"""Bounded private JSON IPC with an isolated, warm local Docling process."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time


class DoclingWorker:
    def __init__(self, python=None):
        self.python = python or os.environ.get('MEDIVAANII_DOCLING_PYTHON')
        self.process = None
        self.responses = queue.Queue()
        self.lock = threading.Lock()

    def _start(self):
        if not self.python or not Path(self.python).is_file():
            raise RuntimeError('The local table worker is not configured.')
        env = {**os.environ, 'HF_HUB_OFFLINE': '1', 'TRANSFORMERS_OFFLINE': '1',
               'HF_HUB_DISABLE_TELEMETRY': '1', 'DO_NOT_TRACK': '1', 'TOKENIZERS_PARALLELISM': 'false'}
        self.responses = queue.Queue()
        self.process = subprocess.Popen([self.python, '-u', str(Path(__file__).resolve()), '--child'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env)
        responses, stream = self.responses, self.process.stdout
        def read():
            try:
                for line in stream:
                    responses.put(line)
            except (OSError, ValueError):
                pass
            finally:
                responses.put(None)
        threading.Thread(target=read, daemon=True).start()

    def convert(self, file_path: str, page_numbers: list[int], deadline_seconds=600):
        if deadline_seconds <= 0 or not page_numbers or min(page_numbers) < 1 or max(page_numbers) > 100:
            raise ValueError('Invalid local conversion limits.')
        start = time.monotonic()
        if not self.lock.acquire(timeout=deadline_seconds):
            raise TimeoutError('The local table worker timed out.')
        try:
            if self.process is None or self.process.poll() is not None:
                self._start()
            self.process.stdin.write(json.dumps({'path': file_path, 'pages': page_numbers}) + '\n')
            self.process.stdin.flush()
            try:
                line = self.responses.get(timeout=max(0, deadline_seconds - (time.monotonic() - start)))
            except queue.Empty:
                self.close()
                raise TimeoutError('The local table worker timed out.') from None
            if line is None:
                self.close()
                raise RuntimeError('The local table worker stopped before completing the report.')
            try:
                reply = json.loads(line)
            except (ValueError, TypeError):
                self.close()
                raise RuntimeError('The local table worker returned an invalid response.') from None
            if reply.get('error') or not isinstance(reply.get('document'), dict):
                raise RuntimeError('The local table worker could not complete this document.')
            return reply['document']
        finally:
            self.lock.release()

    def close(self):
        process, self.process = self.process, None
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            for stream in [process.stdin, process.stdout]:
                if stream:
                    stream.close()


def _child():
    import contextlib
    import importlib.metadata
    import logging
    logging.basicConfig(level=logging.ERROR)
    try:
        if sys.version_info[:2] != (3, 12) or importlib.metadata.version('docling') != '2.138.0':
            raise RuntimeError('Unsupported worker environment')
        with contextlib.redirect_stdout(sys.stderr):
            from docling.datamodel.base_models import InputFormat
            from docling.datamodel.pipeline_options import PdfPipelineOptions, TableFormerMode, AcceleratorOptions, AcceleratorDevice, TesseractCliOcrOptions
            from docling.document_converter import DocumentConverter, PdfFormatOption, ImageFormatOption
            options = PdfPipelineOptions(do_ocr=True, do_table_structure=True, enable_remote_services=False,
                allow_external_plugins=False, document_timeout=600,
                accelerator_options=AcceleratorOptions(num_threads=4, device=AcceleratorDevice.CPU),
                ocr_options=TesseractCliOcrOptions(lang=['eng']))
            options.table_structure_options.mode = TableFormerMode.ACCURATE
            image_options = options.model_copy(deep=True)
            image_options.ocr_options.force_full_page_ocr = True
            converter = DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=options),
                InputFormat.IMAGE: ImageFormatOption(pipeline_options=image_options)})
        for line in sys.stdin:
            try:
                request = json.loads(line)
                with contextlib.redirect_stdout(sys.stderr):
                    result = converter.convert(Path(request['path']),
                        page_range=(min(request['pages']), max(request['pages'])),
                        max_num_pages=100, max_file_size=10 * 1024 * 1024)
                if str(result.status).split('.')[-1] != 'SUCCESS':
                    raise RuntimeError('Incomplete conversion')
                print(json.dumps({'document': result.document.export_to_dict()}), flush=True)
            except Exception:
                print(json.dumps({'error': 'conversion_failed'}), flush=True)
    except Exception:
        print(json.dumps({'error': 'worker_unavailable'}), flush=True)


if __name__ == '__main__' and '--child' in sys.argv:
    _child()
