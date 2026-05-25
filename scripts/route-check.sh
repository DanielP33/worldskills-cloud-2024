#!/bin/bash
# route-check.sh
# Validates expected connectivity matrix from cli.pdl.local
# Run this on cli.pdl.local to confirm network isolation is correctly configured

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ PASS${NC} - $1"; }
fail() { echo -e "${RED}❌ FAIL${NC} - $1"; }

check() {
  local ip=$1
  local expected=$2  # "reachable" or "unreachable"
  local label=$3

  ping -c 1 -W 2 "$ip" > /dev/null 2>&1
  local result=$?

  if [ "$expected" = "reachable" ]; then
    [ $result -eq 0 ] && pass "$label ($ip)" || fail "$label ($ip) — expected reachable"
  else
    [ $result -ne 0 ] && pass "$label ($ip) — correctly unreachable" || fail "$label ($ip) — expected unreachable but got response"
  fi
}

echo "=== Connectivity Check from cli.pdl.local ==="
echo ""

echo "--- Expected REACHABLE ---"
check 10.0.0.100   reachable "srv.pdl.local"
check 10.0.8.100   reachable "cli.pdl.local (self)"
check 10.0.9.100   reachable "dmzwin/dmzlux (100)"
check 10.0.9.101   reachable "dmzwin.pdl.local"
check 10.0.9.102   reachable "dmzlux.pdl.local"
check 172.16.128.101 reachable "intrawin.angra.local (via peering)"
check 172.16.128.102 reachable "intralux.angra.local (via peering)"
check 8.8.8.8      reachable "Internet (via NAT)"

echo ""
echo "--- Expected UNREACHABLE (network isolation) ---"
check 172.16.0.100   unreachable "srv.angra.local (PUBLIC subnet - not in peering scope)"
check 172.16.144.100 unreachable "cli.angra.local (PRIVATE-2 - not in peering scope)"
check 172.16.144.101 unreachable "172.16.144.101 (PRIVATE-2 - not in peering scope)"

echo ""
echo "=== Check complete ==="
