#!/usr/bin/env bash
# =============================================================================
# firebase_update — Test Runner
#
# Usage:
#   ./run_tests.sh                          # interactive
#   ./run_tests.sh -d <device-id>           # pre-select device
#   ./run_tests.sh -d <device-id> --live    # also run live RC test
#   ./run_tests.sh --no-device              # skip all device tests
#
# Examples:
#   ./run_tests.sh -d macos --live
#   ./run_tests.sh -d 00120647H011016 --live
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_DIR="$PKG_ROOT/example"
LOG_DIR="$PKG_ROOT/.test_logs"
mkdir -p "$LOG_DIR"

# ── Parse CLI flags ───────────────────────────────────────────────────────────
CLI_DEVICE=""       # -d <id>  : pre-select device by id or index
CLI_LIVE=false      # --live   : auto-run live RC test without prompting
CLI_NO_DEVICE=false # --no-device : skip device tests entirely

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device) CLI_DEVICE="$2"; shift 2 ;;
    --live)      CLI_LIVE=true; shift ;;
    --no-device) CLI_NO_DEVICE=true; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; D='\033[2m'; N='\033[0m'

sep()  { echo -e "${D}────────────────────────────────────────────────${N}"; }
sep2() { echo -e "${C}${B}════════════════════════════════════════════════${N}"; }

PASS=0; FAIL=0; FAIL_LABELS=()

# ── Run one test file, print one result line ──────────────────────────────────
# run_suite <label> <log_file> <flutter_cmd...>
run_suite() {
  local label="$1"; local log="$2"; shift 2
  printf "  %-52s" "$label"
  set +e
  "$@" > "$log" 2>&1
  local code=$?
  set -e

  if [[ $code -eq 0 ]]; then
    local count
    count=$(grep -E '\+[0-9]+:' "$log" | tail -1 | sed 's/.*+\([0-9]*\):.*/\1/' || true)
    echo -e "  ${G}${B}✔ passed${N} ${D}(${count:-?} tests)${N}"
    PASS=$((PASS + 1))
  else
    local summary
    summary=$(grep -E '\+[0-9]+ -[0-9]+' "$log" | tail -1 | sed 's/.*\(+[0-9]* -[0-9]*\).*/\1/' || true)
    echo -e "  ${R}${B}✘ FAILED${N} ${D}${summary}${N}"
    FAIL=$((FAIL + 1))
    FAIL_LABELS+=("$label")
    # Indent the key failure lines
    grep -E 'Error:|Expected:|Actual:|══╡' "$log" 2>/dev/null \
      | head -8 \
      | sed "s/^/     /" \
      || true
    echo -e "     ${D}log → $log${N}"
  fi
}

# =============================================================================
# 1  DEVICE SELECTION  (needed for example integration tests)
# =============================================================================
sep2
echo -e "${C}${B}  firebase_update · Test Runner${N}"
sep2
echo ""

DEVICE_ID=""
DEVICE_NAME=""

if [[ "$CLI_NO_DEVICE" == true ]]; then
  echo -e "  ${D}--no-device: skipping all device tests.${N}"
