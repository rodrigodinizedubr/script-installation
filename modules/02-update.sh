#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/lib/common.sh"

info "Atualizando índice de pacotes e sistema"
apt update
apt upgrade -y
