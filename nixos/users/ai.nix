{ pkgs, ... }:
let
  git-credential-vault = pkgs.writeShellApplication {
    name = "git-credential-vault";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      openbao
    ];
    text = ''
      action="''${1:-}"
      shift || true

      function get_token() {
          local expires_at token token_path resp tmp_file
          if [[ -f ~/.config/gh-vault/credentials.json ]]; then
              expires_at=$(jq -er '.expires_at' ~/.config/gh-vault/credentials.json)
              if [[ "$expires_at" -gt "$(date +%s)" ]]; then
                  jq -r '.token' ~/.config/gh-vault/credentials.json
                  return
              fi
          fi
          token_path=''${GHVAULT_TOKEN_PATH:-}
          if [[ -z "$token_path" ]]; then
              echo "GHVAULT_TOKEN_PATH is not set" >&2
              return 1
          fi
          mkdir -p ~/.config/gh-vault
          resp=$(bao read -format=json "$token_path")
          expires_at=$(date -d "$(jq -er '.data.expires_at' <<<"$resp")" +%s)
          token=$(jq -er '.data.token' <<<"$resp")
          tmp_file=$(mktemp ghvault.XXXXXXXXXX)
          trap 'rm -f "$tmp_file"' EXIT
          jq -n --arg t "$token" --arg e "$expires_at" '{token: $t, expires_at: $e}' >"$tmp_file"
          mv "$tmp_file" ~/.config/gh-vault/credentials.json
          echo "$token"
      }

      case "$action" in
      store|erase)
          echo "store or erase"
          exit 0
          ;;

      exec)
          GH_TOKEN=$(get_token)
          export GH_TOKEN
          exec "$@"
          ;;

      *)
          token=$(get_token)
          echo "username=x-access-token"
          echo "password=$token"
          ;;
      esac
    '';
  };
in
{
  users.users.nixos = {
    isNormalUser = true;
    linger = true;
    extraGroups = [
      "wheel"
      "openbao-proxy"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAamaMcCAc7DhTJjDqBwXTWhewX0OI8vAuXLvc17yqK/ cardno:19_795_283"
    ];
  };

  home-manager.users.nixos = {
    home.packages = with pkgs; [
      openbao
      gh
      git-credential-vault
    ];
    home.sessionVariables = {
      BAO_ADDR = "unix:///run/openbao-proxy/openbao-proxy.sock";
      GHVAULT_TOKEN_PATH = "/github/token/ai";
    };
    home.shellAliases = {
      gh = "git-credential-vault exec gh";
    };
    home.stateVersion = "25.11";
    programs.bash.enable = true;
    programs.git = {
      enable = true;
      settings = {
        user.name = "claude[bot]";
        user.email = "claude@szp.io";
        credential."https://github.com".helper = "vault";
      };
    };
    programs.claude-code.enable = true;
    programs.zellij.enable = true;

  };

  preservation.preserveAt.default.directories = [
    {
      directory = "/home/nixos";
      mode = "0700";
      user = "nixos";
      group = "users";
    }
  ];
}
