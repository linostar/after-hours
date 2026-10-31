#!/usr/bin/env python3
"""Fetches the public-domain painting scans listed in afterhours/art/scans/SOURCES.json.

For each entry: downloads source_url into a fresh temporary directory (untrusted data: size
capped, decoded only as a JPEG or PNG), checks its SHA-256 against the entry's sha256,
crops it to the entry's optional crop (left, top, right, bottom as fractions of the image; used
to trim writing such as a print's title cartouche, which the No Text rule bans), downscales it to MAX_SIDE on its longest side and writes afterhours/art/scans/<file> (WebP).
An entry with an empty sha256 is pinned: the downloaded file's digest is written back into
SOURCES.json. A digest that differs from a pinned one fails. tools/check_project.gd checks
that every scan has a complete entry.

Needs Pillow (python3 -m pip install Pillow) and network access. Run with -I (isolated mode:
nothing is imported from the current directory).

Usage (from repo root):
    python3 -I tools/scans.py     fetches every scan; prints one line per scan, exit 1 on any
                                  failure (the failing scans are left as they were)
"""
import hashlib
import io
import json
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

SCANS = Path(__file__).resolve().parent.parent / "afterhours" / "art" / "scans"
SOURCES = SCANS / "SOURCES.json"
# The longest side of a scan in the game, in pixels (the largest view, the hideout, shows
# a painting at most about this big on the 960x540 base at 2x).
MAX_SIDE = 768
WEBP_QUALITY = 88
MAX_DOWNLOAD = 20 * 1024 * 1024
# Wikimedia asks scripts to name themselves.
USER_AGENT = "AfterHoursJamBuild/1.0 (game jam asset script; tools/scans.py)"
# Rate limits (HTTP 429): retries per download, the wait without a Retry-After (times the
# attempt) and the pause between downloads.
RETRIES = 4
RETRY_WAIT = 10
PAUSE = 2


class ScanError(Exception):
    pass


def download(url, into):
    """`url`'s bytes, saved to a file in the directory `into` (at most MAX_DOWNLOAD)."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(RETRIES + 1):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read(MAX_DOWNLOAD + 1)
            break
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == RETRIES:
                raise
            wait = int(e.headers.get("Retry-After", "") or RETRY_WAIT * (attempt + 1))
            print(f"scans: {url}: rate limited, retrying in {wait} s")
            time.sleep(wait)
    if len(data) > MAX_DOWNLOAD:
        raise ScanError(f"{url} is larger than {MAX_DOWNLOAD} bytes")
    (Path(into) / "download").write_bytes(data)
    return data


def fetch(entry):
    """Downloads, checks and writes one entry's scan; returns its SHA-256 and output size."""
    from PIL import Image

    with tempfile.TemporaryDirectory() as tmp:
        data = download(entry["source_url"], tmp)
    digest = hashlib.sha256(data).hexdigest()
    if entry["sha256"] and digest != entry["sha256"]:
        raise ScanError(f"SHA-256 {digest} does not match the pinned {entry['sha256']}")
    with Image.open(io.BytesIO(data), formats=["JPEG", "PNG"]) as image:
        image = image.convert("RGB")
        left, top, right, bottom = entry.get("crop", [0, 0, 1, 1])
        w, h = image.size
        image = image.crop((round(left * w), round(top * h), round(right * w), round(bottom * h)))
        image.thumbnail((MAX_SIDE, MAX_SIDE), Image.Resampling.LANCZOS)
        out = SCANS / entry["file"]
        image.save(out, "WEBP", quality=WEBP_QUALITY, method=6)
        return digest, image.size


def main():
    if len(sys.argv) > 1:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        import PIL  # noqa: F401
    except ImportError:
        print("scans: error: needs Pillow (python3 -m pip install Pillow)", file=sys.stderr)
        return 2
    entries = json.loads(SOURCES.read_text(encoding="utf-8"))
    failed = 0
    pinned = 0
    for i, entry in enumerate(entries):
        if i:
            time.sleep(PAUSE)
        try:
            digest, size = fetch(entry)
        except (ScanError, OSError, ValueError) as e:
            print(f"scans: {entry['id']}: FAILED: {e}", file=sys.stderr)
            failed += 1
            continue
        note = ""
        if not entry["sha256"]:
            entry["sha256"] = digest
            pinned += 1
            note = " (pinned)"
        print(f"scans: {entry['id']}: {entry['file']} {size[0]}x{size[1]}, sha256 {digest}{note}")
    if pinned:
        SOURCES.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"scans: {len(entries) - failed} of {len(entries)} scans written, {pinned} pinned")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
