# Justfiles — ujust scripts

These scripts are installed as `ujust` commands in the built image.

## vm-setup — libvirt / virt-manager first-boot setup

```bash
ujust vm-setup
```

Adds the current user to the `libvirt` and `kvm` groups, enables and starts
`libvirtd.service`, and prints a reboot reminder. Requires sudo.
