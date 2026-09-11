# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{
  securix.pam.u2f = {
    enable = true;

    appId = "pam://bureautix-exemple";
    origin = "pam://bureautix-exemple";
  };

  # Accounts authenticate with their FIDO2 key, none of them has a password.
  users.allowNoPasswordLogin = true;
}
