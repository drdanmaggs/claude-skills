#!/usr/bin/env python3
"""
Critical Path Testing - Criticality Scoring Script

Calculates risk-based criticality scores (0-100) for TypeScript files.

Usage:
    python calculate_criticality.py [--project-root PATH] [--output PATH]

Output: JSON file with criticality scores per file
"""

import os
import sys
import json
import hashlib
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from collections import defaultdict


@dataclass
class CriticalityScore:
    """Criticality score breakdown for a file"""
    file: str
    score: int
    breakdown: Dict[str, int]
    details: Dict[str, any]
    reason: str
    test_type: str
    priority: str


class CriticalityScorer:
    """Calculate criticality scores for TypeScript files"""

    # Domain category scores (max 40 points)
    DOMAIN_SCORES = {
        'authentication': 40,
        'payments': 40,
        'data_integrity': 35,
        'rls_policies': 35,
        'api_routes': 30,
        'business_logic': 20,
        'utilities': 5,
    }

    # Thresholds for priority classification
    PRIORITY_THRESHOLDS = {
        80: 'CRITICAL',
        60: 'HIGH',
        40: 'MEDIUM',
        0: 'LOW',
    }

    def __init__(self, project_root: str):
        self.project_root = Path(project_root).resolve()
        self.git_log_cache = None
        self.coverage_data = None
        self.test_fixer_memory = None
        self.fan_in_cache = None

    def calculate_project_hash(self) -> str:
        """Calculate project hash for test-fixer memory lookup"""
        workspace_root = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            cwd=self.project_root
        )

        if workspace_root.returncode == 0:
            root = workspace_root.stdout.strip()
        else:
            root = str(self.project_root)

        return hashlib.sha256(root.encode()).hexdigest()[:32]

    def load_test_fixer_memory(self) -> Dict[str, List[str]]:
        """Load test-fixer memory for this project"""
        project_hash = self.calculate_project_hash()
        memory_dir = Path.home() / '.claude' / 'skills' / 'test-fixer' / 'memory' / project_hash

        memory = {'common_failures': [], 'test_fixes': [], 'critical_paths': []}

        if memory_dir.exists():
            # Read common-failures.md
            common_failures = memory_dir / 'common-failures.md'
            if common_failures.exists():
                memory['common_failures'] = common_failures.read_text().splitlines()

            # Read test-fixes.md
            test_fixes = memory_dir / 'test-fixes.md'
            if test_fixes.exists():
                memory['test_fixes'] = test_fixes.read_text().splitlines()

            # Read critical-path-coverage.md
            critical_paths = memory_dir / 'critical-path-coverage.md'
            if critical_paths.exists():
                memory['critical_paths'] = critical_paths.read_text().splitlines()

        self.test_fixer_memory = memory
        return memory

    def load_coverage_data(self) -> Dict[str, Dict]:
        """Load test coverage data if available"""
        coverage_file = self.project_root / 'coverage' / 'coverage-final.json'

        if coverage_file.exists():
            with open(coverage_file) as f:
                self.coverage_data = json.load(f)
        else:
            self.coverage_data = {}

        return self.coverage_data

    def get_git_log_recent_bugs(self, days: int = 90) -> Dict[str, int]:
        """Get files with recent bug fixes from git log"""
        if self.git_log_cache is not None:
            return self.git_log_cache

        try:
            result = subprocess.run(
                ['git', 'log', f'--since={days} days ago', '--grep=fix\\|bug', '--name-only', '--pretty=format:'],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )

            bug_counts = defaultdict(int)
            for line in result.stdout.splitlines():
                line = line.strip()
                if line and line.endswith('.ts') and not line.endswith('.test.ts'):
                    bug_counts[line] += 1

            self.git_log_cache = dict(bug_counts)
        except Exception as e:
            print(f"Warning: Could not read git log: {e}", file=sys.stderr)
            self.git_log_cache = {}

        return self.git_log_cache

    def calculate_fan_in(self, file_path: str) -> int:
        """Calculate how many files import this file"""
        if self.fan_in_cache is None:
            self.fan_in_cache = {}

        if file_path in self.fan_in_cache:
            return self.fan_in_cache[file_path]

        # Extract module name without extension
        module_name = Path(file_path).stem

        try:
            result = subprocess.run(
                ['grep', '-r', f'import.*from.*{module_name}',
                 '--include=*.ts', '--include=*.tsx', '.'],
                capture_output=True,
                text=True,
                cwd=self.project_root
            )

            # Count unique files that import this module
            importing_files = set()
            for line in result.stdout.splitlines():
                if ':' in line:
                    file = line.split(':')[0]
                    if file != file_path:  # Don't count self-imports
                        importing_files.add(file)

            count = len(importing_files)
            self.fan_in_cache[file_path] = count
            return count

        except Exception as e:
            print(f"Warning: Could not calculate fan-in for {file_path}: {e}", file=sys.stderr)
            return 0

    def detect_domain_category(self, file_path: str, content: str) -> Tuple[str, int]:
        """Detect domain category from file path and content"""
        # Path-based detection
        if 'auth' in file_path.lower():
            return 'authentication', self.DOMAIN_SCORES['authentication']
        if 'payment' in file_path.lower() or 'billing' in file_path.lower() or 'stripe' in file_path.lower():
            return 'payments', self.DOMAIN_SCORES['payments']
        if '/api/' in file_path and 'route.ts' in file_path:
            return 'api_routes', self.DOMAIN_SCORES['api_routes']
        if 'rls' in file_path.lower() or 'policies' in file_path.lower():
            return 'rls_policies', self.DOMAIN_SCORES['rls_policies']
        if 'utils' in file_path.lower() or 'helpers' in file_path.lower():
            return 'utilities', self.DOMAIN_SCORES['utilities']

        # Content-based detection
        content_lower = content.lower()

        auth_patterns = ['login', 'authenticate', 'session', 'jwt', 'oauth', 'signup', 'password']
        if any(pattern in content_lower for pattern in auth_patterns):
            return 'authentication', self.DOMAIN_SCORES['authentication']

        payment_patterns = ['stripe', 'payment', 'checkout', 'subscription', 'invoice', 'billing']
        if any(pattern in content_lower for pattern in payment_patterns):
            return 'payments', self.DOMAIN_SCORES['payments']

        data_patterns = ['household', 'user data', 'create user', 'update user', 'delete user']
        if any(pattern in content_lower for pattern in data_patterns):
            return 'data_integrity', self.DOMAIN_SCORES['data_integrity']

        # Default to business logic
        return 'business_logic', self.DOMAIN_SCORES['business_logic']

    def calculate_complexity_score(self, content: str) -> int:
        """Calculate complexity score (max 5 points)"""
        lines = content.splitlines()
        loc = len([line for line in lines if line.strip()])

        # Count conditional complexity
        conditionals = len(re.findall(r'\b(if|else|switch|case|for|while|catch)\b', content))

        # Count nesting depth (rough estimate)
        max_nesting = max((line.count('  ') for line in lines), default=0) // 2

        score = 0
        if loc > 300:
            score += 2
        if conditionals > 10:
            score += 2
        if max_nesting > 4:
            score += 1

        return min(score, 5)

    def has_external_dependencies(self, content: str) -> bool:
        """Check if file has external dependencies"""
        external_patterns = [
            r'@supabase',
            r'stripe',
            r'openai',
            r'fetch\(',
            r'axios',
        ]

        return any(re.search(pattern, content, re.IGNORECASE) for pattern in external_patterns)

    def is_entry_point(self, file_path: str, content: str) -> bool:
        """Check if file is an entry point (API route, server action, etc.)"""
        # API routes
        if '/api/' in file_path and 'route.ts' in file_path:
            return True

        # Server actions
        if '"use server"' in content or "'use server'" in content:
            return True

        # Webhook handlers
        if 'webhook' in file_path.lower():
            return True

        return False

    def file_in_memory(self, file_path: str) -> bool:
        """Check if file appears in test-fixer memory"""
        if not self.test_fixer_memory:
            self.load_test_fixer_memory()

        file_name = Path(file_path).name

        # Search all memory files
        all_memory = (
            self.test_fixer_memory.get('common_failures', []) +
            self.test_fixer_memory.get('test_fixes', []) +
            self.test_fixer_memory.get('critical_paths', [])
        )

        return any(file_name in line for line in all_memory)

    def get_test_coverage(self, file_path: str) -> float:
        """Get test coverage percentage for file"""
        if not self.coverage_data:
            self.load_coverage_data()

        # Try different path formats
        abs_path = str(self.project_root / file_path)

        for key in self.coverage_data.keys():
            if file_path in key or abs_path in key:
                return self.coverage_data[key].get('lines', {}).get('pct', 0)

        return 0

    def has_tests(self, file_path: str) -> bool:
        """Check if test file exists for this file"""
        test_patterns = [
            file_path.replace('.ts', '.test.ts'),
            file_path.replace('.ts', '.spec.ts'),
            file_path.replace('.tsx', '.test.tsx'),
            file_path.replace('.tsx', '.spec.tsx'),
        ]

        return any((self.project_root / pattern).exists() for pattern in test_patterns)

    def calculate_score(self, file_path: str) -> CriticalityScore:
        """Calculate complete criticality score for a file"""
        # Read file content
        full_path = self.project_root / file_path
        try:
            content = full_path.read_text()
        except Exception as e:
            print(f"Warning: Could not read {file_path}: {e}", file=sys.stderr)
            content = ""

        # 1. Domain category (max 40)
        domain_category, domain_score = self.detect_domain_category(file_path, content)

        # 2. Risk indicators (max 30)
        risk_score = 0
        risk_details = {}

        # In test-fixer memory (+15)
        in_memory = self.file_in_memory(file_path)
        if in_memory:
            risk_score += 15
            risk_details['in_memory'] = True

        # Recent bug fixes (+10)
        bug_counts = self.get_git_log_recent_bugs()
        recent_bugs = bug_counts.get(file_path, 0)
        if recent_bugs > 0:
            risk_score += min(10, recent_bugs * 5)  # 5 points per bug, max 10
            risk_details['recent_bugs'] = recent_bugs

        # High complexity (+5)
        complexity_score = self.calculate_complexity_score(content)
        if complexity_score > 0:
            risk_score += complexity_score
            risk_details['complexity'] = 'high' if complexity_score >= 4 else 'medium'

        # External dependencies (+5)
        has_external = self.has_external_dependencies(content)
        if has_external:
            risk_score += 5
            risk_details['external_deps'] = True

        risk_score = min(risk_score, 30)

        # 3. Impact radius (max 20)
        impact_score = 0
        impact_details = {}

        # High fan-in (+10)
        fan_in = self.calculate_fan_in(file_path)
        if fan_in >= 10:
            impact_score += 10
            impact_details['fan_in'] = fan_in
        elif fan_in >= 5:
            impact_score += 5
            impact_details['fan_in'] = fan_in

        # Entry point (+10)
        is_entry = self.is_entry_point(file_path, content)
        if is_entry:
            impact_score += 10
            impact_details['entry_point'] = True

        impact_score = min(impact_score, 20)

        # 4. Test gap (max 10)
        test_gap_score = 0
        test_gap_details = {}

        has_tests = self.has_tests(file_path)
        coverage = self.get_test_coverage(file_path)

        if not has_tests:
            test_gap_score = 10
            test_gap_details['has_tests'] = False
        elif coverage < 50:
            test_gap_score = 5
            test_gap_details['coverage'] = coverage
        else:
            test_gap_details['coverage'] = coverage

        # Check if tests are flaky (in memory)
        if in_memory and has_tests:
            test_gap_score = max(test_gap_score, 8)
            test_gap_details['flaky'] = True

        # Total score
        total_score = domain_score + risk_score + impact_score + test_gap_score

        # Determine priority
        priority = 'LOW'
        for threshold, label in sorted(self.PRIORITY_THRESHOLDS.items(), reverse=True):
            if total_score >= threshold:
                priority = label
                break

        # Build reason string
        reason_parts = []
        reason_parts.append(f"{domain_category.replace('_', ' ').title()} ({domain_score})")

        if in_memory:
            reason_parts.append("in test-fixer memory (15)")
        if recent_bugs:
            reason_parts.append(f"recent bug fixes (10)")
        if complexity_score >= 4:
            reason_parts.append(f"high complexity ({complexity_score})")
        if has_external:
            reason_parts.append("external dependencies (5)")
        if is_entry:
            reason_parts.append("entry point (10)")
        if fan_in >= 10:
            reason_parts.append(f"high fan-in ({fan_in} imports, 10)")
        elif fan_in >= 5:
            reason_parts.append(f"moderate fan-in ({fan_in} imports, 5)")
        if not has_tests:
            reason_parts.append("no tests (10)")
        elif coverage < 50:
            reason_parts.append(f"low coverage ({coverage}%, 5)")
        if test_gap_details.get('flaky'):
            reason_parts.append("flaky tests (8)")

        reason = " + ".join(reason_parts)

        # Determine test type
        test_type = 'unit'
        if has_external or 'supabase' in content.lower():
            test_type = 'integration'
        if 'page.' in content or 'browser' in content.lower():
            test_type = 'e2e'

        return CriticalityScore(
            file=file_path,
            score=total_score,
            breakdown={
                'domain_category': domain_score,
                'risk_indicators': risk_score,
                'impact_radius': impact_score,
                'test_gap': test_gap_score,
            },
            details={
                'category': domain_category,
                **risk_details,
                **impact_details,
                **test_gap_details,
            },
            reason=reason,
            test_type=test_type,
            priority=priority,
        )

    def find_typescript_files(self) -> List[str]:
        """Find all TypeScript files (excluding tests)"""
        ts_files = []

        # Search in lib/ and app/ directories
        for pattern in ['lib/**/*.ts', 'app/**/*.ts', 'app/**/*.tsx']:
            for file in self.project_root.glob(pattern):
                rel_path = file.relative_to(self.project_root)
                rel_path_str = str(rel_path)

                # Exclude test files and node_modules
                if (not rel_path_str.endswith('.test.ts') and
                    not rel_path_str.endswith('.spec.ts') and
                    'node_modules' not in rel_path_str):
                    ts_files.append(rel_path_str)

        return sorted(ts_files)

    def score_all_files(self) -> Dict[str, CriticalityScore]:
        """Calculate scores for all TypeScript files"""
        files = self.find_typescript_files()
        scores = {}

        print(f"Analyzing {len(files)} TypeScript files...", file=sys.stderr)

        for i, file_path in enumerate(files, 1):
            if i % 10 == 0:
                print(f"  Progress: {i}/{len(files)}", file=sys.stderr)

            score = self.calculate_score(file_path)
            scores[file_path] = score

        return scores


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description='Calculate criticality scores for TypeScript files'
    )
    parser.add_argument(
        '--project-root',
        default='.',
        help='Project root directory (default: current directory)'
    )
    parser.add_argument(
        '--output',
        help='Output JSON file path (default: .claude/cache/criticality-scores-<timestamp>.json)'
    )
    parser.add_argument(
        '--min-score',
        type=int,
        default=0,
        help='Minimum score to include in output (default: 0)'
    )
    args = parser.parse_args()

    # Initialize scorer
    scorer = CriticalityScorer(args.project_root)

    # Calculate scores
    scores = scorer.score_all_files()

    # Filter by minimum score
    if args.min_score > 0:
        scores = {k: v for k, v in scores.items() if v.score >= args.min_score}

    # Convert to JSON-serializable format
    output = {
        file_path: asdict(score)
        for file_path, score in sorted(scores.items(), key=lambda x: x[1].score, reverse=True)
    }

    # Determine output path
    if args.output:
        output_path = Path(args.output)
    else:
        from datetime import datetime
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        cache_dir = Path(args.project_root) / '.claude' / 'cache'
        cache_dir.mkdir(parents=True, exist_ok=True)
        output_path = cache_dir / f'criticality-scores-{timestamp}.json'

    # Write output
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)

    print(f"\nCriticality scores written to: {output_path}", file=sys.stderr)
    print(f"Total files analyzed: {len(output)}", file=sys.stderr)
    print(f"CRITICAL (80-100): {sum(1 for s in scores.values() if s.priority == 'CRITICAL')}", file=sys.stderr)
    print(f"HIGH (60-79): {sum(1 for s in scores.values() if s.priority == 'HIGH')}", file=sys.stderr)
    print(f"MEDIUM (40-59): {sum(1 for s in scores.values() if s.priority == 'MEDIUM')}", file=sys.stderr)
    print(f"LOW (<40): {sum(1 for s in scores.values() if s.priority == 'LOW')}", file=sys.stderr)


if __name__ == '__main__':
    main()
