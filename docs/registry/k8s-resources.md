---
title: Kubernetes Resources
---

## Load Balancer

| Type                 | Value                   | Description                            |
| -------------------- | ----------------------- | -------------------------------------- |
| `Service` label      | `lb.szp.io/pool`        | Select the `LoadBalancerIPPool` to use |
| `Service` annotation | `io.cilium/lb-ipam-ips` | Set the external IPs                   |

Cilium will advertise all LoadBalancer Services. Here're the IP pools available.

| Name      | Description                             |
| --------- | --------------------------------------- |
| `default` | Can be accessed in the internal network |
