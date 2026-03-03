#!/usr/bin/env bash
# scripts/testing/run-all-labs.sh
# Run lab tests across all 20 IT-Stack module repositories.
#
# Usage:
#   bash scripts/testing/run-all-labs.sh
#   bash scripts/testing/run-all-labs.sh --phase 1
#   bash scripts/testing/run-all-labs.sh --module freeipa
#   bash scripts/testing/run-all-labs.sh --lab 01
#   bash scripts/testing/run-all-labs.sh --phase 2 --lab 04
#
# Prerequisites:
#   - All repos cloned under $REPOS_DIR (run clone-all-repos.ps1)
#   - Docker running
#   - Each repo's Compose files functional

set -uo pipefail

REPOS_DIR="${REPOS_DIR:-C:/IT-Stack/it-stack-dev/repos}"
FILTER_PHASE=""
FILTER_MODULE=""
FILTER_LAB=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --phase)  FILTER_PHASE="$2";  shift 2 ;;
    --module) FILTER_MODULE="$2"; shift 2 ;;
    --lab)    FILTER_LAB="$2";    shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Module list: "number name category_dir phase"
declare -a MODULES=(
  "01 freeipa       01-identity       1"
  "02 keycloak      01-identity       1"
  "03 postgresql    02-database       1"
  "04 redis         02-database       1"
  "18 traefik       07-infrastructure 1"
  "06 nextcloud     03-collaboration  2"
  "07 mattermost    03-collaboration  2"
  "08 jitsi         03-collaboration  2"
  "09 iredmail      04-communications 2"
  "11 zammad        04-communications 2"
  "10 freepbx       04-communications 3"
  "12 suitecrm      05-business       3"
  "13 odoo          05-business       3"
  "14 openkm        05-business       3"
  "15 taiga         06-it-management  4"
  "16 snipeit       06-it-management  4"
  "17 glpi          06-it-management  4"
  "05 elasticsearch 02-database       4"
  "19 zabbix        07-infrastructure 4"
  "20 graylog       07-infrastructure 4"
)

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILURES=()

run_lab() {
  local num="$1" mod="$2" cat="$3" phase="$4" lab="$5"
  local repo_path="$REPOS_DIR/$cat/it-stack-$mod"
  local test_script="$repo_path/tests/labs/test-lab-$num-$(printf '%02d' $lab).sh"

  # Apply filters
  [[ -n "$FILTER_PHASE"  && "$phase" != "$FILTER_PHASE"  ]] && return
  [[ -n "$FILTER_MODULE" && "$mod"   != "$FILTER_MODULE" ]] && return
  [[ -n "$FILTER_LAB"    && "$lab"   != "$FILTER_LAB"    ]] && return

  local label="Lab $num-$(printf '%02d' $lab) [$mod]"

  if [[ ! -f "$test_script" ]]; then
    echo "  SKIP: $label (test script not found)"
    ((SKIP_COUNT++))
    return
  fi

  echo ""
  echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
  echo "  Running: $label"
  echo "â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"

  if bash "$test_script"; then
    echo "  RESULT: PASS â€” $label"
    ((PASS_COUNT++))
  else
    echo "  RESULT: FAIL â€” $label"
    ((FAIL_COUNT++))
    FAILURES+=("$label")
  fi
}

echo "IT-Stack Lab Test Runner"
echo "Repos dir: $REPOS_DIR"
echo "Filters: phase=${FILTER_PHASE:-all} module=${FILTER_MODULE:-all} lab=${FILTER_LAB:-all}"
echo ""

for entry in "${MODULES[@]}"; do
  read -r num mod cat phase <<< "$entry"
  for lab in 1 2 3 4 5 6; do
    run_lab "$num" "$mod" "$cat" "$phase" "$lab"
  done
done

echo ""
echo "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
echo "IT-Stack Lab Results"
echo "â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  SKIP: $SKIP_COUNT"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failed labs:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo ""
echo "All labs passed!"