#!/bin/sh
# Rebuild only libssl from the matching, configured Wolfi sources. libcrypto,
# its providers, and the rest of the package come directly from Wolfi.
set -eu

package=$1
source_package=$2
abi=$3
library="libssl.so.$abi"
version=$(apk info -v | sed -n "s/^$package-//p")
[ -n "$version" ] || exit 0
if [ "$abi" = 4 ] && [ "$(apk version -t "$version" 4.0.4)" != '<' ]; then
    exit 0
fi

apk add --no-cache --virtual .tls-source "$source_package-dbg=$version"
ln -s "/usr/src/$source_package" /home/build
cd /home/build
patchfile=/backport/openssl-quic.patch
if patch --reverse --force --fuzz=0 --dry-run -p1 -i "$patchfile" >/dev/null 2>&1; then
    exit 0
fi
patch --forward --fuzz=0 -p1 -i "$patchfile"

# Wolfi's 3.6 recipe applies its default TLS groups patch after saving the
# debug sources. Preserve that change when relinking the library.
if [ "$abi" = 3 ]; then
    groups=/backport/wolfi-openssl36-groups.patch
    if ! patch --reverse --force --fuzz=0 --dry-run -p1 -i "$groups" >/dev/null 2>&1; then
        patch --forward --fuzz=0 -p1 -i "$groups"
    fi
fi

ln -sf "/usr/lib/libcrypto.so.$abi" "libcrypto.so.$abi"
ln -sf "libcrypto.so.$abi" libcrypto.so
make -j4 -o libcrypto.so -o "libcrypto.so.$abi" "$library"
strip --strip-unneeded "$library"

# Refuse replacements that would remove or change exported API symbols.
symbols() {
    nm -D --defined-only "$1" | awk '{print $2, $3}' | sort
}
symbols "/usr/lib/$library" > /tmp/vendor-symbols
symbols "$library" > /tmp/patched-symbols
diff -u /tmp/vendor-symbols /tmp/patched-symbols

# Record ownership and the exact vendor dependency in the APK database.
cat > /tmp/backport.yaml <<YAML
name: ranksystem-libssl$abi-backport
arch: $(apk --print-arch)
version: 1.0.0
description: Wolfi $package $version with the upstream CVE-2026-124709 fix
license: Apache-2.0
maintainer: TS3-Ranksystem fork
depends:
  - $package=$version
replaces:
  - $package
contents:
  - src: /home/build/$library
    dst: /usr/lib/$library
    file_info:
      mode: 0755
YAML
nfpm package --packager apk --config /tmp/backport.yaml --target "/out/libssl$abi.apk"
