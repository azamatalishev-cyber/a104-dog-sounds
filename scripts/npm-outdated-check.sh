#!/bin/bash
echo "Checking for outdated packages..."
npm outdated --long || true
exit 0
