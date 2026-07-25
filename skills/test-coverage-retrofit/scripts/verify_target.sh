#!/bin/bash
# Verify if coverage target has been reached
# Usage: ./verify_target.sh [target_pct] [scope]
# Example: ./verify_target.sh 80 lib/

set -e

TARGET="${1:-80}"
SCOPE="${2:-.}"

echo "🎯 Verifying coverage target: ${TARGET}%"
echo "   Scope: $SCOPE"
echo ""

# Run coverage
./scripts/generate_coverage.sh "$SCOPE" > /dev/null 2>&1

# Parse coverage JSON to get overall percentage
COVERAGE_FILE="./coverage/coverage-final.json"

if [ ! -f "$COVERAGE_FILE" ]; then
    echo "❌ Coverage file not found: $COVERAGE_FILE"
    exit 1
fi

# Calculate overall coverage using Python
CURRENT_PCT=$(python3 -c "
import json
import sys

with open('$COVERAGE_FILE', 'r') as f:
    data = json.load(f)

total_statements = 0
covered_statements = 0

for file_path, file_data in data.items():
    if '$SCOPE' not in file_path:
        continue

    statements = file_data.get('s', {})
    total_statements += len(statements)
    covered_statements += sum(1 for count in statements.values() if count > 0)

if total_statements == 0:
    print('0.0')
else:
    pct = (covered_statements / total_statements) * 100
    print(f'{pct:.1f}')
")

echo "📊 Current coverage: ${CURRENT_PCT}%"
echo "🎯 Target: ${TARGET}%"
echo ""

# Compare
if (( $(echo "$CURRENT_PCT >= $TARGET" | bc -l) )); then
    echo "✅ TARGET REACHED! Coverage is at ${CURRENT_PCT}%"
    exit 0
else
    GAP=$(echo "$TARGET - $CURRENT_PCT" | bc -l)
    echo "⚠️  Not yet at target. Gap: ${GAP}%"
    exit 1
fi
