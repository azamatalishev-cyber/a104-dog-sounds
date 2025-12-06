#!/bin/bash
set -e

echo "Running npm audit..."
if npm audit --audit-level=high; then
    echo "✓ No high or critical vulnerabilities found"
    exit 0
else
    echo "✗ High or critical vulnerabilities detected!"
    echo "Run 'npm audit fix' to fix them"
    exit 1
fi
