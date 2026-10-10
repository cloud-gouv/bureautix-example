# SPDX-FileCopyrightText: 2026 Sébastien Celles <s.celles@gmail.com>
#
# SPDX-License-Identifier: MIT

# Hardening not yet provided by the pinned Sécurix revision
# (cloud-gouv/securix#294, cloud-gouv/securix#299).
{ lib, ... }:
{
  # Boot entries cannot be edited from the boot menu, and a bounded number of
  # generations stays installed (rollback remains possible).
  boot.lanzaboote = {
    settings.editor = false;
    configurationLimit = lib.mkDefault 10;
  };
}
