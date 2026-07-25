#!/usr/bin/env python3
"""
Parse ESLint JSON output and group errors by file.

Usage:
    python3 parse_eslint_errors.py <eslint-output.json>

Output:
    JSON object mapping file paths to their ESLint errors
"""

import json
import sys
from typing import Dict, List, Any

def parse_eslint_output(eslint_json: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """
    Parse ESLint JSON output and group errors by file.

    Args:
        eslint_json: ESLint JSON output (array of file results)

    Returns:
        Dictionary mapping file paths to arrays of error objects
    """
    errors_by_file: Dict[str, List[Dict[str, Any]]] = {}

    for file_result in eslint_json:
        file_path = file_result.get('filePath', '')
        messages = file_result.get('messages', [])

        # Filter for errors only (not warnings)
        errors = [
            {
                'line': msg.get('line'),
                'column': msg.get('column'),
                'rule': msg.get('ruleId'),
                'message': msg.get('message'),
                'severity': msg.get('severity')
            }
            for msg in messages
            if msg.get('severity') == 2  # 2 = error, 1 = warning
        ]

        # Only include files with errors
        if errors:
            errors_by_file[file_path] = errors

    return errors_by_file

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 parse_eslint_errors.py <eslint-output.json>", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]

    try:
        with open(input_file, 'r') as f:
            eslint_output = json.load(f)
    except FileNotFoundError:
        print(f"Error: File not found: {input_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {input_file}: {e}", file=sys.stderr)
        sys.exit(1)

    errors_by_file = parse_eslint_output(eslint_output)

    # Output as JSON
    print(json.dumps(errors_by_file, indent=2))

    # Exit with non-zero if errors found
    sys.exit(1 if errors_by_file else 0)

if __name__ == '__main__':
    main()
