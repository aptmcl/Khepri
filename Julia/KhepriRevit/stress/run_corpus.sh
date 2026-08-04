#!/bin/bash
# Khepri BIM->AD stress corpus driver over the GSG model ladder.
# Usage: run_corpus.sh list | <key> | all
# Per model: two Revit launches — A introspects a disposable copy of the .rvt,
# B rebuilds the generated program on the blank template and compares summaries.
set -u

STRESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS="$STRESS_DIR/corpus.toml"
REVIT="/mnt/c/Program Files/Autodesk/Revit 2024/Revit.exe"
TEMPLATE_WIN='C:\Users\aml\Vault\AML\Projects\Khepri\Julia\KhepriRevit\Plugin\KhepriTemplate.rte'
TEMPLATE_MNT='/mnt/c/Users/aml/Vault/AML/Projects/Khepri/Julia/KhepriRevit/Plugin/KhepriTemplate.rte'
TMP_MNT='/mnt/c/Users/aml/AppData/Local/Temp'
TMP_WIN='C:\Users\aml\AppData\Local\Temp'
PORT_TRIES=60      # x6s = 360s max wait for the plugin on port 11001
JULIA_TIMEOUT=${JULIA_TIMEOUT:-1800} # seconds per julia run (env-overridable for heavy models)

kill_revit() {
  powershell.exe -NoProfile -Command "Stop-Process -Name Revit -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1
}
trap kill_revit EXIT

win_to_mnt() { # 'C:\a\b' -> '/mnt/c/a/b'
  local p="${1//\\//}" drive
  drive="${p%%:*}"
  echo "/mnt/${drive,,}${p#*:}"
}

mnt_to_win() { # '/mnt/c/a/b' -> 'C:\a\b'
  local rest="${1#/mnt/}" drive
  drive="${rest%%/*}"
  rest="${rest#*/}"
  echo "${drive^^}:\\${rest//\//\\}"
}

corpus_keys() {
  sed -n 's/^\[models\.\([A-Za-z0-9_]*\)\]\r\{0,1\}$/\1/p' "$CORPUS"
}

