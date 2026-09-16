<!--
SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>

SPDX-License-Identifier: MIT
-->

# VM test example

This directory contains a minimal example to test Bureautix inside a throwaway QEMU VM.

It reuses `./common` (office tools, KDE, PAM U2F config, …) but disables
everything that requires physical hardware **only inside `system.build.vm`**:

- `disko` / LUKS / FIDO2 (`securix.filesystems.enable = false`)
- Secure Boot via Lanzaboote (replaced by `systemd-boot`)
- PAM U2F (password login stays available)
- `pcscd` / TPM / Yubikey agent

## Run it

```sh
nix-build -A vm
./result/bin/run-bureautix-vm-test-vm
```

Logins:

- `alice` / `test` (autologged on the KDE session)
- `root` / `nixos` (see `common/superadmins.nix`)

## Passing a Yubikey

Find your key with `lsusb`, then uncomment the `usb-host` lines in `vm.nix`:

```nix
"-usb"
"-device"
"usb-host,vendorid=0x1050,productid=0x0407"
```

## Files

- `vm.nix`: the NixOS module used for the VM. Import it through `mkTerminal`
  (see `vmTerminal` in the top-level `default.nix`), all VM-only overrides
  live under `virtualisation.vmVariant`.
