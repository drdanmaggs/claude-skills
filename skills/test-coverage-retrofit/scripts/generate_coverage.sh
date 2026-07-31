#!/bin/bash
# Generate Vitest coverage report in JSON format
# Usage: ./generate_coverage.sh [scope_path] [skip_pattern]
# Example: ./generate_coverage.sh lib/
# Example with skips: ./generate_coverage.sh lib/ "utils.test.ts|helpers.test.ts"

set -e

SCOPE="${1:-.}"
SKIP_PATTERN="${2:-}"

echo "🔍 Generating coverage report for: $SCOPE"

if [ -n "$SKIP_PATTERN" ]; then
  echo "⚠️  Skipping failing tests: $SKIP_PATTERN"
fi

# Build the command as an ARRAY, not a string.
#
# This was `CMD="npx vitest ..."` assembled by string concatenation and run
# through `eval $CMD`, which re-parses the whole line — so anything in $1 or $2
# that survived quoting was executed, not passed. `./generate_coverage.sh
# 'lib/`id`'` ran `id`, and a scope of `x"; rm -rf ~; echo "` did what it says.
# An array passes every element to the process verbatim: no re-parse, no
# splitting, no globbing, and nothing to escape.
CMD=(
  npx vitest run --coverage
  --coverage.enabled=true
  --coverage.reporter=json
  --coverage.reporter=html
  --coverage.reportsDirectory=./coverage
  "$SCOPE"
)

# Add skip pattern if provided (exclude failing test files)
if [ -n "$SKIP_PATTERN" ]; then
  # Convert pipe-separated list to multiple --exclude flags
  IFS='|' read -ra SKIP_ARRAY <<< "$SKIP_PATTERN"
  for skip in "${SKIP_ARRAY[@]}"; do
    # Quoted so the shell leaves the ** glob for vitest to interpret.
    CMD+=(--exclude "**/${skip}")
  done
fi

# Execute command
"${CMD[@]}"

echo "✅ Coverage reports generated:"
echo "   - JSON: ./coverage/coverage-final.json"
echo "   - HTML: ./coverage/index.html"

if [ -n "$SKIP_PATTERN" ]; then
  echo ""
  echo "⚠️  Note: Coverage excludes failing tests. Review these later:"
  IFS='|' read -ra SKIP_ARRAY <<< "$SKIP_PATTERN"
  for skip in "${SKIP_ARRAY[@]}"; do
    echo "   - $skip"
  done
fi
