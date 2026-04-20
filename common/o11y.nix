# SPDX-FileCopyrightText: 2026 Mihai Saveanu <darkangel@ladomotique.eu>
#
# SPDX-License-Identifier: MIT

# Observability configuration for Bureautix fleet.
# Enables log shipping and metrics collection using Securix o11y modules.
# Requires a central log/metrics server to receive data.
{
  lib,
  config,
  ...
}:
let
  cfg = config.bureautix.o11y;
  inherit (lib)
    mkEnableOption
    mkOption
    types
    mkIf
    ;
in
{
  options.bureautix.o11y = {
    enable = mkEnableOption "fleet observability (logs and metrics shipping)";

    logsUrl = mkOption {
      type = types.str;
      description = "URL du serveur central de collecte des journaux (journal-upload)";
      example = "https://logs.example.com";
    };

    metricsUrl = mkOption {
      type = types.str;
      description = "URL du serveur central de collecte des métriques (VictoriaMetrics/Prometheus)";
      example = "https://metrics.example.com/api/v1/write";
    };
  };

  config = mkIf cfg.enable {
    securix.o11y.logs = {
      enable = true;
      serverUrl = cfg.logsUrl;
    };

    securix.o11y.metrics = {
      enable = true;
      serverUrl = cfg.metricsUrl;
    };
  };
}
