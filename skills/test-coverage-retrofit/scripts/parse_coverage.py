#!/usr/bin/env python3
"""
Parse Vitest coverage JSON and identify high-priority uncovered files.

Prioritization heuristics:
1. Critical paths (business logic, server actions logic, API routes)
2. Impact (uncovered lines that would boost overall % most)
3. Skip low-value files (config, types-only, test files)

Output: Structured JSON for tracker generation

Test type classification:
- --test-type unit: Force all files to unit classification
- --test-type integration: Force all files to integration classification
- --test-type e2e: Filter to only E2E test candidates (tests/e2e/, page routes)
- --test-type all (default): Auto-classify based on file patterns
"""

import json
import sys
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict

@dataclass
class UncoveredFile:
    path: str
    coverage_pct: float
    total_lines: int
    uncovered_lines: int
    priority: int  # 1=critical, 2=high, 3=medium
    test_type: str  # 'unit' or 'integration'
    functions: List[Dict[str, any]]

def is_critical_path(file_path: str) -> bool:
    """Identify critical business logic files."""
    critical_patterns = [
        'logic.ts',  # Server action logic files
        'actions.ts',  # Server actions
        '/api/',  # API routes
        '/lib/',  # Business logic libraries
    ]
    return any(pattern in file_path for pattern in critical_patterns)

def is_skip_file(file_path: str) -> bool:
    """Skip low-value files."""
    skip_patterns = [
        '.test.',
        '.spec.',
        '.config.',
        '.d.ts',  # Type definitions only
        'node_modules/',
        '.next/',
        'dist/',
    ]
    return any(pattern in file_path for pattern in skip_patterns)

def is_e2e_candidate(file_path: str) -> bool:
    """
    Determine if file is an E2E test candidate.

    E2E test candidates:
    - Files in tests/e2e/ directory
    - Page routes (page.tsx, page.ts in app/ directory)
    - Route handlers in app/ directory
    """
    e2e_patterns = [
        'tests/e2e/',
        '/e2e/',
        'page.tsx',
        'page.ts',
        'layout.tsx',
        'layout.ts',
    ]

    return any(pattern in file_path for pattern in e2e_patterns)

def classify_test_type(file_path: str, file_content: str = None, force_type: str = None) -> str:
    """
    Classify file as 'unit', 'integration', or 'e2e' test candidate.

    Args:
        file_path: Path to the file
        file_content: Optional file content (read from disk if not provided)
        force_type: If set, force classification to this type ('unit', 'integration', 'e2e')
                   Set to 'auto' for automatic classification (default behavior)

    Integration tests:
    - Server actions (actions.ts files)
    - Files using createIsolatedTestHousehold
    - Files with Supabase operations (.from, .insert, .delete)
    - API routes

    Unit tests:
    - Extracted business logic (logic.ts files)
    - Utility/helper functions
    - Files using vi.mock() heavily

    E2E tests:
    - Files in tests/e2e/ directory
    - Page routes (page.tsx in app/ directory)

    Default to 'unit' if unclear (lighter verification is safer).
    """

    # If force_type is set, use it
    if force_type in ['unit', 'integration', 'e2e']:
        return force_type

    # Strong signals from filename
    if file_path.endswith('logic.ts'):
        return 'unit'  # Extracted business logic

    if file_path.endswith('actions.ts'):
        return 'integration'  # Server actions

    # Check for E2E candidate
    if is_e2e_candidate(file_path):
        return 'e2e'

    # Strong signals from path
    if '/api/' in file_path:
        return 'integration'  # API routes

    # Read file content if not provided
    if file_content is None:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                file_content = f.read()
        except:
            # If we can't read the file, default to unit
            return 'unit'

    # Pattern matching on file content
    integration_patterns = [
        'createClient',
        'createIsolatedTestHousehold',
        '.from(',
        'describe.sequential',
        'cookies()',
        'headers()',
    ]

    unit_patterns = [
        '/utils/',
        '/helpers/',
        '/lib/',
        'vi.mock(',
        '@testing-library/react',
    ]

    # Score based on patterns
    integration_score = sum(1 for p in integration_patterns if p in file_content)
    unit_score = sum(1 for p in unit_patterns if (p in file_path or p in file_content))

    # Default to unit (lighter verification is safer)
    return 'integration' if integration_score > unit_score else 'unit'

def calculate_priority(file_path: str, coverage_pct: float, uncovered_lines: int) -> int:
    """Calculate file priority (1=highest, 3=lowest)."""
    if is_critical_path(file_path):
        return 1
    elif uncovered_lines > 50:  # High impact
        return 2
    else:
        return 3