else
  echo -e "${B}  Detecting available devices…${N}"
  echo ""

  # Collect device list into indexed arrays (bash 3 compatible)
  DEV_IDS=(); DEV_NAMES=()
  while IFS= read -r line; do
    did=$(echo "$line"  | awk -F'•' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
    dname=$(echo "$line" | awk -F'•' '{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}')
    [[ -n "$did" ]] || continue
    DEV_IDS+=("$did")
    DEV_NAMES+=("$dname")
  done < <(flutter devices 2>/dev/null | grep '•')

  if [[ -n "$CLI_DEVICE" ]]; then
    # CLI flag provided — match by id substring or 1-based index
    if [[ "$CLI_DEVICE" =~ ^[0-9]+$ ]] && [[ "$CLI_DEVICE" -le "${#DEV_IDS[@]}" ]]; then
      idx=$((CLI_DEVICE - 1))
      DEVICE_ID="${DEV_IDS[$idx]}"
      DEVICE_NAME="${DEV_NAMES[$idx]}"
    else
      # Match by id substring
      for i in "${!DEV_IDS[@]}"; do
        if [[ "${DEV_IDS[$i]}" == *"$CLI_DEVICE"* ]]; then
          DEVICE_ID="${DEV_IDS[$i]}"
          DEVICE_NAME="${DEV_NAMES[$i]}"
          break
        fi
      done
    fi
    if [[ -z "$DEVICE_ID" ]]; then
      echo -e "  ${R}Device '$CLI_DEVICE' not found. Skipping device tests.${N}"
    else
      echo -e "  ${G}Running on:${N} ${B}$DEVICE_NAME${N} ${D}($DEVICE_ID)${N}"
    fi
  elif [[ ${#DEV_IDS[@]} -eq 0 ]]; then
    echo -e "  ${Y}No devices found. Example integration tests will be skipped.${N}"
  else
    echo -e "  ${B}Select a device for example integration tests:${N}"
    echo ""
    for i in "${!DEV_IDS[@]}"; do
      printf "  ${C}${B}[%d]${N}  %s  ${D}(%s)${N}\n" "$((i+1))" "${DEV_NAMES[$i]}" "${DEV_IDS[$i]}"
    done
    echo ""
    printf "  Choice [1-%d, or 0 to skip device tests]: " "${#DEV_IDS[@]}"
    read -r choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
      echo -e "\n  ${D}Skipping example integration tests.${N}"
    else
      idx=$((choice - 1))
      DEVICE_ID="${DEV_IDS[$idx]}"
      DEVICE_NAME="${DEV_NAMES[$idx]}"
      echo -e "\n  ${G}Running on:${N} ${B}$DEVICE_NAME${N} ${D}($DEVICE_ID)${N}"
    fi
  fi
fi

echo ""

# =============================================================================
# 2  PACKAGE UNIT + WIDGET TESTS  (no device needed)
# =============================================================================
sep2
echo -e "${C}${B}  [1/3]  Package Tests${N}  ${D}(no device)${N}"
sep2
echo ""

cd "$PKG_ROOT"
run_suite "firebase_update_test.dart" \
  "$LOG_DIR/firebase_update_test.log" \
  flutter test test/firebase_update_test.dart --reporter=compact

run_suite "firebase_update_flow_integration_test.dart" \
  "$LOG_DIR/firebase_update_flow_integration_test.log" \
  flutter test test/firebase_update_flow_integration_test.dart --reporter=compact

echo ""

# =============================================================================
# 3  EXAMPLE UNIT / WIDGET TESTS  (no device needed)
# =============================================================================
sep2
echo -e "${C}${B}  [2/3]  Example App Tests${N}  ${D}(no device)${N}"
sep2
echo ""

cd "$EXAMPLE_DIR"
run_suite "example/test/widget_test.dart" \
  "$LOG_DIR/example_widget_test.log" \
  flutter test test/widget_test.dart --reporter=compact

echo ""

# =============================================================================
# 4  EXAMPLE INTEGRATION TESTS  (device required)
# =============================================================================
sep2
echo -e "${C}${B}  [3/3]  Example Integration Tests${N}  ${D}(on device)${N}"
sep2
echo ""

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo -e "  ${D}Skipped — no device selected.${N}"
else
  cd "$EXAMPLE_DIR"
  run_suite "integration_test/update_flow_test.dart" \
    "$LOG_DIR/integration_update_flow.log" \
    flutter test integration_test/update_flow_test.dart \
      -d "$DEVICE_ID" --reporter=compact

  run_suite "integration_test/priority_sequence_test.dart" \
    "$LOG_DIR/integration_priority_sequence.log" \
    flutter test integration_test/priority_sequence_test.dart \
      -d "$DEVICE_ID" --reporter=compact

  # live_rc_test talks to Firebase — auto-reads service account key
  SA_JSON="$PKG_ROOT/test/firebase_config/service-account.json"
  echo ""
  if [[ ! -f "$SA_JSON" ]]; then
    echo -e "  ${D}live_rc_test.dart skipped — service-account.json not found at:${N}"
    echo -e "  ${D}  test/firebase_config/service-account.json${N}"
  else
    echo -e "  ${D}live_rc_test.dart hits the Firebase REST API using test/firebase_config/service-account.json${N}"
    if [[ "$CLI_LIVE" == true ]]; then
      run_live="y"
    else
      printf "  Run it? [y/N]: "
      read -r run_live
    fi
    if [[ "$run_live" =~ ^[Yy]$ ]]; then
      # Extract key with literal \n (not actual newlines) so the value is a
      # single-line string. --dart-define-from-file breaks on Android because
      # Flutter URL-encodes the value and the build chain mistakes it for a
      # file path. A single-line --dart-define avoids the entire issue.
      # The test decodes \n back to real newlines before calling RSAPrivateKey.
      SA_KEY=$(python3 -c "
import json
sa = json.load(open('$SA_JSON'))
print(sa['private_key'].replace('\n', '\\\\n'), end='')
" 2>/dev/null || true)
      if [[ -z "$SA_KEY" ]]; then
        echo -e "  ${R}Could not read private_key from service-account.json — skipping.${N}"
      else
        run_suite "integration_test/live_rc_test.dart" \
          "$LOG_DIR/integration_live_rc.log" \
          flutter test integration_test/live_rc_test.dart \
            -d "$DEVICE_ID" --reporter=compact \
            "--dart-define=SA_PRIVATE_KEY=$SA_KEY"
      fi
    else
      echo -e "  ${D}live_rc_test.dart skipped.${N}"
    fi
  fi
fi

echo ""

# =============================================================================
# 5  SUMMARY
# =============================================================================
sep2
echo -e "${C}${B}  Results${N}"
sep2
echo ""
TOTAL=$((PASS + FAIL))
echo -e "  ${B}Total suites:  $TOTAL${N}"
echo -e "  ${G}${B}Passed:        $PASS${N}"

if [[ $FAIL -gt 0 ]]; then
  echo -e "  ${R}${B}Failed:        $FAIL${N}"
  echo ""
  echo -e "  ${R}${B}Failed:${N}"
  for name in "${FAIL_LABELS[@]}"; do
    echo -e "    ${R}✘  $name${N}"
  done
  echo ""
  echo -e "  ${R}${B}Fix the failures above before shipping.${N}"
else
  echo ""
  echo -e "  ${G}${B}✔  All clear — you're good to go!${N}"
  echo -e "  ${G}   Good job, developer. Ship it. 🚀${N}"
fi

echo ""
sep2
echo ""

[[ $FAIL -eq 0 ]]
