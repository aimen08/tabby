#!/bin/bash
# Rebuilds and relaunches dist/Tabby.app for local testing.
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-app.sh
pkill -x Tabby 2>/dev/null && sleep 0.5 || true
open dist/Tabby.app
