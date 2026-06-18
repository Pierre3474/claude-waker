#!/usr/bin/env bash
# OPTIONAL — only if you run Proxmox VE. Creates a tiny unprivileged LXC to host
# the waker. Skip this entirely if you just have a Debian VM/VPS: run ../install.sh
# directly on that host instead. Edit the vars, then run ON the PVE node as root.
set -euo pipefail

CTID="${CTID:-631}"
HOSTNAME="${HOSTNAME:-claude-waker}"
IP="${IP:-dhcp}"                       # e.g. 192.168.1.50/24  or  dhcp
GW="${GW:-}"                           # e.g. 192.168.1.1      (empty if dhcp)
BRIDGE="${BRIDGE:-vmbr0}"
VLAN="${VLAN:-}"                       # e.g. 20   (empty = no tag)
STORAGE="${STORAGE:-local-lvm}"
TEMPLATE_STORE="${TEMPLATE_STORE:-local}"
TEMPLATE="${TEMPLATE:-debian-12-standard_12.12-1_amd64.tar.zst}"

pveam update || true
pveam list "$TEMPLATE_STORE" | grep -q "$TEMPLATE" || pveam download "$TEMPLATE_STORE" "$TEMPLATE"

net="name=eth0,bridge=${BRIDGE},ip=${IP}"
[[ -n "$GW"   ]] && net="${net},gw=${GW}"
[[ -n "$VLAN" ]] && net="${net},tag=${VLAN}"

pct create "$CTID" "${TEMPLATE_STORE}:vztmpl/${TEMPLATE}" \
  --hostname "$HOSTNAME" \
  --cores 1 --memory 512 --swap 256 \
  --rootfs "${STORAGE}:4" \
  --net0 "$net" \
  --features nesting=1 \
  --onboot 1 --unprivileged 1 \
  --description "claude-waker - opens 5h usage windows"

pct start "$CTID"
echo "CT $CTID up. Now push this repo inside and run install.sh:"
echo "  tar czf - -C .. . | pct exec $CTID -- tar xzf - -C /root/ && pct exec $CTID -- bash -c 'cd /root && ./install.sh'"
