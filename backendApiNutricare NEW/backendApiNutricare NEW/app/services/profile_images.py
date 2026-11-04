"""Validate and normalize profile uploads before contacting external storage."""
from io import BytesIO
import warnings

from fastapi import HTTPException
from PIL import Image, UnidentifiedImageError, ImageOps

MAX_UPLOAD_BYTES = 5 * 1024 * 1024
MAX_IMAGE_PIXELS = 16_000_000
ALLOWED_IMAGE_TYPES = {"JPEG", "PNG", "WEBP"}


def normalize_profile_image(content: bytes) -> bytes:
    if not content:
        raise HTTPException(status_code=400, detail="Choose a non-empty profile image")
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Profile images must be 5 MB or smaller")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(content)) as probe:
                if probe.format not in ALLOWED_IMAGE_TYPES:
                    raise HTTPException(status_code=415, detail="Use a JPEG, PNG or WebP image")
                if probe.width * probe.height > MAX_IMAGE_PIXELS:
                    raise HTTPException(status_code=413, detail="Profile image dimensions are too large")
                probe.verify()
            with Image.open(BytesIO(content)) as original:
                image = ImageOps.exif_transpose(original).convert("RGB")
                image.thumbnail((1024, 1024))
                output = BytesIO()
                # Re-encoding strips metadata and trailing non-image content.
                image.save(output, format="JPEG", quality=85)
                return output.getvalue()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError,
            Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(status_code=415, detail="The uploaded file is not a supported valid image") from None
