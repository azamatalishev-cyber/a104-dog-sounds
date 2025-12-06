#!/bin/bash
if git diff --cached --name-only | grep -E "\.env$|\.env\..*$"; then
    echo "ERROR: Attempting to commit .env file!"
    exit 1
fi
exit 0
