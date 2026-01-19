{ flake-parts-lib, lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib)
    mkOption
    types
    literalExpression
    mkDefault
    mkIf
    ;
  fileOption =
    pkgs:
    {
      name,
      config,
      ...
    }:
    {
      options = {
        target = mkOption {
          type = types.str;
          defaultText = literalExpression "name";
          description = "Path to the target file relative to base path";
        };
        source = mkOption {
          type = types.path;
          description = "Path of the source file or directory.";
        };
        text = mkOption {
          type = types.nullOr types.lines;
          default = null;
          description = "Text of the file.";
        };
        executable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the file should be executable.";
        };
      };
      config = {
        target = mkDefault name;
        source = mkIf (config.text != null) (
          pkgs.writeTextFile {
            name = name;
            inherit (config) text executable;
          }
        );
      };
    };
in
{
  options.perSystem = mkPerSystemOption (
    { config, pkgs, ... }:
    {
      options.files = {
        files = mkOption {
          type = types.attrsOf (types.submodule (fileOption pkgs));
          default = { };
          description = "Files to link into the repository";
        };
        shellHook = mkOption {
          type = types.lines;
          internal = true;
          readOnly = true;
        };
      };
      config.files.shellHook = lib.optionalString (config.files.files != { }) ''
        link_file() {
            local target="$1"
            local source="$2"
            local current_source
            current_source=$(readlink "$target")
            if [[ $? -eq 0 && "$current_source" == "$source" ]]; then
                return
            fi
            mkdir -p "$(dirname "$target")"
            ln -sf "$source" "$target"
            echo -e "\e[32mlink $target updated\e[0m"
        }
        ${lib.concatMapStrings (
          f:
          "link_file ${
            lib.escapeShellArgs [
              f.target
              f.source
            ]
          }\n"
        ) (lib.attrValues config.files.files)}
        unset -f link_file
      '';

    }
  );
}
