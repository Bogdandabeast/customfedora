# Justfiles — ujust scripts

These scripts are installed as `ujust` commands in the built image.

Only files ending in `.just` are treated as justfiles by the BlueBuild module.

## vm-setup — libvirt/kvm first-boot setup

```bash
ujust vm-setup
```

Adds the current user to the `libvirt` and `kvm` groups, enables and starts
`libvirtd.service`, and prints a reboot reminder. Requires sudo.

This file is documentation only; it is not a `.just` file and is not imported
by the justfiles module.
