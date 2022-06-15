#!/bin/bash

echo "GHA_BUILD_FOLDER=$GHA_BUILD_FOLDER"
echo "WIN_PYTHON=$WIN_PYTHON"
echo "WIN_QT=$WIN_QT"

scripts/build-ffmpeg.sh . --target-os=win64 --arch=x86_64 --toolchain=msvc || exit 1
export PKG_CONFIG_PATH="$GHA_BUILD_FOLDER/ffmpeg-prefix/lib/pkgconfig:$PKG_CONFIG_PATH"

git clone https://github.com/xiph/opus.git && cd opus && git checkout ad8fe90db79b7d2a135e3dfd2ed6631b0c5662ab || exit 1
mkdir build && cd build
cmake \
	-G Ninja \
	-DCMAKE_C_COMPILER=cl \
	-DCMAKE_SYSTEM_NAME=Windows \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$GHA_BUILD_FOLDER/opus-prefix" \
	.. || exit 1
ninja || exit 1
ninja install || exit 1
cd ../..
export PATH="$GHA_BUILD_FOLDER/opus-prefix:$PATH"

wget https://mirror.firedaemon.com/OpenSSL/openssl-1.1.1o.zip && 7z x openssl-1.1.1o.zip || exit 1
export OPENSSL_ROOT_DIR="$GHA_BUILD_FOLDER/openssl-1.1/x64"

wget https://www.libsdl.org/release/SDL2-devel-2.0.14-VC.zip && 7z x SDL2-devel-2.0.14-VC.zip || exit 1
export SDL2_ROOT_DIR="$GHA_BUILD_FOLDER/SDL2-2.0.14"
#echo "set(SDL2_ROOT \"$SDL2_ROOT_DIR\")
#set(SDL2_INCLUDE_DIRS \"$SDL2_ROOT_DIR/include\")
#set(SDL2_LIBRARIES \"$SDL2_ROOT_DIR/lib/x64/SDL2.lib\")
#set(SDL2_LIBDIR \"$SDL2_ROOT_DIR/lib/x64\")" > "$SDL2_ROOT_DIR/SDL2Config.cmake" || exit 1

mkdir protoc && cd protoc
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.20.1/protoc-3.20.1-win64.zip && 7z x protoc-3.20.1-win64.zip || exit 1
cd ..
export PATH="$PWD/protoc/bin:$PATH"

mkdir build && cd build
cmake \
	-G Ninja \
	-DCMAKE_C_COMPILER=cl \
	-DCMAKE_C_FLAGS="-we4013 -X -I\"${INCLUDE//;/\" -I\"}\"" \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_PREFIX_PATH="$GHA_BUILD_FOLDER/ffmpeg-prefix;$GHA_BUILD_FOLDER/opus-prefix;$GHA_BUILD_FOLDER/openssl-1.1/x64;$WIN_QT" \
	-DPYTHON_EXECUTABLE="$WIN_PYTHON" \
	-DCHIAKI_ENABLE_TESTS=ON \
	-DCHIAKI_ENABLE_CLI=OFF \
	-DCHIAKI_GUI_ENABLE_SDL_GAMECONTROLLER=ON \
	.. || exit 1
sed -i 's/ -IC:\\msys64\\mingw64\\include / /g' build.ninja
sed -ri 's/(av(codec|util))\.lib/..\\ffmpeg-prefix\\lib\\lib\1.a/g' build.ninja
sed -ri 's/(kernel32\.lib)/..\\SDL2-2.0.14\\lib\\x64\\SDL2.lib \1/g' build.ninja
cp /c/msys64/mingw64/include/strings.h /c/msys64/mingw64/include/SDL2
ninja || exit 1
test/chiaki-unit.exe || exit 1
cd ..


#Deploy
COPY_DLLS="$OPENSSL_ROOT_DIR/bin/libcrypto-1_1-x64.dll $OPENSSL_ROOT_DIR/bin/libssl-1_1-x64.dll $SDL2_ROOT_DIR/lib/x64/SDL2.dll"
mkdir Chiaki && cp build/gui/chiaki.exe Chiaki || exit 1
mkdir Chiaki-PDB && cp build/gui/chiaki.pdb Chiaki-PDB || exit 1
"$WIN_QT/bin/windeployqt.exe" Chiaki/chiaki.exe || exit 1
cp -v $COPY_DLLS Chiaki
