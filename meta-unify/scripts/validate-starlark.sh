#!/bin/bash
# Validate Starlark syntax (Codex rules)
# Usage: validate-starlark.sh <file>
# Exit codes: 0 = valid, 1 = invalid
#
# Note: Starlark is a Python dialect, so we use Python's AST parser
# for basic syntax validation. This catches most syntax errors but
# won't validate Starlark-specific semantics.

set -e

if [ -z "$1" ]; then
    echo "Usage: validate-starlark.sh <file>" >&2
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
fi

# Use Python AST for syntax validation
python3 -c "
import ast
import sys
import re

try:
    with open('$FILE', 'r') as f:
        content = f.read()

    # Parse as Python (Starlark is a Python subset)
    ast.parse(content)

    # Additional Starlark-specific checks
    errors = []
    warnings = []

    lines = content.split('\n')
    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith('#'):
            continue

        # Check for valid prefix_rule() calls
        if 'prefix_rule' in stripped:
            # Verify it has required 'pattern' field
            if 'pattern' not in stripped and 'pattern' not in ''.join(lines[i-1:i+5]):
                warnings.append(f'Line {i}: prefix_rule() should have a pattern field')

            # Check decision values
            if 'decision' in stripped:
                valid_decisions = ['\"allow\"', '\"prompt\"', '\"forbidden\"', \"'allow'\", \"'prompt'\", \"'forbidden'\"]
                has_valid = any(d in stripped for d in valid_decisions)
                if not has_valid and 'decision' in stripped:
                    # Check next few lines too
                    context = ''.join(lines[max(0,i-1):min(len(lines),i+3)])
                    has_valid = any(d in context for d in valid_decisions)
                    if not has_valid:
                        warnings.append(f'Line {i}: decision should be \"allow\", \"prompt\", or \"forbidden\"')

        # Check for import statements (not allowed in Starlark rules)
        if stripped.startswith('import ') or stripped.startswith('from '):
            errors.append(f'Line {i}: import statements not allowed in Starlark rules')

    if errors:
        print(f'Invalid Starlark in $FILE:', file=sys.stderr)
        for err in errors:
            print(f'  {err}', file=sys.stderr)
        sys.exit(1)

    if warnings:
        print(f'Starlark warnings in $FILE:')
        for warn in warnings:
            print(f'  {warn}')

    print('Valid Starlark: $FILE')
    sys.exit(0)

except SyntaxError as e:
    print(f'Invalid Starlark in $FILE:', file=sys.stderr)
    print(f'  Line {e.lineno}: {e.msg}', file=sys.stderr)
    if e.text:
        print(f'    {e.text.strip()}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error validating $FILE: {e}', file=sys.stderr)
    sys.exit(1)
"
