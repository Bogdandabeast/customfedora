# Setup libvirt + kvm user groups and start libvirtd
vm-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "→ Adding $(whoami) to libvirt and kvm groups…"
    sudo usermod -aG libvirt "$(whoami)"
    sudo usermod -aG kvm "$(whoami)"

    echo "→ Enabling and starting libvirtd.service…"
    sudo systemctl enable --now libvirtd.service

    echo "Done. Reboot once (or run 'newgrp libvirt && newgrp kvm') so the"
    echo "     group changes take effect, then open virt-manager."
