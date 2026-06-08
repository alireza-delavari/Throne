#!/bin/bash
# FINAL_UBUNTU20_COMPAT_NO_LINUX_UPDATER_V2
set -euo pipefail

TAGS="with_clash_api,with_gvisor,with_quic,with_wireguard,with_utls,with_dhcp,with_tailscale,badlinkname,tfogo_checklinkname0"

rm -rf "$DEST"
mkdir -p "$DEST"

if [[ "${GOOS}" =~ legacy$ ]]; then
    IS_LEGACY=true
    GOCMD="$PWD/golang.org/go/bin/go"
    GOOS="${GOOS%legacy}"
else
    IS_LEGACY=false
    GOCMD="go"
fi

# Keep Windows updater behavior for non-Linux workflows.
# Do not download the official Linux updater here: current upstream Linux updater
# releases are built against newer glibc and require GLIBC_2.33/GLIBC_2.34, which
# breaks Ubuntu 20.04 compatibility.
if [[ "$GOOS" == "windows" ]]; then
    FILE="updater-windows-x${GOARCH: -2}.exe"
    curl -fLso "$DEST/updater.exe" "https://github.com/throneproj/updater/releases/latest/download/$FILE"
fi

case "$GOOS" in
  windows)
    export CGO_ENABLED=0
    if ! $IS_LEGACY; then
      TAGS+=",with_purego,with_naive_outbound"
      curl -fLso "$DEST/libcronet.dll" "https://github.com/SagerNet/cronet-go/releases/latest/download/libcronet-windows-$GOARCH.dll"
    fi
    ;;
  darwin)
    TAGS+=",with_naive_outbound"
    export CGO_ENABLED=1 CGO_LDFLAGS="-weak_framework UniformTypeIdentifiers"
    ;;
  linux)
    TAGS+=",with_naive_outbound"
    export CGO_ENABLED=1
    ;;
esac

#### Go: core ####
pushd core/server
pushd gen
protoc -I . --go_out=. --go-grpc_out=. libcore.proto
popd
VERSION_SINGBOX=$(go list -m -f '{{.Version}}' github.com/sagernet/sing-box)
$GOCMD build -v -o "$DEST" -trimpath -ldflags "-w -s -X 'github.com/sagernet/sing-box/constant.Version=${VERSION_SINGBOX}' -X 'internal/godebug.defaultGODEBUG=multipathtcp=0' -checklinkname=0" -tags "$TAGS"
popd
