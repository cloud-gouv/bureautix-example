<!--
SPDX-FileCopyrightText: 2026 Sébastien Celles <s.celles@gmail.com>

SPDX-License-Identifier: MIT
-->

# Installing Bureautix

This guide goes from a fork of this repository to a first boot. It was
written while installing the example machine `PC140V35` from an ISO in a
UEFI virtual machine (NVMe disk, TPM), and from reading the installer code.
Parts that need a FIDO2 security key are marked as such.

## What you need

- A machine with Nix to build the images (a few GB of free space, more for
  the full system closure).
- For each machine to install: UEFI firmware, an NVMe disk (the layout
  formats `/dev/nvme0n1` by default) and its serial number.
- FIDO2 security keys (for example YubiKeys): the default disk layout
  (`office_v1`) enrolls one to unlock the disk at boot, and PAM U2F uses
  them to log in.

## 1. Fork and describe your fleet

Fork this repository (keep it private: it describes your machines and
users). Everything below happens in your fork.

### Machines

Each machine has a file `inventory/machines/<SERIAL>.nix`, named after its
serial number:

```nix
{
  securix.self.mainDisk = "/dev/nvme0n1";
  securix.self.machine = {
    hardwareSKU = "x280";
    serialNumber = "PC140V35";
    users = [ "heloise" ];
  };
}
```

- The serial number is what the firmware reports: `cat
  /sys/class/dmi/id/product_serial` (or `dmidecode -s system-serial-number`)
  on the machine, for example from the installer.
- `hardwareSKU` selects one of Sécurix's hardware profiles (`hardware/` in
  Sécurix: `x280`, `x390`, `t14g6`, `p14sg6`, `elitebook850g8`, …). Add a
  profile to Sécurix if your model is missing.
- `users` lists the people who use this machine; each one needs a file in
  `inventory/users/`.

### Users

Each user has a file `inventory/users/<username>.nix`:

```nix
{ pkgs, ... }:
{
  securix.self.user = {
    email = "heloise@example.com";
    username = "heloise";
    # pamu2fcfg --appid pam://bureautix-exemple --origin pam://bureautix-exemple --nouser
    u2f_keys = [ "<output of pamu2fcfg>" ];
    defaultLoginShell = pkgs.zsh;
  };
}
```

Generate a key entry with `pamu2fcfg` (package `pam_u2f`) while the key is
plugged in. `--appid` and `--origin` must match `common/pam_u2f.nix`;
change both there to a value of your own (for example
`pam://acme-workstations`) before generating keys.

The example users have the password `test` (`hashedPassword`): remove those
lines in your fork (see #16).

### IT staff and remote access

- `common/admins.nix`: one `<name>-adm` account per administrator, with
  their `u2f_keys`. These accounts are in `wheel`.
- `common/superadmins.nix`: SSH access as root for the keys listed in
  `keys`. **It also sets root's password to `nixos`: replace or remove that
  line in your fork.** With `users.mutableUsers = false`, the configuration
  is the only source of passwords: a password changed on the machine is
  reset at the next activation.

Check that everything still evaluates:

```sh
nix-instantiate -A toplevelRegistry
```

## 2. Choose how to install

| Method | Installs | Use it for |
|---|---|---|
| USB stick (`usb-installer`) | the generic **default** system (no user account) | a single machine, or when there is no provisioning server |
| Netboot (`net-installer`, see `netboot/README.md`) | the system of **this machine**, selected by its serial number from `toplevelRegistry` | installing a fleet (with the Sécurix currently pinned, `net-installer` does not evaluate; a newer pin fixes it, see #19) |

The USB installer can only install the generic system: it falls back to it
because its list of systems contains nothing else. The machine then gets its
own configuration in step 4.

## 3. Install from a USB stick

```sh
nix-build -A usb-installer
# the image is in result/iso/
dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot the machine from the stick (UEFI). The console logs in as root and
tells you to run:

```sh
autoinstall-terminal
```

It then:

1. lists the disks and asks to confirm reformatting `/dev/nvme0n1`;
2. creates the ESP, a recovery partition and the encrypted partition
   (LUKS2), then:
   - **with a FIDO2 key** (default layout): enrolls the key; plug it in and
     touch it when it blinks;
   - enrolls a **recovery key**, shown with a QR code: store it safely before
     pressing Enter, as it is the only way in if the key is lost;
3. creates Secure Boot keys and installs the system, then tries to enroll
   the Secure Boot keys. On machines with option ROMs (discrete GPU, some
   NVMe or network cards, virtual machines) this enrollment can fail while
   the installation still reports success, see
   cloud-gouv/securix#287. Check after the first boot (step 5).

Remove the stick and reboot. The disk is unlocked with the FIDO2 key, or the
recovery key if needed.

## 4. Apply this machine's configuration

After a USB installation the machine runs the generic system. To switch it
to its own configuration, log in as an administrator (or root) and build the
terminal from your fork. This is the same command Sécurix's `upgrade` script
uses:

```sh
git clone <your fork> /etc/bureautix
nixos-rebuild switch --file /etc/bureautix --attr terminals.<SERIAL>.system
```

`/etc/bureautix` is the path `common/default.nix` sets as
`infraRepositoryPath`. To keep machines up to date from the fork, Sécurix
has opt-in modules (`securix.auto-updates`, `securix.manual-upgrades`).
Read their documentation before enabling them.

## 5. Check the installation

On the installed machine:

- `sbctl status`: `Secure Boot: Enabled` and `Setup Mode: Disabled`. If
  Secure Boot is disabled and setup mode enabled, the keys were not
  enrolled: `sbctl enroll-keys --microsoft` (or `--tpm-eventlog`), then
  reboot.
- `ss -tlnp`: only the services you expect listen on the network (SSH on
  port 22 when superadmins are enabled).
- `sshd -T | grep -E 'passwordauthentication|kbdinteractiveauthentication'`:
  both should be `no`. The Sécurix revision pinned here leaves them
  enabled (fixed in Sécurix by f7e8d3b); until the pin includes it, set
  `services.openssh.settings.PasswordAuthentication = false;` and
  `KbdInteractiveAuthentication = false;` in `common/`.

## Adding software later

Add packages or modules in `common/` (for every machine), in a machine file
or in a user file, commit to your fork, then rebuild as in step 4.
