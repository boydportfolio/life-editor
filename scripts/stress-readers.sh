#!/bin/zsh
set -eu
cd "${0:A:h:h}"
if [[ ${1:-} == --help ]]; then
  print -r -- 'Usage: scripts/stress-readers.sh [rounds:1-100] [scratch-directory] [new-artifact-directory]'
  print -r -- 'Runs native four-camera supersession and concurrent-export/cancellation checks with reader traces.'
  exit 0
fi
rounds=${1:-20}
if [[ $rounds != <-> ]] || (( rounds < 1 || rounds > 100 )); then
  print -u2 -r -- 'Use 1 to 100 rounds.'
  exit 2
fi
scratch_directory=${2:-/tmp/life-reader-stress-build}
artifact_directory=${3:-/tmp/life-reader-stress-$(date +%Y%m%d-%H%M%S)-$$}
# Refuse existing artifacts so a successful rerun cannot replace crash evidence.
if [[ -e $artifact_directory ]]; then
  print -u2 -r -- 'Choose a new artifact directory; existing evidence is preserved.'
  exit 2
fi
mkdir -p "$artifact_directory"
artifact_directory=${artifact_directory:A}
selection='fourCameraWaveformSwitchRefineReopenExportKeepsSeparateMaster|concurrentNativeExportsKeepExecutorResponsiveAndProtectCancelledDestination'
for (( round=1; round<=rounds; round++ )); do
  name=$(printf 'round-%02d' $round)
  print -r -- "Starting $name of $rounds"
  if LIFE_RUN_MEDIA_INTEGRATION=1 LIFE_NATIVE_READER_TRACE="$artifact_directory/$name.jsonl" \
      scripts/test.sh --scratch-path "$scratch_directory" --filter "$selection" --no-parallel \
      > "$artifact_directory/$name.log" 2>&1; then
    print -r -- "$name passed" | tee -a "$artifact_directory/summary.txt"
  else
    result=$?
    print -r -- "$name failed with exit $result; logs and trace: $artifact_directory" | tee -a "$artifact_directory/summary.txt"
    exit $result
  fi
done
print -r -- "All $rounds rounds passed. Evidence: $artifact_directory"
