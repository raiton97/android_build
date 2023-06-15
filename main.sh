#!/bin/bash
#
# Copyright (C) 2023 The Minerva's Dome.
#
# SPDX-License-Identifier: Apache-2.0
#

# Download previous ccache.
cd ~/
rclone copy mrvadrv-1:ci-test/ccache.tar.gz -P
time tar xf ccache.tar.gz

# Set up ccache.
if [ -d "$HOME/.ccache" ]; then
    export CCACHE_DIR="$HOME/.ccache"
else
    exit 1
fi
export CCACHE_EXEC="$(which ccache)"
export USE_CCACHE=1
export CCACHE_COMPRESS=1
ccache --max-size=20G

# Go to Android rootdir folder.
cd ~/android || return

# Initialize local repository.
repo init --no-repo-verify --depth=1 -u https://github.com/PixelOS-AOSP/manifest.git -b thirteen -g default,-mips,-darwin,-notdefault

# Initialize local manifest.
git clone --depth=1 https://github.com/frstprjkt/local_manifests.git -b ci-test .repo/local_manifests

# Start sync local source.
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

# [WORKAROUND]
# We may will get an fatal error on first sync, re-sync local source to fix broken sync.
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

# Prepare build environment.
. build/envsetup.sh

# Set build user and host name.
export BUILD_USERNAME="minerva"
export BUILD_HOSTNAME="android-build"

# Set up build command.
export LUNCH_TARGET="lunch aosp_citrus-userdebug"
export MAKE_TARGET="make bacon"
if [[ $MAKE != *"mka"* ]]; then
    export MAKE_TARGET="$MAKE -j$(nproc --all)"
fi

# Auto-select build method.
CCACHE_HITSIZE="$(ccache -s | grep -i "hit" | grep -Eo '[0-9.]+%')"
if [ "${CCACHE_HITSIZE%.*}" -ge "85" ]; then
    bash build.sh
else
    bash collect.sh
fi