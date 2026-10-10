<!--
SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>

SPDX-License-Identifier: MIT
-->

# Bureautix, un exemple

Bureautix est une souche dérivée de Sécurix en tant qu'exemple général.

Cet exemple montre comment utiliser Sécurix afin de faire des postes de bureautiques, les opérations de DSI autour etc.

Le modèle du Bureautix est un système NixOS nominatif avec des comptes administrateurs DSI. La chaine de démarrage et d'authentification est essentiellement assurée par des clefs de sécurité (LUKS FIDO2 + PAM U2F).

Comme Sécurix, Bureautix conserve les propriétés de Secure Boot de Sécurix et hérite des propriétés de sécurité de Sécurix.

Cet exemple contient un kit pour fabriquer votre PC de bureautique dit "Bureautix" avec un inventaire, un installeur et des customisations de bureautique. Vous pouvez le prendre et rajouter vos customisations organisationnels en le clonant puis en faisant une version privée.


Voir [INSTALL.md](INSTALL.md) (en anglais) pour installer Bureautix sur vos machines.

## FAQ

### Pourquoi il n'y a pas d'authentification centralisée via LDAP?

La famille des systèmes Sécurix cherche à faire beaucoup avec le moins
d'infrastructure possible, c'est pour cela qu'on y trouve pas d'annuaire
centralisée LDAP ou de FreeIPA ou similaire.

Ces systèmes permettent de démarrer une organisation avec le moins de
dépendance et aussitot que l'organisation a besoin de complexité, elle peut
décider d'introduire un annuaire centralisée.

En évitant les annuaires centralisées, on évite les problèmes de comptes qui
n'apparaissent pas sur un système utilisateur, les problèmes de connexions à un
réseau accédant à l'annuaire depuis l'écran de connexion et d'autres
difficultés d'intégration.

En revanche, Bureautix repose sur un annuaire statique géré "as code" dans votre
repo. La distribution de nouveaux utilisateurs se fait via "le protocole Git"
ou en téléchargeant une nouvelle mise à jour par le moyen de votre choix.

## Problèmes connus

### Je ne sais pas quand il faut appuyer sur la Yubikey!

En effet, dès que la Yubikey n'est configuée pour demander que la présence de
l'utilisateur, i.e. sans code PIN, la plupart des mécanismes n'afficheront pas
ou ne pourront pas afficher un message permettant d'expliquer qu'il faut
toucher la Yubikey.

Il y a des idées pour résoudre ce problème sur le court terme.
