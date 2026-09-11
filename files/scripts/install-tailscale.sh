#!/usr/bin/env bash
set -euo pipefail
# BlueBuild script: instala Tailscale via script oficial
# https://tailscale.com/install.sh
# Se ejecuta dentro del build del container como root.
echo "==> install-tailscale.sh: instalando Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
echo "==> Tailscale instalado"
tailscale version 2>&1 | head -n 5 || true
systemctl is-enabled tailscaled 2>&1 | head -n 5 || true