corpus_field() { # key field -> value (quotes stripped), empty if absent
  awk -v sec="[models.$1]" -v fld="$2" -v q="'" '
    { sub(/\r$/, "") }
    $0 == sec { insec = 1; next }
    /^\[/ { insec = 0 }
    insec && $1 == fld && $2 == "=" {
      val = $0
      sub(/^[^=]*=[ \t]*/, "", val)
      c = substr(val, 1, 1)
      if (c == q || c == "\"") val = substr(val, 2, length(val) - 2)
      print val
      exit
    }
  ' "$CORPUS"
}

list_corpus() {
  local k skip desc reason
  for k in $(corpus_keys); do
    skip="$(corpus_field "$k" skip)"
    desc="$(corpus_field "$k" description)"
    if [ "$skip" = "true" ]; then
      reason="$(corpus_field "$k" reason)"
      printf '  %-10s SKIP  %s (%s)\n' "$k" "$desc" "$reason"
    else
      printf '  %-10s run   %s\n' "$k" "$desc"
    fi
  done
}

# launch_and_run <doc_win> <jl_win> <log_file> [VAR=value ...]
# Kill Revit, launch on doc, poll port 11001, run the julia script on Windows
# with the given env vars, kill Revit. Success = 0.
launch_and_run() {
  local doc_win="$1" jl_win="$2" log="$3"
  shift 3
  # Truncate up front: the TIMEOUT path appends, and a leftover log from a prior
  # run would otherwise satisfy the caller's STRESS-OK/PASS grep with stale data.
  : > "$log"
  local envset="" kv k v
  for kv in "$@"; do
    k="${kv%%=*}"
    v="${kv#*=}"
    envset+="\$env:$k='$v'; "
  done
  kill_revit
  sleep 8
  echo "  launching Revit on: ${doc_win##*\\}"
  "$REVIT" "$doc_win" >/dev/null 2>&1 &
  local ready=0 i l
  for i in $(seq 1 "$PORT_TRIES"); do
    l=$(powershell.exe -NoProfile -Command "(Get-NetTCPConnection -LocalPort 11001 -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count" 2>/dev/null | tr -d '[:space:]')
    [ "${l:-0}" = "1" ] && { ready=1; echo "  plugin listening after ~$((i * 6))s"; break; }
    sleep 6
  done
  if [ "$ready" != "1" ]; then
    echo "  TIMEOUT waiting for plugin" | tee -a "$log"
    kill_revit
    return 1
  fi
  sleep 15
  timeout "$JULIA_TIMEOUT" powershell.exe -NoProfile -Command \
    "${envset}julia --project='@v1.12' '$jl_win'; exit \$LASTEXITCODE" >"$log" 2>&1
  local rc=$?
  [ "$rc" = "124" ] && echo "  TIMEOUT: julia run exceeded ${JULIA_TIMEOUT}s" | tee -a "$log"
  kill_revit
  return "$rc"
}

# run_model <key>; sets RESULT to PASS/FAIL-.../SKIP/ERROR
run_model() {
  local key="$1"
  RESULT="ERROR"
  local path skip
  path="$(corpus_field "$key" path)"
  if [ -z "$path" ]; then
    echo "unknown corpus key: $key"
    return 1
  fi
  skip="$(corpus_field "$key" skip)"
  if [ "$skip" = "true" ]; then
    echo "== $key: SKIP ($(corpus_field "$key" reason))"
    RESULT="SKIP"
    return 0
  fi
  local src_mnt rdir rdir_win stress_win copy_mnt copy_win
  src_mnt="$(win_to_mnt "$path")"
  if [ ! -f "$src_mnt" ]; then
    echo "== $key: ERROR (missing model: $src_mnt)"
    return 1
  fi
  rdir="$STRESS_DIR/results/$key"
  mkdir -p "$rdir"
  rdir_win="$(mnt_to_win "$rdir")"
  stress_win="$(mnt_to_win "$STRESS_DIR")"
  copy_mnt="$TMP_MNT/gsg_stress_$key.rvt"
  copy_win="$TMP_WIN\\gsg_stress_$key.rvt"
  echo "== $key: $(corpus_field "$key" description)"
  cp -f "$src_mnt" "$copy_mnt" || { echo "  ERROR: cannot copy model to temp"; return 1; }

  # Launch A: introspect the disposable copy.
  launch_and_run "$copy_win" "$stress_win\\_stress_introspect.jl" "$rdir/introspect.log" \
    "KHEPRI_STRESS_GEN=$rdir_win\\generated.jl" \
    "KHEPRI_STRESS_SUMMARY=$rdir_win\\summary_src.txt"
  if ! grep -q '^STRESS-OK' "$rdir/introspect.log"; then
    echo "  introspection FAILED (see $rdir/introspect.log)"
    grep '^STRESS-FAIL' "$rdir/introspect.log" | head -3
    rm -f "$copy_mnt"
    RESULT="FAIL-introspect"
    return 1
  fi
  rm -f "$copy_mnt"

  # Headless per-element conformance: replay the generated program on the
  # MeasureBackend and compare against the introspection-time ledger (advisory).
  if [ -f "$rdir/ledger.tsv" ]; then
    (cd "$STRESS_DIR/.." && timeout 900 julia --project "$STRESS_DIR/_conformance.jl" \
        "$rdir/generated.jl" "$rdir/ledger.tsv" "$rdir/conformance_report.txt") \
      > "$rdir/conformance.log" 2>&1 || true
    grep -E '^CONFORMANCE' "$rdir/conformance_report.txt" 2>/dev/null | head -1
  fi

  # Launch B: rebuild on the blank template, re-introspect, compare.
  local length_rtol
  length_rtol="$(corpus_field "$key" length_rtol)"
  launch_and_run "$TEMPLATE_WIN" "$stress_win\\_stress_rebuild.jl" "$rdir/rebuild.log" \
    "KHEPRI_STRESS_LENGTH_RTOL=${length_rtol:-0.01}" \
    "KHEPRI_STRESS_GEN=$rdir_win\\generated.jl" \
    "KHEPRI_STRESS_SUMMARY_SRC=$rdir_win\\summary_src.txt" \
    "KHEPRI_STRESS_SUMMARY_REBUILT=$rdir_win\\summary_rebuilt.txt" \
    "KHEPRI_STRESS_REPORT=$rdir_win\\report.txt" \
    "KHEPRI_STRESS_GEN2=$rdir_win\\generated2.jl"
  if grep -q '^STRESS-PASS' "$rdir/rebuild.log"; then
    # Fixpoint drift: normalized line diff between the generated program and the
    # re-introspection of the rebuild (advisory; convergence = 0 differing lines).
    if [ -f "$rdir/generated2.jl" ]; then
      diff <(grep -v 'Generated on:' "$rdir/generated.jl") \
           <(grep -v 'Generated on:' "$rdir/generated2.jl") \
        > "$rdir/fixpoint_diff.txt" || true
      echo "  fixpoint drift: $(grep -c '^[<>]' "$rdir/fixpoint_diff.txt") differing lines (fixpoint_diff.txt)"
    fi
    echo "  $key: PASS"
    RESULT="PASS"
    return 0
  fi
  echo "  rebuild/compare FAILED (see $rdir/rebuild.log)"
  grep -E '^(STRESS-FAIL|FAIL )' "$rdir/rebuild.log" | head -10
  RESULT="FAIL-rebuild"
  return 1
}

usage() {
  echo "usage: $(basename "$0") list | <key> | all"
  echo "corpus ($CORPUS):"
  list_corpus
}

[ -f "$CORPUS" ] || { echo "missing corpus: $CORPUS"; exit 2; }
[ $# -ge 1 ] || { usage; exit 2; }

case "$1" in
  list)
    list_corpus
    exit 0
    ;;
  all)
    KEYS="$(corpus_keys)"
    ;;
  *)
    KEYS="$1"
    ;;
esac

[ -f "$TEMPLATE_MNT" ] || { echo "missing blank template: $TEMPLATE_MNT"; exit 2; }

declare -a TABLE=()
ANY_FAIL=0
for key in $KEYS; do
  RESULT="ERROR"
  run_model "$key" || true
  TABLE+=("$key $RESULT")
  case "$RESULT" in PASS | SKIP) ;; *) ANY_FAIL=1 ;; esac
done

echo
echo "== corpus results =="
for row in "${TABLE[@]}"; do
  printf '  %-10s %s\n' ${row}
done
exit "$ANY_FAIL"
