{ pkgs, config, ... }:
let
  keyValueFormat = pkgs.formats.keyValue { };
in
{
  xdg.configFile."go/env".source = keyValueFormat.generate "go-env" {
    "GOPATH" = "${config.xdg.dataHome}/go";
  };
}
