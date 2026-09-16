# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

# Test-only NixOS module to run Bureautix inside a QEMU VM.
#
# Why this module exists:
# - Physical Bureautix machines assume a real disk (e.g. /dev/nvme0n1),
#   LUKS + FIDO2 enrollment, Secure Boot via Lanzaboote and a Yubikey
#   for PAM U2F. None of this exists inside a throwaway QEMU VM.
# - `virtualisation.vmVariant` is only merged into
#   `config.system.build.vm`, so every override below applies to the VM
#   run (`nix-build -A vm`) and never to your real installed systems.
{ lib, pkgs, ... }:
{
  # Identity of the VM used as a test.
  # This reuses the `alice` test account (password is `test`, see
  # `inventory/users/alice.nix`).
  # NOTE: `mainDisk` is still required at eval time because the
  # `office_v1`/`securix_v1` filesystem modules read it eagerly, even
  # when disabled via `securix.filesystems.enable = false` in vmVariant.
  securix.self.mainDisk = "/dev/vda";
  securix.self.machine = {
    hardwareSKU = "x280";
    serialNumber = "VM-TEST-01";
  };

  imports = [
    # Keep the example small and self-contained: reuse the standard office
    # configuration but the test user is defined inline so `nix-build -A vm`
    # works without touching the real inventory.
    ../common
  ];

  securix.self.user = {
    email = "alice@example.com";
    username = "alice";
    # password is `test`
    hashedPassword = "$y$j9T$zk4xGLyshz7RzqnMX6M8O0$AybRelILMkQSWcQZV4s.ykRNi/UlgaCUaDwdee0n7N2";
    defaultLoginShell = pkgs.zsh;
  };

  # Everything below only affects `system.build.vm`, not the real toplevel.
  virtualisation.vmVariant = {
    # Disable everything that requires physical hardware.
    # - disko / LUKS / FIDO2: the VM uses a throwaway qcow2 managed by qemu-vm.nix.
    # - Lanzaboote / Secure Boot: OVMF in `build.vm` is not enrolled, use systemd-boot.
    # - PAM U2F: no Yubikey is passed through by default, keep password login.
    securix.filesystems.enable = lib.mkForce false;
    disko.enableConfig = lib.mkForce false;
    boot.lanzaboote.enable = lib.mkForce false;
    # NOTE: securix forces systemd-boot off with `mkForce`, so inside
    # `vmVariant` we need an even stronger priority (`mkOverride 10`)
    # to re-enable it for the VM.
    boot.loader.systemd-boot.enable = lib.mkOverride 10 true;
    boot.loader.efi.canTouchEfiVariables = lib.mkOverride 10 false;
    securix.pam.u2f.enable = lib.mkForce false;
    # `securix.admins` asserts that PAM U2F is enabled (admin accounts are
    # passwordless by design). There is no Yubikey in the test VM, so
    # disable the IT admin accounts here; `alice` (password `test`) and
    # `root` (password `nixos`) stay available.
    securix.admins.enable = lib.mkForce false;

    # Do not fail the VM on missing smartcard hardware.
    services.pcscd.enable = lib.mkForce false;
    services.yubikey-agent.enable = lib.mkForce false;

    # Convenient test-only settings.
    users.users.alice.extraGroups = [ "wheel" ];
    security.sudo.wheelNeedsPassword = false;

    # Autologin on the graphical session so `run-*-vm` lands directly
    # on the KDE desktop. Console login still works with `alice` / `test`
    # and `root` / `nixos`.
    services.displayManager.autoLogin.enable = true;
    services.displayManager.autoLogin.user = "alice";

    # Guest integration + resources.
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;

    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 20480;
      graphics = true;
      qemu.options = [
        # Example: pass a physical Yubikey to the VM to test PAM U2F / FIDO2.
        # Find vendor/product with `lsusb`, then uncomment:
        # "-usb"
        # "-device"
        # "usb-host,vendorid=0x1050,productid=0x0407"
      ];
    };
  };
}
