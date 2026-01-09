#!/bin/bash
# Validate JSON syntax
# Usage: validate-json.sh <file>
# Exit codes: 0 = valid, 1 = invalid

set -e

if [ -z "$1" ]; then
    echo "Usage: validate-json.sh <file>" >&2
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
fi

# Use Python for JSON validation (widely available)
python3 -c "
import json
import sys

try:
    with open('$FILE', 'r') as f:
        json.load(f)
    print('Valid JSON: $FILE')
    sys.exit(0)
except json.JSONDecodeError as e:
    print(f'Invalid JSON in $FILE:', file=sys.stderr)
    print(f'  Line {e.lineno}, Column {e.colno}: {e.msg}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'Error reading $FILE: {e}', file=sys.stderr)
    sys.exit(1)
"
