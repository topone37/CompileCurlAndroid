#!/bin/bash
# Compile curl & openssl & zlib for android with NDK.
# Copyright (C) 2018  shishuo <shishuo365@126.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

APP_ABI=(armeabi-v7a arm64-v8a)

BASE_PATH=$(
	cd "$(dirname $0)"
	pwd
)
CURL_PATH="$BASE_PATH/curl-7.67.0"
BUILD_PATH="$BASE_PATH/build"

checkExitCode() {
	if [ $1 -ne 0 ]; then
		echo "Error building curl library"
		cd $BASE_PATH
		exit $1
	fi
}
safeMakeDir() {
	if [ ! -x "$1" ]; then
		mkdir -p "$1"
	fi
}

## Android NDK
export NDK_ROOT=/media/tanpan/a393d005-ebe5-42a0-8c6a-c86fdfb185c1/Android/android-ndk-r13b
export ANDROID_NDK_HOME=/media/tanpan/a393d005-ebe5-42a0-8c6a-c86fdfb185c1/Android/android-ndk-r13b


if [ -z "$NDK_ROOT" ]; then
	echo "Please set your NDK_ROOT environment variable first"
	exit 1
fi

## Clean build directory
#rm -rf $BUILD_PATH
#safeMakeDir $BUILD_PATH



## Build cURL

compatibleWithAndroid() {
	# options -V -qversion has removed from gcc-4.9
	sed 's/ -V -qversion//' $CURL_PATH/configure >$CURL_PATH/configure.temp
	mv $CURL_PATH/configure.temp $CURL_PATH/configure
	chmod 755 $CURL_PATH/configure
}

# compile $1 ABI $2 SYSROOT $3 TOOLCHAIN $4 TARGET $5 CFLAGS
compile() {
	cd $CURL_PATH
	ABI=$1
	SYSROOT=$2
	TOOLCHAIN=$3
	TARGET=$4
	CFLAGS=$5
	# https://android.googlesource.com/platform/ndk/+/ics-mr0/docs/STANDALONE-TOOLCHAIN.html
	export SYSROOT="$SYSROOT"
	export CFLAGS="$CFLAGS --sysroot=$SYSROOT"
	export CPPFLAGS="-I$SYSROOT/usr/include --sysroot=$SYSROOT"
	export CC="$TOOLCHAIN/$TARGET-gcc"
	export CPP="$TOOLCHAIN/$TARGET-cpp"
	export CXX="$TOOLCHAIN/$TARGET-g++"
	export LD="$TOOLCHAIN/$TARGET-ld"
	export AS="$TOOLCHAIN/$TARGET-as"
	export AR="$TOOLCHAIN/$TARGET-ar"
	export NM="$TOOLCHAIN/$TARGET-nm"
	export STRIP="$TOOLCHAIN/$TARGET-strip"
	export RANLIB="$TOOLCHAIN/$TARGET-ranlib"
	export PKG_CONFIG_PATH="$BUILD_PATH/openssl/$ABI/lib/pkgconfig"
	# config
	./buildconf
	checkExitCode $?
	safeMakeDir $BUILD_PATH/curl/$ABI
	
	# extract *.o from libcurl.a
	safeMakeDir $BASE_PATH/obj/$ABI/curl
	cd $BASE_PATH/obj/$ABI/curl
	$AR -x $BUILD_PATH/curl/$ABI/lib/libcurl.a
	checkExitCode $?
	# extract *.o from libssl.a & libcrypto.a
	safeMakeDir $BASE_PATH/obj/$ABI/openssl
	cd $BASE_PATH/obj/$ABI/openssl
	$AR -x $BUILD_PATH/openssl/$ABI/lib/libssl.a
	$AR -x $BUILD_PATH/openssl/$ABI/lib/libcrypto.a
	checkExitCode $?
	# extract *.o from libz.a
	safeMakeDir $BASE_PATH/obj/$ABI/zlib
	cd $BASE_PATH/obj/$ABI/zlib
	$AR -x $BUILD_PATH/zlib/$ABI/lib/libz.a
	checkExitCode $?
	# combine *.o to libcurl.a
	safeMakeDir $BASE_PATH/libs/$ABI
	cd $BASE_PATH
	$AR -cr $BASE_PATH/libs/$ABI/libcurl.a $BASE_PATH/obj/$ABI/curl/*.o $BASE_PATH/obj/$ABI/openssl/*.o $BASE_PATH/obj/$ABI/zlib/*.o
	checkExitCode $?
	# copy dylib
	cp -f $BUILD_PATH/curl/$ABI/lib/libcurl.so $BASE_PATH/libs/$ABI/libcurl.so
	checkExitCode $?
}

# check system
host=$(uname | tr 'A-Z' 'a-z')
if [ $host = "darwin" ] || [ $host = "linux" ]; then
	echo "system: $host"
else
	echo "unsupport system, only support Mac OS X and Linux now."
	exit 1
fi

for abi in ${APP_ABI[*]}; do
	case $abi in
	armeabi-v7a)
		# https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html#ARM-Options
		compile $abi "$NDK_ROOT/platforms/android-12/arch-arm" "$NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/$host-x86_64/bin" "arm-linux-androideabi" "-march=armv7-a -mfloat-abi=softfp -mfpu=neon"
		;;
	x86)
		# http://gcc.gnu.org/onlinedocs/gcc/x86-Options.html
		compile $abi "$NDK_ROOT/platforms/android-12/arch-x86" "$NDK_ROOT/toolchains/x86-4.9/prebuilt/$host-x86_64/bin" "i686-linux-android" "-march=i686"
		;;
	arm64-v8a)
		# https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html#AArch64-Options
		compile $abi "$NDK_ROOT/platforms/android-21/arch-arm64" "$NDK_ROOT/toolchains/aarch64-linux-android-4.9/prebuilt/$host-x86_64/bin" "aarch64-linux-android" "-march=armv8-a"
		;;
	*)
		echo "Error APP_ABI"
		;;
	esac
done

echo "== build success =="
echo "path: $BASE_PATH/libs"

cd $BASE_PATH
exit 0
