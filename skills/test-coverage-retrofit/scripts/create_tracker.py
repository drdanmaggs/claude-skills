#!/usr/bin/env python3
"""
Generate tracking document from parsed coverage data.

Input: JSON from parse_coverage.py
Output: Markdown tracking document similar to TDD plan format
"""

import json
import sys
from pathlib import Path
from datetime import datetime

def group_files_by_folder(files: list) -> dict:
    """Group files by their parent folder."""
    from collections import defaultdict
    import os

    folder_groups = defaultdict(list)

    for file_info in files:
        file_path = file_info['path']
        folder = os.path.dirname(file_path)
        if not folder:
            folder = '.'
        folder_groups[folder].append(file_info)

    return dict(folder_groups)

def calculate_folder_priority(folder_path: str, files: list) -> int:
    """Calculate folder priority based on importance and coverage."""
    # Critical folders (Priority 1)
    critical_patterns = ['auth', 'api', 'core', 'security']
    if any(pattern in folder_path.lower() for pattern in critical_patterns):
        return 1

    # High impact folders (Priority 2) - low average coverage
    avg_coverage = sum(f['coverage_pct'] for f in files) / len(files)
    if avg_coverage < 30:
        return 2

    # Medium impact (Priority 3)
    return 3

def generate_tracker_markdown(coverage_data: dict, target_pct: float, scope: str) -> str:
    """Generate markdown tracking document organized by test type, then folder."""

    current_overall = calculate_overall_coverage(coverage_data)
    unit_count = coverage_data.get('unit_files', 0)
    integration_count = coverage_data.get('integration_files', 0)

    md = f"""# Test Coverage Retrofit Tracker

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Target:** {target_pct}% overall coverage
**Current:** {current_overall:.1f}%
**Scope:** {scope or 'entire codebase'}

**Strategy:** Two-phase approach
1. **Phase 1: Unit tests** → {target_pct}% (fast wins, lighter verification)
2. **Phase 2: Integration tests** (only if needed, strict verification)

**Early stopping:** If Phase 1 reaches {target_pct}%, Phase 2 is skipped.

**Files:** {unit_count} unit, {integration_count} integration

---

"""

    # Separate by test type
    unit_files = [f for f in coverage_data['files'] if f.get('test_type') == 'unit']
    integration_files = [f for f in coverage_data['files'] if f.get('test_type') == 'integration']

    # Generate Phase 1: Unit Tests
    md += f"## PHASE 1: UNIT TESTS (Target: {target_pct}%)\n\n"
    md += "Unit tests are faster to write and less flaky. We process these first.\n\n"

    # Group unit files by folder
    folder_groups = group_files_by_folder(unit_files)

    # Calculate priority and average coverage for each folder
    folder_stats = []
    for folder_path, files in folder_groups.items():
        avg_coverage = sum(f['coverage_pct'] for f in files) / len(files)
        priority = calculate_folder_priority(folder_path, files)
        folder_stats.append({
            'path': folder_path,
            'files': files,
            'avg_coverage': avg_coverage,
            'priority': priority,
            'file_count': len(files)
        })

    # Sort folders by priority, then by average coverage (lowest first)
    folder_stats.sort(key=lambda f: (f['priority'], f['avg_coverage']))

    # Generate Phase 1 folders
    for folder_info in folder_stats:
        folder_path = folder_info['path']
        avg_coverage = folder_info['avg_coverage']
        files = folder_info['files']

        md += f"### Folder: {folder_path}/ ({avg_coverage:.0f}% avg coverage)\n\n"

        for file_info in files:
            file_path = file_info['path']
            coverage_pct = file_info['coverage_pct']
            uncovered_lines = file_info['uncovered_lines']
            functions = file_info['functions']

            # Use markdown checkbox format like TDD skill
            md += f"- [ ] `{file_path}` — {coverage_pct:.1f}% coverage, {uncovered_lines} uncovered lines\n"

            if functions and len(functions) > 0:
                md += "  <details>\n"
                md += "  <summary>Uncovered functions</summary>\n\n"
                for func in functions[:10]:  # Limit to first 10
                    func_name = func['name']
                    func_line = func['line']
                    md += f"  - `{func_name}` (line {func_line})\n"

                if len(functions) > 10:
                    md += f"  - ...and {len(functions) - 10} more\n"

                md += "  </details>\n\n"
            else:
                md += "\n"

        md += "\n"

    # Generate Phase 2: Integration Tests
    md += "---\n\n"
    md += f"## PHASE 2: INTEGRATION TESTS (Only if Phase 1 < {target_pct}%)\n\n"
    md += "Integration tests require real DB, cleanup, and multi-run verification.\n\n"

    # Group integration files by folder
    integration_folder_groups = group_files_by_folder(integration_files)

    # Calculate folder stats for integration files
    integration_folder_stats = []
    for folder_path, files in integration_folder_groups.items():
        avg_coverage = sum(f['coverage_pct'] for f in files) / len(files)
        priority = calculate_folder_priority(folder_path, files)
        integration_folder_stats.append({
            'path': folder_path,
            'files': files,
            'avg_coverage': avg_coverage,
            'priority': priority,
            'file_count': len(files)
        })

    # Sort folders by priority, then by average coverage (lowest first)
    integration_folder_stats.sort(key=lambda f: (f['priority'], f['avg_coverage']))

    # Generate Phase 2 folders
    for folder_info in integration_folder_stats:
        folder_path = folder_info['path']
        avg_coverage = folder_info['avg_coverage']
        files = folder_info['files']

        md += f"### Folder: {folder_path}/ ({avg_coverage:.0f}% avg coverage)\n\n"

        for file_info in files:
            file_path = file_info['path']
            coverage_pct = file_info['coverage_pct']
            uncovered_lines = file_info['uncovered_lines']
            functions = file_info['functions']

            md += f"- [ ] `{file_path}` — {coverage_pct:.1f}% coverage, {uncovered_lines} uncovered lines\n"

            if functions and len(functions) > 0:
                md += "  <details>\n"
                md += "  <summary>Uncovered functions</summary>\n\n"
                for func in functions[:10]:
                    func_name = func['name']
                    func_line = func['line']
                    md += f"  - `{func_name}` (line {func_line})\n"

                if len(functions) > 10:
                    md += f"  - ...and {len(functions) - 10} more\n"

                md += "  </details>\n\n"
            else:
                md += "\n"

        md += "\n"

    return md

