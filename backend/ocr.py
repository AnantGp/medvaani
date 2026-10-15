import os
import importlib.util
import hashlib
import shutil
from pathlib import Path


def lines_from_words(words, page, method='native'):
    """Group the same physical row, retaining original words and coordinates."""
    groups = []
    for word in sorted(words, key=lambda w: (w['y'], w['x'])):
        group = next((g for g in reversed(groups[-4:]) if abs(g[0]['y'] - word['y']) < .0035), None)
        if group is None:
            groups.append([word])
        else:
            group.append(word)
    result = []
    for group in groups:
        group.sort(key=lambda w: w['x'])
        x, y = min(w['x'] for w in group), min(w['y'] for w in group)
        right = max(w['x'] + w['width'] for w in group)
        bottom = max(w['y'] + w['height'] for w in group)
        result.append({'page': page, 'text': ' '.join(w['text'] for w in group),
                       'box': [x, y, right - x, bottom - y], 'words': group, 'method': method})
    return result


def read_document(file_path: str):
    """Read source primitives before any medical interpretation or flat-text parsing."""
    from report_records import ExtractedDocument
    path = Path(file_path)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    pages, diagnostics, candidates = [], [], []
    cloud_ocr = os.getenv('MEDIVAANII_FORCE_VISION') == '1' or not shutil.which('tesseract')
    if path.suffix.lower() != '.pdf':
        from PIL import Image, ImageOps
        with Image.open(path) as source:
            corrected = ImageOps.exif_transpose(source)
            width, height = corrected.size
            if cloud_ocr:
                from groq_vision import scan_image
                scanned, candidates = scan_image(corrected, digest)
                text = scanned['extracted_text']
                pages.append(scanned)
        if not cloud_ocr:
            lines = []
            text = extract_from_image(str(path), layout=lines)
            pages.append({'page': 1, 'width': width, 'height': height,
                          'words': [w for l in lines for w in l['words']], 'lines': lines, 'regions': []})
        input_type = 'photo'
    else:
        import pdfplumber
        vision_pages = 0
        try:
            with pdfplumber.open(path) as pdf:
                if len(pdf.pages) > 100:
                    raise ValueError('Choose a report of up to 100 pages.')
                for number, page in enumerate(pdf.pages, 1):
                    try:
                        raw_words = page.extract_words(x_tolerance=3, y_tolerance=3)
                        image_area = sum(max(0, im['x1'] - im['x0']) * max(0, im['bottom'] - im['top']) for im in page.images)
                        if not raw_words or (len(raw_words) < 25 and image_area > page.width * page.height * .5):
                            if cloud_ocr:
                                if vision_pages >= int(os.getenv('MEDIVAANII_MAX_VISION_PAGES', '8')):
                                    raise ValueError('Cloud OCR page allowance exceeded for this upload.')
                                from groq_vision import scan_image
                                import pypdfium2 as pdfium
                                with pdfium.PdfDocument(str(path)) as rendered:
                                    rendered_page = rendered[number - 1]
                                    image = rendered_page.render(scale=min(3, 2400 / max(page.width, page.height))).to_pil()
                                    scanned, extra = scan_image(image, digest, number)
                                    image.close()
                                    rendered_page.close()
                                pages.append(scanned)
                                candidates.extend(extra)
                                vision_pages += 1
                                continue
                            from pdf2image import convert_from_path
                            image = convert_from_path(str(path), first_page=number, last_page=number, size=2000)[0]
                            lines = []
                            read_ocr(image, layout=lines, page=number)
                            words = [w for l in lines for w in l['words']]
                        else:
                            words = [{'text': w['text'], 'x': w['x0'] / page.width, 'y': w['top'] / page.height,
                                      'width': (w['x1'] - w['x0']) / page.width,
                                      'height': (w['bottom'] - w['top']) / page.height} for w in raw_words]
                            lines = lines_from_words(words, number)
                        pages.append({'page': number, 'width': page.width, 'height': page.height,
                                      'words': words, 'lines': lines, 'regions': []})
                        if not words:
                            diagnostics.append({'code': 'page_failed', 'page': number})
                    except Exception as exc:
                        # Preserve an actionable provider error for the user.
                        from groq_provider import GroqError
                        if isinstance(exc, GroqError):
                            raise ValueError(str(exc)) from exc
                        diagnostics.append({'code': 'page_failed', 'page': number})
                        pages.append({'page': number, 'width': page.width, 'height': page.height,
                                      'words': [], 'lines': [], 'regions': []})
        except ValueError:
            raise
        except Exception as exc:
            raise ValueError('We could not read this PDF. Choose an unlocked original PDF or a clearer report photo.') from exc
        text = '\n'.join(p.get('extracted_text') or '\n'.join(l['text'] for l in p['lines']) for p in pages)
        input_type = 'pdf'
    if not text.strip():
        raise ValueError('We could not read the report. Choose a clearer photo or original PDF.')
    return ExtractedDocument(source_digest=digest, input_type=input_type, extracted_text=text,
                             pages=pages, candidates=candidates, diagnostics=diagnostics)


def extract_text(file_path: str, *, layout=None) -> str:
    """
    Extract text from image or PDF file
    Supports: JPG, JPEG, PNG, PDF
    """
    if os.getenv('VERCEL') == '1' or os.getenv('MEDIVAANII_FORCE_VISION') == '1':
        document = read_document(file_path)
        if layout is not None:
            layout.extend(line for page in document['pages'] for line in page.get('lines', []))
        return document['extracted_text']
    ext = os.path.splitext(file_path)[1].lower()

    if ext == '.pdf':
        return extract_from_pdf(file_path, layout=layout)
    else:
        return extract_from_image(file_path, layout=layout)


