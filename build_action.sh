#!/usr/bin/env bash

VERSION=$(grep 'Kernel Configuration' < config | awk '{print $3}')

# add deb-src to sources.list
sed -i "/deb-src/s/# //g" /etc/apt/sources.list

# install dep
apt update
apt install -y wget xz-utils make gcc flex bison dpkg-dev bc rsync kmod cpio libssl-dev
apt build-dep -y linux

# change dir to workplace
cd "${GITHUB_WORKSPACE}" || exit

# download kernel source
# 下载最新的 Mainline 内核源代码
TARBALL_URL=$(wget -qO- https://www.kernel.org/ | grep -oP '(?<=href=")[^"]*linux-.*?\.tar\.gz' | head -1)
# 获取版本号
VERSION=$(echo "$TARBALL_URL" | grep -oP 'linux-(\d+\.\d+-\w+)\.tar\.gz' | sed 's/linux-//;s/\.tar\.gz//')
wget "${TARBALL_URL}"
tar -zxvf "linux-${VERSION}.tar.gz"
cd "linux-${VERSION}" || exit

# copy config file
cp ../config .config

# disable DEBUG_INFO to speedup build
scripts/config --disable DEBUG_INFO

# apply patches
# shellcheck source=src/util.sh
source ../patch.d/*.sh

# build deb packages
CPU_CORES=$(($(grep -c processor < /proc/cpuinfo)*2))
make deb-pkg -j"$CPU_CORES"

# move deb packages to artifact dir
cd ..
rm -rfv *dbg*.deb
mkdir "artifact"
mv ./*.deb artifact/