def calculate_overall_coverage(coverage_data: dict) -> float:
    """Calculate overall coverage percentage from files data."""
    total_lines = sum(f['total_lines'] for f in coverage_data['files'])
    covered_lines = sum(
        f['total_lines'] - f['uncovered_lines']
        for f in coverage_data['files']
    )

    if total_lines == 0:
        return 100.0

    return (covered_lines / total_lines) * 100

def main():
    if len(sys.argv) < 2:
        print("Usage: create_tracker.py <parsed_coverage.json> [output_path] [target_pct] [scope]")
        print("Example: create_tracker.py coverage_data.json .claude/docs/test-retrofit-tracker.md 80 lib/")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else '.claude/docs/test-retrofit-tracker.md'
    target_pct = float(sys.argv[3]) if len(sys.argv) > 3 else 95.0
    scope = sys.argv[4] if len(sys.argv) > 4 else 'entire codebase'

    if not Path(input_path).exists():
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    with open(input_path, 'r') as f:
        coverage_data = json.load(f)

    markdown = generate_tracker_markdown(coverage_data, target_pct, scope)

    # Ensure output directory exists
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        f.write(markdown)

    print(f"✅ Tracker generated: {output_path}")
    print(f"   Files to cover: {coverage_data['total_files']}")
    print(f"   Target: {target_pct}% coverage")

if __name__ == '__main__':
    main()
