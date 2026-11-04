"""Supervise two single-worker servers; ML is reachable only on loopback."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import urllib.request
import json


def main():
    backend = Path(os.getenv('BACKEND_DIR', '/srv/backend'))
    ml = Path(os.getenv('ML_DIR', '/srv/ml'))
    port = int(os.getenv('PORT', '10000'))
    children = []

    def stop(*_):
        for child in children:
            if child.poll() is None:
                child.terminate()
        for child in children:
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    try:
        subprocess.run([sys.executable, '-m', 'app.scripts.seed_demo'], cwd=backend, check=True)
        children.append(subprocess.Popen([sys.executable, '-m', 'uvicorn', 'api:app',
            '--host', '127.0.0.1', '--port', '8002', '--workers', '1', '--no-access-log'], cwd=ml))
        deadline = time.monotonic() + 120
        while True:
            if children[0].poll() is not None:
                raise RuntimeError('ML process exited during startup')
            try:
                with urllib.request.urlopen('http://127.0.0.1:8002/model-status', timeout=2) as response:
                    if json.load(response).get('status') == 'loaded':
                        break
            except Exception:
                pass
            if time.monotonic() > deadline:
                raise RuntimeError('ML startup readiness timed out')
            time.sleep(1)
        children.append(subprocess.Popen([sys.executable, '-m', 'uvicorn', 'app.main:app',
            '--host', '0.0.0.0', '--port', str(port), '--workers', '1', '--no-access-log'], cwd=backend))
        while all(child.poll() is None for child in children):
            time.sleep(1)
        raise RuntimeError('A required service exited')
    finally:
        stop()


if __name__ == '__main__':
    main()
