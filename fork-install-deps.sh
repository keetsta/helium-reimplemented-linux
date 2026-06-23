#!/usr/bin/env bash
#
# fork-install-deps — install, natively on a Debian trixie host, the exact build
# dependencies that docker/build.Dockerfile installs, so fork-build/fork-rebuild
# can run WITHOUT Docker. Run once. Needs root (sudo).
#
# Mirrors docker/build.Dockerfile: Node 22 (nodesource), the distro -dev set,
# clone helpers, and sccache. On x86_64 it skips cmake/clang/lld (Chromium ships
# a prebuilt clang); on other arches those are installed because LLVM is built
# locally.
#
# Usage: sudo ./fork-install-deps.sh
set -euo pipefail

NODE_VERSION="${NODE_VERSION:-22}"
SCCACHE_VERSION="${SCCACHE_VERSION:-0.10.0}"

if [ "$(id -u)" != 0 ]; then
  echo "re-running under sudo..."; exec sudo -E "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections || true

echo "==> apt update/upgrade"
apt-get -y update
apt-get -y upgrade

echo "==> Node.js ${NODE_VERSION} (nodesource)"
apt-get -y install apt-transport-https ca-certificates curl gnupg
curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
apt-get -y update
apt-get -y install nodejs

if [ "$(uname -m)" != x86_64 ]; then
  echo "==> non-x86_64: installing cmake/clang/lld for local LLVM build"
  apt-get -y install cmake clang lld
fi

echo "==> distro build packages"
apt-get -y install bison debhelper desktop-file-utils flex gperf gsettings-desktop-schemas-dev imagemagick \
  libasound2-dev libavcodec-dev libavformat-dev libavutil-dev libcap-dev libcups2-dev libcurl4-openssl-dev libdrm-dev \
  libegl1-mesa-dev libelf-dev libevent-dev libexif-dev libflac-dev libgbm-dev libgcrypt20-dev libgl1-mesa-dev libgles2-mesa-dev \
  libglew-dev libglib2.0-dev libglu1-mesa-dev libgtk-3-dev libhunspell-dev libjpeg-dev libjs-jquery-flot libjsoncpp-dev \
  libkrb5-dev liblcms2-dev libminizip-dev libmodpbase64-dev libnspr4-dev libnss3-dev libopenjp2-7-dev libopus-dev libpam0g-dev \
  libpci-dev libpipewire-0.3-dev libpng-dev libpulse-dev libre2-dev libsnappy-dev libspeechd-dev libudev-dev libusb-1.0-0-dev \
  libva-dev libvpx-dev libwebp-dev libx11-xcb-dev libxcb-dri3-dev libxshmfence-dev libxslt1-dev libxss-dev libxt-dev libxtst-dev \
  mesa-common-dev ninja-build pkg-config python3-jinja2 python3-setuptools python3-xcbgen python-is-python3 qtbase5-dev \
  uuid-dev valgrind wdiff x11-apps xcb-proto xfonts-base xvfb xz-utils yasm

echo "==> clone helpers"
apt-get -y install git python3-httplib2 python3-pyparsing python3-six python3-pillow python3-requests rsync sudo vim

echo "==> sccache ${SCCACHE_VERSION}"
_m="$(uname -m)"
curl --fail -Lo /tmp/sccache.tar.gz \
  "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-${_m}-unknown-linux-musl.tar.gz"
tar --strip-components=1 -xzf /tmp/sccache.tar.gz -C /usr/bin --wildcards '*/sccache'
rm -f /tmp/sccache.tar.gz
chmod +x /usr/bin/sccache

echo
echo "==> done. node $(node --version 2>/dev/null), sccache $(sccache --version 2>/dev/null | head -1)"
echo "Next: ./fork-build   (first build is from-scratch; see README/fork-build header)"
