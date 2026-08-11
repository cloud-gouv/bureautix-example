# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ nix-actions, ... }:

{
  name = "Run pre-commit on all files";
  on = [
    "push"
    "pull_request"
  ];

  jobs.pre-commit = {
    runs-on = "ubuntu-latest";
    steps = [
      { uses = "actions/checkout@08eba0b27e820071cde6df949e0beb9ba4906955"; }
      {
        name = "Install Lix";
        uses = "samueldr/lix-gha-installer-action@8c7f8a4b0f594ab8a6dc3bf71c217587bbc756b5";
      }
    ]
    # Inspired by DGNum's way of checking for pre-commit hooks.
    ++ (map
      (stage: {
        name = "Check stage ${stage}";
        run = ''
          	  set -o pipefail
          	  set -o nounset
          	  set -o errexit
          	  nix-shell --run 'pre-commit run --all-files --hook-stage ${stage} --show-diff-on-failure'
          	'';
      })
      [
        "pre-commit"
        "pre-push"
      ]
    );
  };
}
