{ config, pkgs, ... }:
{
  systemd.services.proxy-subscriptions = {
    enableStrictShellChecks = true;
    script = ''
      umask 0027
      output_dir=/var/lib/proxy-subscriptions
      mkdir -p "$output_dir"/{subscription/v2,subscription/clash}
      settings=$(<"$CREDENTIALS_DIRECTORY/settings.yaml")
      namespace=$(yq -re '.namespace' <<<"$settings")
      readarray -d "" -t emails < <(yq -0e '.users[] | .email' <<<"$settings")
      for email in "''${emails[@]}"; do
        uuid=$(python -m uuid -u uuid5 -n "$namespace" -N "$email")
        uuid="$uuid" yq -r '.servers[] |
          "vless://\(strenv(uuid))@\(.add):443?security=reality&encryption=none&" +
          "pbk=\(.pbk)&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision" +
          "&sni=\(.add)&sid=\(.sid)#\(.ps | @uri)"
        ' <<<"$settings" | base64 -w 0 > "$output_dir/subscription/v2/$uuid"
        uuid="$uuid" yq -P '{"proxies": [.servers[] | {
          "name": .ps,
          "type": "vless",
          "server": .add,
          "port": 443,
          "uuid": strenv(uuid),
          "network": "tcp",
          "tls": true,
          "udp": true,
          "flow": "xtls-rprx-vision",
          "servername": .add,
          "reality-opts": {
            "public-key": .pbk,
            "short-id": .sid
          },
          "client-fingerprint": "chrome"
        }]}' <<<"$settings" > "$output_dir/subscription/clash/$uuid"
      done
    '';
    path = with pkgs; [
      yq-go
      python3
    ];
    postStop = ''
      rm -rf /var/lib/proxy-subscriptions/*
    '';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Group = "nginx";
      LoadCredential = "settings.yaml:${config.sops.secrets."proxy/settings.yaml".path}";
      StateDirectory = "proxy-subscriptions";
    };
  };

  # settings.yaml schema
  #
  #   namespace: 8be4df61-93ca-11d2-aa0d-00e098032b8c
  #   users:
  #   - email: alice@example.com
  #   servers:
  #   - add: example.com
  #     pbk: AAAA
  #     sid: xxxx
  #     ps: HK Server
  #
  # We used to use uuid5 to generate the user id.
  # Though it's not a good idea, we need to keep backward compatibility.
  sops.secrets."proxy/settings.yaml" = { };
}
