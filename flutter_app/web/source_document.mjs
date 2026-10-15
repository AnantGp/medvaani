// Prefer the file signature over upload names, query parameters and MIME hints.
export function sourceMimeType(bytes) {
  const at = (signature, offset = 0) => bytes.length >= offset + signature.length &&
    signature.every((value, i) => bytes[offset + i] === value);
  if (at([37, 80, 68, 70, 45])) return 'application/pdf';
  if (at([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (at([255, 216, 255])) return 'image/jpeg';
  if (at([82, 73, 70, 70]) && at([87, 69, 66, 80], 8)) return 'image/webp';
  return null;
}
