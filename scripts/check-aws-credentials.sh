#!/bin/bash
if git diff --cached --name-only -z | xargs -0 grep -HnE "(AKIA|ASIA)[0-9A-Z]{16}" 2>/dev/null; then
    echo "ERROR: AWS credentials detected!"
    exit 1
fi
exit 0