def extract_uncovered_functions(file_data: dict) -> List[Dict]:
    """Extract uncovered or partially covered functions from file."""
    functions = []

    # Parse function coverage from V8/Istanbul report
    if 'fnMap' in file_data and 'f' in file_data:
        fn_map = file_data['fnMap']
        fn_coverage = file_data['f']

        for fn_id, fn_data in fn_map.items():
            hit_count = fn_coverage.get(fn_id, 0)
            if hit_count == 0:  # Completely uncovered
                functions.append({
                    'name': fn_data.get('name', 'anonymous'),
                    'line': fn_data['loc']['start']['line'],
                    'coverage': 0
                })

    return functions

def parse_coverage_report(coverage_path: str, scope: str = None, test_type_filter: str = 'all') -> List[UncoveredFile]:
    """
    Parse coverage JSON and return prioritized list of uncovered files.

    Args:
        coverage_path: Path to coverage-final.json
        scope: Optional scope filter (e.g., "lib/")
        test_type_filter: Filter/force test type classification
            - 'unit': Force all files to unit classification
            - 'integration': Force all files to integration classification
            - 'e2e': Only include E2E test candidates
            - 'all': Auto-classify (default)
    """

    with open(coverage_path, 'r') as f:
        coverage_data = json.load(f)

    uncovered_files = []

    # Determine force type for classification
    force_type = None if test_type_filter == 'all' else test_type_filter

    for file_path, file_data in coverage_data.items():
        # Apply scope filter
        if scope and not file_path.startswith(scope):
            continue

        # Skip unwanted files
        if is_skip_file(file_path):
            continue

        # For E2E filter, skip non-E2E candidates early
        if test_type_filter == 'e2e' and not is_e2e_candidate(file_path):
            continue

        # Calculate coverage
        statements = file_data.get('s', {})
        total_statements = len(statements)
        covered_statements = sum(1 for count in statements.values() if count > 0)

        if total_statements == 0:
            continue

        coverage_pct = (covered_statements / total_statements) * 100
        uncovered_lines = total_statements - covered_statements

        # Only include files below 80% coverage
        if coverage_pct >= 80:
            continue

        # Extract uncovered functions
        functions = extract_uncovered_functions(file_data)

        # Calculate priority
        priority = calculate_priority(file_path, coverage_pct, uncovered_lines)

        # Classify test type (with optional force)
        test_type = classify_test_type(file_path, force_type=force_type)

        uncovered_files.append(UncoveredFile(
            path=file_path,
            coverage_pct=coverage_pct,
            total_lines=total_statements,
            uncovered_lines=uncovered_lines,
            priority=priority,
            test_type=test_type,
            functions=functions
        ))

    # Sort by priority, then by impact (uncovered lines)
    uncovered_files.sort(key=lambda f: (f.priority, -f.uncovered_lines))

    return uncovered_files

def main():
    parser = argparse.ArgumentParser(
        description='Parse Vitest coverage JSON and classify files by test type'
    )
    parser.add_argument(
        'coverage_path',
        help='Path to coverage-final.json'
    )
    parser.add_argument(
        'scope',
        nargs='?',
        default=None,
        help='Optional scope filter (e.g., "lib/")'
    )
    parser.add_argument(
        '--test-type',
        choices=['unit', 'integration', 'e2e', 'all'],
        default='all',
        help='Test type filter: unit (force all to unit), integration (force all to integration), e2e (only E2E candidates), all (auto-classify)'
    )

    args = parser.parse_args()

    if not Path(args.coverage_path).exists():
        print(f"Error: Coverage file not found: {args.coverage_path}", file=sys.stderr)
        sys.exit(1)

    uncovered_files = parse_coverage_report(args.coverage_path, args.scope, args.test_type)

    # Output as JSON
    output = {
        'test_type_filter': args.test_type,
        'total_files': len(uncovered_files),
        'unit_files': len([f for f in uncovered_files if f.test_type == 'unit']),
        'integration_files': len([f for f in uncovered_files if f.test_type == 'integration']),
        'e2e_files': len([f for f in uncovered_files if f.test_type == 'e2e']),
        'priority_1_files': len([f for f in uncovered_files if f.priority == 1]),
        'priority_2_files': len([f for f in uncovered_files if f.priority == 2]),
        'priority_3_files': len([f for f in uncovered_files if f.priority == 3]),
        'files': [
            {
                'path': f.path,
                'test_type': f.test_type,
                'coverage_pct': round(f.coverage_pct, 1),
                'total_lines': f.total_lines,
                'uncovered_lines': f.uncovered_lines,
                'priority': f.priority,
                'functions': f.functions
            }
            for f in uncovered_files
        ]
    }

    print(json.dumps(output, indent=2))

if __name__ == '__main__':
    main()
