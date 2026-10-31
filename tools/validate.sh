#!/usr/bin/env bash
# Validation gate: asset import, project check (No Text, public-domain scan credits,
# touch-first and landscape rules + strict script compile) and its violation fixtures,
# scan fetcher self-test, headless gameplay tests, headless run of the main scene. Exits non-zero on the first failure and points at
# the log that explains it. Every Godot call is killed after GODOT_TIMEOUT seconds.
# Env: GODOT (Godot binary), GODOT_TIMEOUT (default 300), RUN_FRAMES (headless run length, default 120).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
GODOT_TIMEOUT="${GODOT_TIMEOUT:-300}"
LOG_DIR=build/logs
mkdir -p "$LOG_DIR"

fail() {
  echo "FAIL $1 (log: $2)" >&2
  grep -E "ERROR|WARNING|check_project|test_gameplay|run_main|import_cache|scans" "$2" >&2 || true
  exit 1
}

# Runs Godot with a hard timeout (macOS has no coreutils `timeout`; perl's alarm
# kills the process with SIGALRM, exit status 142). Usage: godot <log> <args...>
godot() {
  local log="$1"
  shift
  local status=0
  perl -e 'alarm shift @ARGV; exec @ARGV or die "exec failed: $!\n"' "$GODOT_TIMEOUT" "$GODOT" "$@" >"$log" 2>&1 || status=$?
  if [ "$status" -eq 142 ]; then
    echo "ERROR: timed out after ${GODOT_TIMEOUT}s" >>"$log"
  fi
  return "$status"
}

# Runs a Godot --script and requires exit status 0, its explicit OK line and a log
# free of ERROR/WARNING. Usage: run_script <name> <log> <extra godot args...>
run_script() {
  local name="$1" log="$2"
  shift 2
  # Godot exits 0 even when a --script fails to compile, so status 0 alone proves
  # nothing: a run passes only with status 0 and its explicit OK line (a crash or
  # signal after the OK line still fails).
  local status=0
  godot "$log" --headless --path afterhours "$@" --script "$PWD/tools/$name.gd" || status=$?
  if [ "$status" -ne 0 ]; then
    fail "$name exited with status $status" "$log"
  fi
  if ! grep -q "^$name: OK" "$log" || grep -qE "ERROR|WARNING" "$log"; then
    fail "$name" "$log"
  fi
}

# On a fresh clone (no import cache), and in an existing checkout after new or changed
# assets arrive (a pull, a branch switch), the first import can report errors for
# resources loaded at startup (a scene's texture or sound) before
# they are imported. A priming import fills the cache; the checked import below then must
# be clean. Only cache-miss errors (a not-yet-imported file and the loads that fail because
# of it) are tolerated there; any other problem (a script or scene parse error) still fails.
CACHE_MISS="Cannot open file 'res://\.godot/imported/|Unable to open file: res://\.godot/imported/|Failed loading resource: res://|referenced non-existent resource at: res://"

# Whether the import cache is stale, by Godot's own rule (tools/import_cache.py: no cache, an
# asset not imported yet, or one whose content changed since its import; a touch alone is
# not stale), and that rule's self-test on made-up projects.
if ! python3 tools/import_cache.py --self-test >"$LOG_DIR/import_cache.log" 2>&1 || ! grep -q "^import_cache: OK" "$LOG_DIR/import_cache.log"; then
  fail "import cache check self-test" "$LOG_DIR/import_cache.log"
fi
# The scan fetcher's rules (pinning, mismatch, crop, downscale, non-images refused) on local
# images; skipped without Pillow.
if ! python3 -I tools/scans.py --self-test >"$LOG_DIR/scans.log" 2>&1 || ! grep -qE "^scans: (OK|self-test skipped)" "$LOG_DIR/scans.log"; then
  fail "scans self-test" "$LOG_DIR/scans.log"
fi
cache_state="$(python3 tools/import_cache.py afterhours 2>>"$LOG_DIR/import_cache.log")" || fail "import cache check" "$LOG_DIR/import_cache.log"
if [ "$cache_state" != "fresh" ]; then
  echo "Import cache is stale (${cache_state#stale: }): running the priming import"
  godot "$LOG_DIR/import_prime.log" --headless --path afterhours --import || true
  if grep -E "ERROR|WARNING" "$LOG_DIR/import_prime.log" | grep -qvE "$CACHE_MISS"; then
    fail "priming import reported problems besides import-cache misses" "$LOG_DIR/import_prime.log"
  fi
fi
godot "$LOG_DIR/import.log" --headless --path afterhours --import || fail "import exited non-zero" "$LOG_DIR/import.log"
if grep -qE "ERROR|WARNING" "$LOG_DIR/import.log"; then fail "import reported problems" "$LOG_DIR/import.log"; fi

run_script check_project "$LOG_DIR/check.log"

# check_project.gd against the tiny projects in tools/check_fixtures/ (outside the game,
# so they never ship): each <case>/expected.txt lists the violation lines that case must
# report (each line a prefix of one reported violation), and nothing else; a case without
# expected.txt (allowed input use) must pass. Engine ERROR/WARNING lines fail a case,
# except in a case whose expected_engine_errors.txt lists them (the strict-compile case:
# a script that fails to compile makes Godot log its parse error): each listed line must
# appear, and every ERROR/WARNING line must contain one of them.
fixtures=0
for fixture in tools/check_fixtures/*/; do
  case_name="$(basename "$fixture")"
  log="$LOG_DIR/check_fixture_$case_name.log"
  godot "$log" --headless --path "$fixture" --script "$PWD/tools/check_project.gd" || true
  engine_errors="$fixture/expected_engine_errors.txt"
  if [ -f "$engine_errors" ]; then
    while IFS= read -r line; do
      grep -qF "$line" "$log" || fail "check_project fixture $case_name did not log the expected engine error: $line" "$log"
    done <"$engine_errors"
    if grep -E "ERROR|WARNING" "$log" | grep -qvF -f "$engine_errors"; then
      fail "check_project fixture $case_name reported unexpected engine problems" "$log"
    fi
  elif grep -qE "ERROR|WARNING" "$log"; then
    fail "check_project fixture $case_name reported engine problems" "$log"
  fi
  if [ -f "$fixture/expected.txt" ]; then
    while IFS= read -r line; do
      grep -qF "check_project: $line" "$log" || fail "check_project fixture $case_name did not report: $line" "$log"
    done <"$fixture/expected.txt"
    expected="$(grep -c . "$fixture/expected.txt")"
    grep -qxF "check_project: FAILED with $expected violation(s)" "$log" || fail "check_project fixture $case_name must report exactly $expected violation(s)" "$log"
  elif ! grep -q "^check_project: OK" "$log"; then
    fail "check_project fixture $case_name (allowed input use) must pass" "$log"
  fi
  fixtures=$((fixtures + 1))
done
run_script test_gameplay "$LOG_DIR/test.log" --fixed-fps 60
summary="$(grep "^import_cache: OK" "$LOG_DIR/import_cache.log"); $(grep -E "^scans: (OK|self-test skipped)" "$LOG_DIR/scans.log"); $(grep "^check_project: OK" "$LOG_DIR/check.log"); check fixtures: $fixtures; $(grep "^test_gameplay: OK" "$LOG_DIR/test.log")"
# The main scene (the title) runs 120 frames (2 s at 60 fixed fps) by default; run_main
# requires the flow state to match the running scene.
RUN_FRAMES="${RUN_FRAMES:-120}" run_script run_main "$LOG_DIR/run.log" --fixed-fps 60

echo "PASS validate ($summary)"
