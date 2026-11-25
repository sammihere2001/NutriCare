from datetime import date, timedelta
from io import BytesIO
from io import TextIOWrapper
from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import AsyncMock, patch

import httpx
from fastapi import HTTPException
from PIL import Image
from pydantic import ValidationError

from app.auth_utils import get_current_user
from app.database import get_db
from app.main import app
from app.models import UserMedication
from app.services.profile_images import MAX_UPLOAD_BYTES, normalize_profile_image
from app.services.treatment_service import read_treatment, save_treatment
from app.routers.notifications import create_notification
from app.treatment_schemas import MedicationRecord, TreatmentProfile


class TreatmentValidationTests(TestCase):
    def test_combination_therapy_is_supported(self):
        profile = TreatmentProfile(medications=[
            MedicationRecord(medication_class='insulin'),
            MedicationRecord(medication_class='glp1', name=' Recorded name '),
            MedicationRecord(medication_class='metformin')])
        self.assertEqual(len(profile.medications), 3)
        self.assertEqual(profile.medications[1].name, 'Recorded name')

    def test_unconfirmed_empty_list_is_distinct_from_confirmed_none(self):
        self.assertFalse(TreatmentProfile().medications_confirmed)
        self.assertTrue(TreatmentProfile(medications_confirmed=True).medications_confirmed)

    def test_invalid_class_future_date_and_extra_user_id_are_rejected(self):
        for payload in [{'medication_class': 'made_up'},
                        {'medication_class': 'glp1', 'started_on': date.today() + timedelta(days=1)},
                        {'medication_class': 'metformin', 'user_id': 2}]:
            with self.assertRaises(ValidationError):
                MedicationRecord(**payload)


class TreatmentPersistenceTests(IsolatedAsyncioTestCase):
    async def test_disabled_notifications_do_not_crash_a_windows_console(self):
        rows = SimpleNamespace(scalars=lambda: SimpleNamespace(all=lambda: []))
        db = SimpleNamespace(execute=AsyncMock(return_value=rows))
        with TextIOWrapper(BytesIO(), encoding='cp1252', errors='strict') as stream:
            with patch('sys.stdout', stream):
                result = await create_notification(db, 1, 'Profile saved', 'Saved', 'success')
        self.assertIsNone(result)

    async def test_save_combination_keeps_insulin_and_prescription_information(self):
        profile = SimpleNamespace(insulin_usage=False, insulin_morning_units=12,
                                  insulin_night_units=8)
        added = []
        db = SimpleNamespace(get=AsyncMock(side_effect=[profile, None]),
                             execute=AsyncMock(), add=added.append)
        payload = TreatmentProfile(medications_confirmed=True, appetite='reduced',
            medications=[MedicationRecord(medication_class='insulin'),
                         MedicationRecord(medication_class='glp1', prescribed_dose='Copied from prescription')])
        await save_treatment(db, 1, payload)
        self.assertTrue(profile.insulin_usage)
        self.assertEqual(profile.insulin_morning_units, 12)
        medicines = [row for row in added if isinstance(row, UserMedication)]
        self.assertEqual([row.medication_class for row in medicines], ['insulin', 'glp1'])
        self.assertEqual(medicines[1].prescribed_dose, 'Copied from prescription')

    async def test_removing_insulin_clears_stale_legacy_doses(self):
        profile = SimpleNamespace(insulin_usage=True, insulin_morning_units=12,
                                  insulin_night_units=8)
        db = SimpleNamespace(get=AsyncMock(side_effect=[profile, None]),
                             execute=AsyncMock(), add=lambda row: None)
        await save_treatment(db, 1, TreatmentProfile(medications=[MedicationRecord(medication_class='metformin')]))
        self.assertFalse(profile.insulin_usage)
        self.assertIsNone(profile.insulin_morning_units)

    async def test_legacy_insulin_is_retained_without_claiming_verified_medications(self):
        rows = SimpleNamespace(scalars=lambda: SimpleNamespace(all=lambda: []))
        db = SimpleNamespace(get=AsyncMock(return_value=None), execute=AsyncMock(return_value=rows))
        result = await read_treatment(db, 1, legacy_insulin=True)
        self.assertEqual(result['medications'][0]['medication_class'], 'insulin')
        self.assertFalse(result['medications_confirmed'])


class ImageValidationTests(TestCase):
    def test_real_image_is_normalized_and_trailing_content_is_removed(self):
        stream = BytesIO()
        Image.new('RGB', (10, 10), 'red').save(stream, format='PNG')
        result = normalize_profile_image(stream.getvalue() + b'private-trailing-content')
        self.assertNotIn(b'private-trailing-content', result)
        with Image.open(BytesIO(result)) as image:
            self.assertEqual(image.format, 'JPEG')

    def test_spoofed_content_and_oversize_are_rejected(self):
        for payload, status in [(b'<script>not an image</script>', 415),
                                (b'x' * (MAX_UPLOAD_BYTES + 1), 413), (b'', 400)]:
            with self.assertRaises(HTTPException) as caught:
                normalize_profile_image(payload)
            self.assertEqual(caught.exception.status_code, status)


class TreatmentAndUploadApiTests(IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        async def fake_db():
            yield SimpleNamespace()
        app.dependency_overrides[get_db] = fake_db
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test')

    async def asyncTearDown(self):
        await self.client.aclose()
        app.dependency_overrides.clear()

    async def test_treatment_requires_authentication(self):
        self.assertEqual((await self.client.get('/treatment/me')).status_code, 401)
        self.assertEqual((await self.client.put('/treatment/me', json={})).status_code, 401)

    async def test_another_user_id_cannot_be_submitted(self):
        async def current_user():
            return SimpleNamespace(user_id=1)
        app.dependency_overrides[get_current_user] = current_user
        response = await self.client.put('/treatment/me', json={'user_id': 2})
        self.assertEqual(response.status_code, 422)

    async def test_fake_image_is_rejected_before_cloud_upload(self):
        async def current_user():
            return SimpleNamespace(user_id=1)
        app.dependency_overrides[get_current_user] = current_user
        with patch('app.routers.profile.cloudinary.uploader.upload') as upload:
            response = await self.client.put('/profile/edit', data={'user_id': '1'},
                files={'profile_picture': ('image.jpg', b'not an image', 'image/jpeg')})
        self.assertEqual(response.status_code, 415)
        upload.assert_not_called()

    async def test_valid_image_is_normalized_before_cloud_upload(self):
        async def current_user():
            return SimpleNamespace(user_id=1)
        app.dependency_overrides[get_current_user] = current_user
        stream = BytesIO()
        Image.new('RGB', (10, 10), 'blue').save(stream, format='PNG')
        with patch('app.routers.profile.cloudinary.uploader.upload',
                   return_value={'secure_url': 'https://example.invalid/profile.jpg'}) as upload, \
             patch('app.routers.profile.update_profile', new=AsyncMock(return_value=
                   SimpleNamespace(profile_picture='https://example.invalid/profile.jpg'))), \
             patch('app.routers.profile.create_notification', new=AsyncMock()):
            result = await self.client.put('/profile/edit', data={'user_id': '1'},
                files={'profile_picture': ('photo.png', stream.getvalue(), 'image/png')})
        self.assertEqual(result.status_code, 200)
        self.assertTrue(upload.call_args.args[0].startswith(b'\xff\xd8'))
