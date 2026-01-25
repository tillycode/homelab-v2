#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(dirname "$0")

export VIP=10.112.8.100
export INTERFACE=bond0
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
export KVVERSION

kube_vip=(docker run --network host --rm "ghcr.io/kube-vip/kube-vip:$KVVERSION")
# using ARP for control plane HA and not enabling service load balancing
"${kube_vip[@]}" manifest daemonset \
  --interface "$INTERFACE" \
  --address "$VIP" \
  --inCluster \
  --taint \
  --controlplane \
  --arp \
  >"$SCRIPT_DIR/daemonset.yaml"
