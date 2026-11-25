# Android demo with a laptop backend

This APK is for demonstration and testing. It is debug-signed, uses a separate `com.example.fyp.demo` application ID, and supports Android 7/API 24 or later. Physical-phone behavior still needs your verification.

## Install

Download the APK matching your phone from the repository's Releases page. Most recent Android phones use **arm64-v8a**; older 32-bit ARM devices may require **armeabi-v7a**. The x86_64 build is intended for compatible emulators. Never install an APK from an untrusted copy.

Connect your phone by USB, enable Developer Options/USB debugging yourself, and accept the computer's authorization prompt yourself. In a terminal with Android platform-tools available:

```sh
adb devices
adb install -r NutriCare-Demo-arm64-v8a.apk
adb reverse tcp:8000 tcp:8000
```

Use the actual downloaded filename if it differs. On Windows the platform-tools executable is commonly under `%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe`.

## Start the laptop services

Start PostgreSQL. From the ML directory with its virtual environment active:

```sh
python -m uvicorn api:app --host 127.0.0.1 --port 8002 --no-access-log
```

From the backend directory with its environment active and private `.env` configured:

```sh
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-access-log
```

Check `http://127.0.0.1:8000/health/ready` on the laptop. Then open **NutriCare Demo** on the phone and register a fictional demo account, complete onboarding, generate meals and log a reading.

The APK uses `http://127.0.0.1:8000`. USB forwarding maps that phone port to the laptop. Re-run `adb reverse` after reconnecting/restarting the phone. The debug network policy allows cleartext only for loopback/emulator hosts; release settings are not relaxed globally.

The app requires the running backend. It is not an offline application, and the laptop cannot be switched off during this demo. Public cloud hosting and an HTTPS-configured APK are separate future steps. Groq narration requires a backend-only key; it is optional and falls back to recorded statistics.

## Build from source

From `mobile/`:

```sh
flutter pub get
flutter build apk --debug --split-per-abi --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Outputs are under `build/app/outputs/flutter-apk/`. A Play Store/release build requires production signing and an HTTPS backend. Never put a database string or provider key in Flutter source or build arguments.
