"""Prepare optional local models before processing private documents."""
import argparse
from pathlib import Path
import subprocess
import sys
import venv

parser = argparse.ArgumentParser()
parser.add_argument('--venv', type=Path)
parser.add_argument('--reuse-python', type=Path)
args = parser.parse_args()
if args.reuse_python:
    python = str(args.reuse_python)
elif args.venv:
    if sys.version_info[:2] != (3, 12):
        raise SystemExit('Run setup with Python 3.12.')
    if not args.venv.exists():
        venv.create(args.venv, with_pip=True)
    python = str(args.venv / 'bin/python')
    subprocess.run([python, '-m', 'pip', 'install', '-r', str(Path(__file__).parents[1] / 'requirements-docling.txt')], check=True)
else:
    raise SystemExit('Choose --venv or --reuse-python.')
subprocess.run([python, '-c', "import sys,importlib.metadata; assert sys.version_info[:2]==(3,12); assert importlib.metadata.version('docling')=='2.138.0'"], check=True)
subprocess.run([python, '-c', 'from docling.utils.model_downloader import download_models; download_models(with_layout=True, with_tableformer=True, with_code_formula=False, with_picture_classifier=False, with_rapidocr=False)'], check=True)
print(f'Local worker ready. Set MEDIVAANII_DOCLING_PYTHON={python}')