def read_ocr(image, *, layout=None, page=1):
    """Keep the OCR words and their actual image coordinates in the same pass.

    Coordinates are normalized to the EXIF-corrected image; they are locations,
    not a claim that OCR recognized the content correctly.
    """
    import pytesseract
    if layout is None:
        return pytesseract.image_to_string(image, lang="eng", timeout=30).strip()
    data = pytesseract.image_to_data(image, lang="eng", timeout=30, output_type=pytesseract.Output.DICT)
    groups = {}
    for i, text in enumerate(data["text"]):
        text = text.strip()
        if not text:
            continue
        key = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
        groups.setdefault(key, []).append({"text": text,
            "x": data["left"][i] / image.width, "y": data["top"][i] / image.height,
            "width": data["width"][i] / image.width, "height": data["height"][i] / image.height})
    lines = []
    for words in groups.values():
        text = " ".join(word["text"] for word in words)
        lines.append(text)
        left = min(word["x"] for word in words)
        top = min(word["y"] for word in words)
        right = max(word["x"] + word["width"] for word in words)
        bottom = max(word["y"] + word["height"] for word in words)
        layout.append({"page": page, "text": text, "method": "ocr",
            "box": [left, top, right - left, bottom - top], "words": words})
    return "\n".join(lines)


def extract_from_image(image_path: str, *, layout=None) -> str:
    """Read a camera photo; extraction failures are not report content."""
    from PIL import Image, ImageOps, UnidentifiedImageError
    import pytesseract
    try:
        with Image.open(image_path) as source:
            if source.width * source.height > 25_000_000:
                raise ValueError("This photo is too large. Choose a smaller photo or a PDF.")
            image = ImageOps.exif_transpose(source)
            # Remove transparency against white, normalize contrast and reduce
            # camera images to a bounded working size without cropping the page.
            rgba = image.convert("RGBA")
            background = Image.new("RGBA", rgba.size, "white")
            image = ImageOps.autocontrast(ImageOps.grayscale(Image.alpha_composite(background, rgba)))
            image.thumbnail((3000, 3000), Image.Resampling.LANCZOS)
            text = read_ocr(image, layout=layout)
    except pytesseract.TesseractNotFoundError as exc:
        raise ValueError("Photo reading is unavailable on this server. Try uploading a PDF report.") from exc
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError("We could not read this photo. Choose a JPG, PNG or WebP image, or take another photo.") from exc
    except ValueError:
        raise
    except Exception as e:
        raise ValueError("We could not read the text in this photo. Take a clearer photo in good light, or upload a PDF.") from e
    if len(text) < 10:
        raise ValueError("We could not read enough text. Take a clearer photo with the whole report in focus, or upload a PDF.")
    return text


def extract_from_pdf(pdf_path: str, *, layout=None) -> str:
    """Extract text from PDF file using fallback methods."""
    # Get file info for better error messages
    file_name = os.path.basename(pdf_path)
    file_size = os.path.getsize(pdf_path) if os.path.exists(pdf_path) else 0

    # First try PDF text extraction (for text-based PDFs)
    try:
        reader = None

        if importlib.util.find_spec("pypdf") is not None:
            from pypdf import PdfReader
            reader = PdfReader(pdf_path)
        elif importlib.util.find_spec("PyPDF2") is not None:
            import PyPDF2
            reader = PyPDF2.PdfReader(pdf_path)

        if reader is not None:
            page_texts = [page.extract_text() or "" for page in reader.pages]
            if any(text.strip() for text in page_texts) and layout is not None:
                # A mixed PDF can contain a digital first page and a scanned
                # second page. Do not silently discard the scanned results.
                from pdf2image import convert_from_path
                for i, page_text in enumerate(page_texts):
                    if not page_text.strip():
                        image = convert_from_path(pdf_path, first_page=i + 1, last_page=i + 1, size=2000)[0]
                        page_texts[i] = read_ocr(image, layout=layout, page=i + 1)
            full_text = "\n".join(page_texts)

            if full_text.strip():
                return full_text

    except Exception as e:
        pdf_text_error = f"PDF text extraction failed for {file_name} ({file_size} bytes): {str(e)}"

    # Fallback to image-based OCR if libraries are available
    try:
        if layout is not None:
            layout.clear()
        if importlib.util.find_spec("pdf2image") is not None and importlib.util.find_spec("pytesseract") is not None:
            from pdf2image import convert_from_path
            import pytesseract

            images = convert_from_path(pdf_path, size=2000)
            full_text = ""
            for i, image in enumerate(images):
                text = read_ocr(image, layout=layout, page=i + 1)
                full_text += f"\n--- Page {i+1} ---\n{text}"

            if full_text.strip():
                return full_text

    except Exception as e:
        ocr_error = f"PDF image-based OCR failed for {file_name} ({file_size} bytes): {str(e)}"

    # Return combined error information
    error_msg = f"Text extraction failed for {file_name} ({file_size} bytes).\n"
    if 'pdf_text_error' in locals():
        error_msg += f"PDF text extraction: {pdf_text_error}\n"
    if 'ocr_error' in locals():
        error_msg += f"OCR extraction: {ocr_error}\n"
    error_msg += "The document may be image-based, corrupted, or require different processing libraries."

    return error_msg

