### 编译`libCurl`
 > 本次编译,开启`Openssl,`Zlib`等功能选项 (高版本的`ndk`中,已经自带了`zlib`)
1. 相关配置

   - `curl: 7.67.0 `  
   - `openssl: 1.0.2r`
   - `zlib: 1.2.11`
   - `ndk: android-ndk-r13b`
   - `os: Ubuntu 16.04`

2. 编译脚本

   1. `build_zip.sh`

      ```bash
      #!/bin/bash
      
      BASE_PATH=$(
      	cd "$(dirname $0)"
      	pwd
      )
      ZLIB_PATH="xxx/zlib"
      BUILD_PATH="xxx/build"
      
      ## Android NDK
      export NDK_ROOT=/xxx/android-ndk-r13b
      
      
      rm -rf $BUILD_PATH/zlib
      mkdir -p $BUILD_PATH/zlib
      # check system
      host=$(uname | tr 'A-Z' 'a-z')
      if [ $host = "darwin" ] || [ $host = "linux" ]; then
      	echo "system: $host"
      else
      	echo "unsupport system, only support Mac OS X and Linux now."
      	exit 1
      fi
      
      
      ## Build zlib
      cd $ZLIB_PATH
      ABI=armeabi-v7a
      SYSROOT=$NDK_ROOT/platforms/android-12/arch-arm
      TOOLCHAIN=$NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/$host-x86_64/bin
      TARGET=arm-linux-androideabi
      CFLAGS=-march=armv7-a -mfloat-abi=softfp -mfpu=neon
      export CFLAGS="-I$SYSROOT/usr/include --sysroot=$SYSROOT $CFLAGS"
      # zlib configure
      export CROSS_PREFIX="$TOOLCHAIN/$TARGET-"
      # config
      mkdir -p  $BUILD_PATH/zlib/$ABI
      ./configure --prefix=$BUILD_PATH/zlib/$ABI
      
      make clean
      make -j4
      make install
      
      exit 0
      ```

   2. `build_openssl.sh`

      > 编译`openssl`需要注意,`1.1.x`的版本,在执行`Configure`命令时候,不支持`android`,只有`android-arm等其他选项`,为了方便,我这边直接使用的`1.0.x`版本

      ```bash
      #!/bin/bash
      # 前面环境变量部分基本一致,唯一不一样的是,Configure部分
      #....
      ./Configure android no-shared --prefix=$BUILD_PATH/openssl/$ABI
      
      ```

   3. `build_curl_with_ssl_and_zlib.sh`

      ```bash
      #!/bin/bash
      # 前面环境变量部分基本一致,唯一不一样的是,Configure部分
      ./configure --host=$TARGET \
      		--prefix=$BUILD_PATH/curl/$ABI \
      		--with-zlib=$BUILD_PATH/zlib/$ABI \
      		--with-ssl=$BUILD_PATH/openssl/$ABI \
      		--enable-static \
      		--enable-shared \
      		--disable-verbose \
      		--enable-threaded-resolver \
      		--enable-libgcc \
      		--enable-ipv6
      export AR="$TOOLCHAIN/$TARGET-ar"		
      	# 合并.a文件到libcurl.a
      	
      	# 从各个.a提取出.o文件,然后生成.a
      	
      	# extract *.o from libcurl.a
          $AR -x $BUILD_PATH/curl/$ABI/lib/libcurl.a
      	# extract *.o from libssl.a & libcrypto.a
      	cd $BASE_PATH/obj/$ABI/openssl
      	$AR -x $BUILD_PATH/openssl/$ABI/lib/libssl.a
      	$AR -x $BUILD_PATH/openssl/$ABI/lib/libcrypto.a
      	
      	# extract *.o from libz.a
      	cd $BASE_PATH/obj/$ABI/zlib
      	$AR -x $BUILD_PATH/zlib/$ABI/lib/libz.a
      	
      	# combine *.o to libcurl.a
      	cd $BASE_PATH
      	$AR -cr $BASE_PATH/libs/$ABI/libcurl.a $BASE_PATH/obj/$ABI/curl/*.o $BASE_PATH/obj/$ABI/openssl/*.o $BASE_PATH/obj/$ABI/zlib/*.o
      	
      
      ```

      