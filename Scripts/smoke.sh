#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p docs/evidence
stamp="$(date +%Y%m%d-%H%M%S)"
result="$PWD/docs/evidence/smoke-$stamp.txt"
errors="$PWD/docs/evidence/smoke-$stamp-errors.txt"
open -n -W --stdout "$result" --stderr "$errors" "$PWD/dist/OpenAudio.app" --args --smoke "$@"
cat "$result" "$errors"
rg -q '^SMOKE PASS:' "$result"
