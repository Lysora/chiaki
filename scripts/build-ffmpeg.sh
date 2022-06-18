#!/bin/bash

cd $(dirname "${BASH_SOURCE[0]}")/..
cd "./$1"
shift
ROOT="`pwd`"

TAG=n4.4
git clone https://git.ffmpeg.org/ffmpeg.git --depth 1 -b $TAG && cd ffmpeg || exit 1

./configure \
    --disable-all \
    --enable-avcodec \
    --enable-dxva2 \
    --enable-decoder=h264 \
    --enable-decoder=hevc \
    --enable-hwaccel=h264_dxva2 \
    --enable-hwaccel=hevc_dxva2 \
    --prefix="$ROOT/ffmpeg-prefix" "$@" \
    || exit 1
make -j4 || exit 1
make install || exit 1
