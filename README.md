<!--
SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>

SPDX-License-Identifier: MIT
-->

# Bureautix, an example

Bureautix is a derivative of [Sécurix](https://github.com/cloud-gouv/securix/) used as a general example.

This example shows how to use Sécurix to set up office workstations, perform IT operations, etc.

The Bureautix model is a named NixOS system with IT administrator accounts. The boot and authentication chain is essentially secured by security keys (LUKS FIDO2 + PAM U2F).

Like Sécurix, Bureautix retains [the Secure Boot properties of Sécurix](https://git.afnix.fr/lanzaboote/lanzaboote) and inherits the security properties of Sécurix.

This example contains a kit for building your own office PC called "Bureautix" with an inventory, an installer, and office customizations. You can take it and add your own organizational customizations by cloning it and then making a private version.


See [INSTALL.md](INSTALL.md) to install Bureautix on your machines.

## FAQ

### Why is there no centralized authentication via LDAP?

The Sécurix family of systems aims to do as much as possible with as little
infrastructure as possible, which is why there is no centralized LDAP directory,
FreeIPA, or similar.

These systems allow an organization to start with the least amount of
dependency, and as soon as the organization needs complexity, it can
decide to introduce a centralized directory.

By avoiding centralized directories, we avoid problems with accounts that
do not appear on a user system, problems connecting to a
network accessing the directory from the login screen, and other
integration difficulties.

On the other hand, Bureautix relies on a static directory managed “as code” in your
repo. New users are distributed via “the Git protocol”
or by downloading a new update using the method of your choice.

## Known issues

### I don't know when to press the Yubikey!

In fact, as soon as the Yubikey is configured to request the presence of the
user, i.e. without a PIN code, most mechanisms will not display
or will be unable to display a message explaining that the Yubikey must be
touched.

There are ideas for solving this problem in the short term.
