#!/usr/bin/env bash
# Regenerates the PHP gRPC classes of core-api from proto/inventory.proto.
# Run it from the repository root after changing the proto file:
#
#   bash scripts/generate-grpc-php.sh
#
# Needs only Docker (protoc and grpc_php_plugin come from the image).
# The .NET service compiles the same proto automatically on build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Docker on Windows (Git Bash) needs C:/... paths; on macOS/Linux pwd -W does not exist.
host_path() { (cd "$1" && pwd -W 2>/dev/null) || (cd "$1" && pwd); }
# Git Bash would also rewrite "/defs"-style container paths unless told not to.
export MSYS_NO_PATHCONV=1

docker run --rm \
  -v "$(host_path "$ROOT/proto"):/defs" \
  -v "$(host_path "$OUT"):/out" \
  namely/protoc-all:1.51_2 \
  -f inventory.proto -l php -o /out

rm -rf "$ROOT/services/core-api/app/Grpc"
mkdir -p "$ROOT/services/core-api/app/Grpc"
cp -r "$OUT/App/Grpc/." "$ROOT/services/core-api/app/Grpc/"

echo "Generated:"
find "$ROOT/services/core-api/app/Grpc" -name '*.php' | sed "s#$ROOT/##"
