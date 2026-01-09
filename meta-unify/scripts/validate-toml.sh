#!/bin/bash
# Validate TOML syntax
# Usage: validate-toml.sh <file>
# Exit codes: 0 = valid, 1 = invalid

set -e

if [ -z "$1" ]; then
    echo "Usage: validate-toml.sh <file>" >&2
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
fi

# Use Python with tomllib (Python 3.11+) or tomli fallback
python3 -c "
import sys

try:
    # Try Python 3.11+ built-in tomllib
    import tomllib
    with open('$FILE', 'rb') as f:
        tomllib.load(f)
    print('Valid TOML: $FILE')
    sys.exit(0)
except ImportError:
    # Fall back to tomli package
    try:
        import tomli
        with open('$FILE', 'rb') as f:
            tomli.load(f)
        print('Valid TOML: $FILE')
        sys.exit(0)
    except ImportError:
        # No TOML parser available, try basic validation
        print('Warning: No TOML parser available (install tomli: pip install tomli)', file=sys.stderr)
        print('Performing basic syntax check...', file=sys.stderr)

        with open('$FILE', 'r') as f:
            content = f.read()

        # Basic checks
        errors = []
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            # Check for common TOML errors
            if '=' in line and not line.startswith('['):
                key_part = line.split('=')[0].strip()
                if ' ' in key_part and not key_part.startswith('\"'):
                    errors.append(f'Line {i}: Key with spaces should be quoted')

        if errors:
            print('Potential TOML issues:', file=sys.stderr)
            for err in errors:
                print(f'  {err}', file=sys.stderr)
            sys.exit(1)
        else:
            print('Basic TOML check passed: $FILE')
            sys.exit(0)
except Exception as e:
    # Extract line number if available
    error_str = str(e)
    print(f'Invalid TOML in $FILE:', file=sys.stderr)
    print(f'  {error_str}', file=sys.stderr)
    sys.exit(1)
"
