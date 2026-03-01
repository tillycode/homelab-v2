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
| 32-33  | HGH       | 10.112.32.0/23 |
| 34     | _WG VPN_  | 10.112.34.0/24 |
| 35     | _Anycast_ | 10.112.35.0/24 |
| 36-255 | N/A       |                |

### Details

| #      | Region    | IP CIDR        | Usage                    |
| ------ | --------- | -------------- | ------------------------ |
| 0-7    | Home      | 10.112.0.0/21  | Hasee Pods               |
| 8      |           | 10.112.8.0/24  | Nodes                    |
| 9      |           | 10.112.9.0/24  | Hasee ClusterIP Services |
| 10     |           | 10.112.10.0/24 | Services                 |
| 11     |           | 10.112.11.0/24 | Incus containers or VMs  |
| 12-31  |           |                | Reserved                 |
| 32     | HGH       | 10.112.32.0/24 | Services                 |
| 33     |           | 10.112.33.0/24 |                          |
| 34     | _WG VPN_  | 10.112.34.0/24 | Overlay Network          |
| 35     | _Anycast_ | 10.112.35.0/24 |                          |
| 36-255 | N/A       |                | Unallocated              |

### Well-known IPs

| IP            | Usage                         |
| ------------- | ----------------------------- |
| 10.112.8.100  | Hasee Cluster kube-vip        |
| 10.112.10.100 | Hasee default gateway         |
| 10.112.10.200 | Home authoritative DNS server |
| 10.112.32.200 | HGH authoritative DNS server  |
| 10.112.35.1-2 | Anycast DNS server            |

## ASNs

| ASN   | Usage      |
| ----- | ---------- |
| 64512 | Cilium BGP |
| 64513 | Home Nodes |
