# A treefmt formatter for GitHub workflow files: every key sorted, `jobs`
# kept last, and the unicode escapes yq writes turned back into characters.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.devkit.githubWorkflows;
  unescape = lib.escapeShellArg "s/\\\\U([0-9a-fA-F]{8})/chr(hex \$1)/ge; s/\\\\u([0-9a-fA-F]{4})/chr(hex \$1)/ge";
  unescapeCommand = lib.optionalString cfg.unescapeUnicode "| ${pkgs.perl}/bin/perl -CS -pe ${unescape}";
  format = pkgs.writeShellScriptBin "github-workflows" ''
    set -euo pipefail
    for f in "$@"; do
      tmp=$(mktemp)
      ${pkgs.yq-go}/bin/yq -r ${lib.escapeShellArg cfg.expression} "$f" ${unescapeCommand} > "$tmp"
      if cmp -s "$tmp" "$f"; then rm "$tmp"; else mv "$tmp" "$f"; fi
    done
  '';
in {
  options.devkit.githubWorkflows = {
    enable = lib.mkEnableOption "the GitHub workflow formatter";

    includes = lib.mkOption {
      type = with lib.types; listOf str;
      default = [".github/workflows/*.yaml" ".github/workflows/*.yml"];
      description = "The files it formats.";
    };

    expression = lib.mkOption {
      type = lib.types.str;
      default = "sort_keys(..) | . as $orig | del(.jobs) | .jobs = $orig.jobs";
      description = "The yq expression each file is rewritten with.";
    };

    unescapeUnicode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Turn the `\uXXXX` and `\UXXXXXXXX` escapes yq writes for non-ASCII
        characters back into the characters.
      '';
    };

    priority = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = ''
        treefmt runs formatters that match one file in ascending priority.
        It runs last by default, so its output is the file's final form even
        when a general YAML formatter matches the same file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    settings.formatter.github-workflows = {
      command = format;
      inherit (cfg) includes priority;
    };
  };
}
