{ pkgs, ... }:
{
  home.packages = with pkgs; [
    niks3
  ];

  home.sessionVariables = {
    NIKS3_SERVER_URL = "https://niks3.szp.io";
  };
}
