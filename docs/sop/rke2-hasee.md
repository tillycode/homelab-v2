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
3. Deploy the rest of server nodes.
4. Deploy the agent nodes.

!!! warning "Violating Cilium's Practice"

    This process violates the cilium's practice "[Don’t change the IPAM mode of an existing cluster](https://docs.cilium.io/en/v1.18/network/concepts/ipam/)".
    Note that RKE2 changes the default IPAM mode to Kubernetes Host Scope.

[^1]: [rke2-charts/packages/rke2-cilium/generated-changes/patch/values.yaml.patch at main-source · rancher/rke2-charts](https://github.com/rancher/rke2-charts/blob/main-source/packages/rke2-cilium/generated-changes/patch/values.yaml.patch#L121)
