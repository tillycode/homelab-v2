---
title: IP and ASN Allocation
---

## IPs

We decided to use `10.112.0.0/16` as the private IP address for all services.
If we need more IP addresses, we may change the mask to `/12` in the future.

### Regions

| #      | Region    | IP CIDR        |
| ------ | --------- | -------------- |
| 0-31   | Home      | 10.112.0.0/19  |
| 32     | _Anycast_ | 10.112.32.0/24 |
| 33     | HGH       | 10.112.33.0/24 |
| 34-255 | N/A       |                |

### Details

| #      | Region    | IP CIDR        | Usage                       |
| ------ | --------- | -------------- | --------------------------- |
| 0-7    | Home      | 10.112.0.0/21  | Hasee Pods                  |
| 8      |           | 10.112.8.0/24  | Nodes                       |
| 9      |           | 10.112.9.0/24  | Hasee ClusterIP Services    |
| 10     |           | 10.112.10.0/24 | Hasee LoadBalancer Services |
| 11     |           | 10.112.11.0/24 | Incus contains or VMs       |
| 12-31  |           |                | Reserved                    |
| 32     | _Anycast_ | 10.112.32.0/24 |                             |
| 33     | HGH       | 10.112.33.0/24 |                             |
| 34     | WG VPN    | 10.112.34.0/24 | Wireguard Overlay Network   |
| 35-255 | N/A       |                | Unallocated                 |

### Well-known IPs

| IP           | Usage                  |
| ------------ | ---------------------- |
| 10.112.8.100 | Hasee Cluster kube-vip |

TODO: anycast DNS server

## ASNs

| ASN   | Usage      |
| ----- | ---------- |
| 64512 | Cilium BGP |
| 64513 | Home Nodes |
