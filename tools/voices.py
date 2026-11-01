#!/usr/bin/env python3
"""Renders the guards' spoken lines with the local VoiceStudio server and checks them.

tools/voices.json holds the inputs, written by Claude: each guard voice's design ("instruct",
a description VoiceStudio designs a voice from, and its "seed") and each event's lines
(two per event). Every voice says every line: the line ids are <voice>_<event>_<n> (n from 1),
which is how Audio.say finds them. Rendering is voice design only: no saved profile and no
reference audio are ever sent, so no cloned voice can be used. A render is not always speech
(an exclamation can come out as a near-silent breath), so each one is transcribed by the same
server's speech recogniser and must read back as its text (MATCH); otherwise the next seed is
tried, up to TRIES from the voice's seed. The render that passes is encoded to
afterhours/audio/voice/<id>.mp3 (lame, 48 kbps mono, no ID3 tags) and recorded under "lines"
with its text, design, the voice's seed ("seed_from"), the seed that passed ("seed"), what was
heard and the MP3's sha256.

Speech never carries anything the player needs (CLAUDE.md): every line plays beside its
event's icon and sound.

Usage (from repo root):
    python3 tools/voices.py            render every line that is missing or whose text or design
                                       changed, each checked by transcription (needs VoiceStudio
                                       at VOICESTUDIO_URL and lame on PATH)
    python3 tools/voices.py --check    verify every line is recorded as its inputs say, its MP3
                                       is there, unchanged and imported, and no MP3 is orphaned;
                                       prints "voices: OK" (no server needed)
"""
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "tools" / "voices.json"
OUT_DIR = ROOT / "afterhours" / "audio" / "voice"
VOICESTUDIO_URL = os.environ.get("VOICESTUDIO_URL", "http://localhost:3900")
# Diffusion steps per render (32: VoiceStudio's quality setting).
STEPS = 32
TIMEOUT_S = 600
# Seeds tried per line (from the voice's seed on) before giving up.
TRIES = 8
# How closely the transcript must match the line's text (difflib ratio of their letters).
MATCH = 0.8
# The voice lines together must stay under this (the web build stays small).
MAX_TOTAL_BYTES = 1024 * 1024


class VoiceError(Exception):
    pass


def wanted(spec):
    """{line id: {"voice", "event", "text", "instruct", "seed_from"}} as the inputs say."""
    lines = {}
    for voice, design in spec["voices"].items():
        for event, texts in spec["events"].items():
            for n, text in enumerate(texts, 1):
                lines[f"{voice}_{event}_{n}"] = {"voice": voice, "event": event, "text": text,
                                                 "instruct": design["instruct"], "seed_from": design["seed"]}
    return lines


def same_inputs(recorded, want):
    return all(recorded.get(key) == value for key, value in want.items())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def post(path, fields, files=None):
    """POSTs multipart `fields` (and `files`: name -> (file name, bytes)) to VoiceStudio;
    returns (content type, body)."""
    boundary = uuid.uuid4().hex
    body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode() for k, v in fields.items())
    for name, (file_name, data) in (files or {}).items():
        body += (f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{file_name}"\r\n'
                 "Content-Type: application/octet-stream\r\n\r\n").encode() + data + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    request = urllib.request.Request(f"{VOICESTUDIO_URL}{path}", data=body, method="POST",
                                     headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_S) as response:
            return response.headers.get("content-type", ""), response.read()
    except OSError as e:
        raise VoiceError(f"VoiceStudio at {VOICESTUDIO_URL}{path} failed: {e} (is the app running?)")


def render(text, instruct, seed):
    """WAV bytes of `text` in the voice VoiceStudio designs from `instruct` and `seed`."""
    kind, data = post("/generate", {"text": text, "language": "English", "instruct": instruct, "seed": str(seed), "num_step": str(STEPS)})
    if kind != "audio/wav" or data[:4] != b"RIFF":
        raise VoiceError(f"VoiceStudio answered '{text}' with {kind or 'no content type'}, not a WAV")
    return data


def heard(wav):
    """What VoiceStudio's speech recogniser hears in `wav` (English)."""
    _, body = post("/v1/audio/transcriptions", {"model": "whisper-1", "language": "en"}, {"file": ("line.wav", wav)})
    try:
        return json.loads(body).get("text", "")
    except ValueError:
        raise VoiceError(f"the transcription answer is not JSON: {body[:200]!r}")


def letters(text):
    return re.sub(r"[^a-z]", "", text.lower())


