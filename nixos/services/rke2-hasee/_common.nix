{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.rke2;
  inherit (pkgs.stdenv.hostPlatform) system;
  arch =
    {
      "x86_64-linux" = "amd64";
      "aarch64-linux" = "arm64";
    }
    .${system};
in
lib.mkMerge [
  {
    services.rke2 = {
      enable = true;
      package = pkgs.rke2;
      cisHardening = true;
      images = [
        cfg.package."images-core-linux-${arch}-tar-zst"
        cfg.package."images-cilium-linux-${arch}-tar-zst"
        cfg.package."images-multus-linux-${arch}-tar-zst"
      ];
      gracefulNodeShutdown.enable = true;
      extraFlags = [
        "--protect-kernel-defaults"
      ];
    };

    preservation.preserveAt.default.directories = [
      # rke2
      {
        directory = "/run/k3s";
        mode = "0711";
      }
      {
        directory = "/var/lib/kubelet";
        mode = "0700";
      }
      "/etc/rancher"
      "/var/lib/rancher"
      # CNI
      {
        directory = "/etc/cni";
        mode = "0700";
      }
      "/opt/cni"
      "/var/lib/cni"
      # Rook Ceph
      {
        directory = "/var/lib/rook";
        mode = "0700";
      }
      # Local Path Provisioner
      {
        directory = "/opt/local-path-provisioner";
        mode = "0700";
      }
    ];
  }

  (lib.mkIf (cfg.role == "server") {
    services.rke2 = {
      cni = "multus,cilium";
      extraFlags = [
        "--tls-san=10.112.8.100"
        "--tls-san=rke2-hasee.szp.io"
        "--cluster-cidr=10.112.0.0/21"
        "--service-cidr=10.112.9.0/24"
        "--cluster-dns=10.112.9.10"
        "--cluster-domain=hasee.internal"
        # "--egress-selector-mod=disabled"
        "--disable-cloud-controller"
        "--disable-kube-proxy"
        "--ingress-controller=none"
      ];
    };

    home-manager.users.root = {
      home.sessionPath = [
        "/var/lib/rancher/rke2/bin"
      ];
      home.sessionVariables = {
        KUBECONFIG = "/etc/rancher/rke2/rke2.yaml";
        CRI_CONFIG_FILE = "/var/lib/rancher/rke2/agent/etc/crictl.yaml";
        CONTAINERD_ADDRESS = "/run/k3s/containerd/containerd.sock";
        CONTAINERD_NAMESPACE = "k8s.io";
      };
      programs.bash = {
        enable = true;
        shellAliases = {
          etcdctl = ''
            crictl exec "$(crictl ps --label io.kubernetes.container.name=etcd --quiet)" etcdctl \
              --cert /var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
              --key /var/lib/rancher/rke2/server/tls/etcd/server-client.key \
              --cacert /var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
          '';
        };
      };
    };
  })
]
