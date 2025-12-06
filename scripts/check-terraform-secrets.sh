#!/bin/bash
if git diff --cached --name-only | grep "\.tf$" | xargs grep -HnE "(password|secret|api_key)\s*=\s*\"[^\$]" 2>/dev/null; then
    echo "ERROR: Hardcoded secrets in Terraform!"
    exit 1
fi
exit 0
