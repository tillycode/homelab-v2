---
title: RKE2 Hasee Cluster Management
---

## Bootstrap the cluster

Here're the NixOS profiles for the RKE2 cluster:

| Profile                         | Install On?         |
| ------------------------------- | ------------------- |
| `services.rke2-hasee.bootstrap` | The 1st server node |
| `services.rke2-hasee.server`    | Other server nodes  |
| `services.rke2-hasee.agent`     | Agent nodes         |

1. Deploy the 1st server node.
2. Apply the cilium kustomizations, wait for the cilium to be ready.
   ```shell
   scp root@hasee01:/etc/rancher/rke2/rke2.yaml ~/.kube/config
   yq -i '.clusters[0].cluster.server = "https://10.112.8.2:6443"' ~/.kube/config
   kubectl apply -k k8s/cilium --server-side
   kubectl apply -k k8s/kube-vip --server-side
   yq -i '.clusters[0].cluster.server = "https://10.112.8.100:6443"' ~/.kube/config
   ```

TODO: deploy the rest of the nodes.