def render_heard(text, instruct, seed_from):
    """(WAV bytes, seed, transcript) of the first render from seed_from on that reads back as
    `text`; none in TRIES is an error."""
    tried = []
    for seed in range(seed_from, seed_from + TRIES):
        wav = render(text, instruct, seed)
        transcript = heard(wav)
        if difflib.SequenceMatcher(None, letters(transcript), letters(text)).ratio() >= MATCH:
            return wav, seed, transcript
        tried.append(f"seed {seed}: {transcript!r}")
    raise VoiceError(f"no render of '{text}' ({instruct}) reads back as it in {TRIES} seeds: {'; '.join(tried)}")


def generate():
    lame = shutil.which("lame")
    if lame is None:
        raise VoiceError("lame is needed on PATH to encode (Homebrew: brew install lame)")
    spec = json.loads(SPEC.read_text())
    want = wanted(spec)
    recorded = {key: value for key, value in spec.get("lines", {}).items() if key in want}
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for line_id, inputs in want.items():
            mp3 = OUT_DIR / f"{line_id}.mp3"
            if line_id in recorded and same_inputs(recorded[line_id], inputs) and mp3.exists():
                continue
            data, seed, transcript = render_heard(inputs["text"], inputs["instruct"], inputs["seed_from"])
            wav = Path(tmp) / f"{line_id}.wav"
            wav.write_bytes(data)
            result = subprocess.run([lame, "--quiet", "-m", "m", "-b", "48", "--noreplaygain", str(wav), str(mp3)],
                                    capture_output=True, text=True)
            if result.returncode != 0:
                raise VoiceError(f"lame failed for {mp3}: {result.stderr.strip()}")
            recorded[line_id] = dict(inputs, seed=seed, heard=transcript, sha256=sha(mp3))
            print(f"voices: rendered {line_id}: \"{inputs['text']}\" (seed {seed}, heard {transcript!r}, {mp3.stat().st_size} bytes)")
            # Recorded after every line, so an interrupted run keeps what it rendered.
            spec["lines"] = dict(sorted(recorded.items()))
            SPEC.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n")
    for path in sorted(OUT_DIR.glob("*.mp3")):
        if path.stem not in want:
            raise VoiceError(f"{path.relative_to(ROOT)} is orphaned: no line makes it any more; delete it and its .import")
    spec["lines"] = dict(sorted(recorded.items()))
    SPEC.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n")
    print(f"voices: {len(want)} lines up to date in {OUT_DIR.relative_to(ROOT)}")


def check():
    try:
        spec = json.loads(SPEC.read_text())
    except (OSError, ValueError) as e:
        raise VoiceError(f"cannot read {SPEC.relative_to(ROOT)}: {e}")
    want = wanted(spec)
    recorded = spec.get("lines", {})
    problems = []
    total_bytes = 0
    for line_id, inputs in want.items():
        mp3 = OUT_DIR / f"{line_id}.mp3"
        if line_id not in recorded:
            problems.append(f"{line_id} (\"{inputs['text']}\") was never rendered, run python3 tools/voices.py")
        elif not same_inputs(recorded[line_id], inputs):
            problems.append(f"{line_id}: its text or design changed since it was rendered, run python3 tools/voices.py")
        if not mp3.exists():
            problems.append(f"{mp3.relative_to(ROOT)} is missing, run python3 tools/voices.py")
            continue
        total_bytes += mp3.stat().st_size
        if line_id in recorded and recorded[line_id].get("sha256") != sha(mp3):
            problems.append(f"{mp3.relative_to(ROOT)} differs from the render recorded in {SPEC.relative_to(ROOT)}")
        if not Path(str(mp3) + ".import").exists():
            problems.append(f"{mp3.relative_to(ROOT)}.import missing: import the project (Godot --import) and commit it")
    for line_id in sorted(set(recorded) - set(want)):
        problems.append(f"{SPEC.relative_to(ROOT)} records {line_id}, which no voice and event make any more")
    for path in sorted(OUT_DIR.glob("*.mp3")):
        if path.stem not in want:
            problems.append(f"{path.relative_to(ROOT)} is orphaned: no line makes it any more")
    if total_bytes > MAX_TOTAL_BYTES:
        problems.append(f"the voice lines total {total_bytes} bytes, over {MAX_TOTAL_BYTES}")
    if problems:
        raise VoiceError("\n".join(problems))
    print(f"voices: OK ({len(want)} lines, {len(spec['voices'])} voices, {total_bytes} bytes)")


def main():
    try:
        if sys.argv[1:] == ["--check"]:
            check()
        elif not sys.argv[1:]:
            generate()
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except VoiceError as e:
        print(f"voices: error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
