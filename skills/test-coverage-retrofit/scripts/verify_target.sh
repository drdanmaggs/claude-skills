#!/bin/bash
# Verify if coverage target has been reached
# Usage: ./verify_target.sh [target_pct] [scope]
# Example: ./verify_target.sh 80 lib/

set -e

TARGET="${1:-80}"
SCOPE="${2:-.}"

# Resolve the sibling script from THIS script's directory, not the caller's.
# SKILL.md documents invoking this as
# `bash <skill-path>/scripts/verify_target.sh 95 lib/` from the project root,
# where the old hardcoded ./scripts/generate_coverage.sh resolved against the
# project — so it either missed, or found an unrelated script of the same name.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🎯 Verifying coverage target: ${TARGET}%"
echo "   Scope: $SCOPE"
echo ""

# Run coverage
"$SCRIPT_DIR/generate_coverage.sh" "$SCOPE" > /dev/null 2>&1

# The report itself IS cwd-relative — it's an artifact of the project being
# measured, not of the skill.
COVERAGE_FILE="./coverage/coverage-final.json"

if [ ! -f "$COVERAGE_FILE" ]; then
    echo "❌ Coverage file not found: $COVERAGE_FILE"
    exit 1
fi

# Calculate coverage and evaluate the target in one Python call.
#
# The values travel through the ENVIRONMENT and the program text is
# single-quoted, so the shell expands nothing inside it and neither the scope
# nor the path is ever part of the source. These used to be interpolated
# directly: a scope containing an apostrophe closed the string literal
# ("SyntaxError: unterminated string literal") and anything past it was parsed
# as Python.
#
# Comparing here too drops the `bc` dependency, which is absent from many
# minimal images.
RESULT=$(
  COVERAGE_FILE="$COVERAGE_FILE" SCOPE="$SCOPE" TARGET="$TARGET" python3 -c '
import json, os

with open(os.environ["COVERAGE_FILE"], "r") as f:
    data = json.load(f)

scope = os.environ["SCOPE"]
target = float(os.environ["TARGET"])

total_statements = 0
covered_statements = 0

for file_path, file_data in data.items():
    if scope not in file_path:
        continue

    statements = file_data.get("s", {})
    total_statements += len(statements)
    covered_statements += sum(1 for count in statements.values() if count > 0)

pct = 0.0 if total_statements == 0 else (covered_statements / total_statements) * 100

# Judge the rounded figure, so the number reported is the number judged.
# Otherwise 66.666% prints as 66.7% and then fails a target of 66.7.
met = "yes" if round(pct, 1) >= target else "no"
gap = max(0.0, target - pct)

print(f"{pct:.1f} {met} {gap:.1f}")
'
)
read -r CURRENT_PCT MET GAP <<< "$RESULT"

echo "📊 Current coverage: ${CURRENT_PCT}%"
echo "🎯 Target: ${TARGET}%"
echo ""

if [ "$MET" = "yes" ]; then
    echo "✅ TARGET REACHED! Coverage is at ${CURRENT_PCT}%"
    exit 0
else
    echo "⚠️  Not yet at target. Gap: ${GAP}%"
    exit 1
fi
