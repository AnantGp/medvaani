import importlib
import importlib.util
import subprocess
import sys
from pathlib import Path
import pytest


def worker_type():
    assert importlib.util.find_spec('docling_worker') is not None, 'Bounded isolated worker is missing'
    return importlib.import_module('docling_worker').DoclingWorker


def test_worker_enforces_startup_deadline_and_stops_owned_process(tmp_path):
    source = tmp_path / 'source.pdf'
    source.write_bytes(b'not used before startup deadline')
    worker = worker_type()(python=sys.executable)
    with pytest.raises(TimeoutError):
        worker.convert(str(source), [1], deadline_seconds=.001)
    assert worker.process is None


def test_worker_invalid_limits_are_rejected():
    worker = worker_type()(python=sys.executable)
    with pytest.raises(ValueError):
        worker.convert('source.pdf', [0])
    with pytest.raises(ValueError):
        worker.convert('source.pdf', [1], deadline_seconds=0)
    assert worker.process is None


def test_worker_module_does_not_import_ml_packages_into_api_process():
    worker_type()
    backend = Path(__file__).parent
    result = subprocess.run([sys.executable, '-c', "import sys; import docling_worker; assert 'torch' not in sys.modules; assert 'docling' not in sys.modules"], cwd=backend, capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
