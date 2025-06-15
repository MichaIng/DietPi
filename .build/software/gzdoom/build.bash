#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

# APT dependencies
# - libSDL2
adeps_build=('make' 'gcc' 'pkg-config' 'libc6-dev' 'libdrm-dev' 'libgbm-dev' 'libasound2-dev' 'libudev-dev')
adeps=('libc6' 'libdrm2' 'libgbm1' 'libegl1' 'libgl1-mesa-dri' 'libasound2' 'libudev1')
(( $G_HW_ARCH == 10 )) && sdl_flags=('--disable-video-opengles2' '--enable-video-opengl') doom_flags=('-DHAVE_GLES2=OFF') adeps_build+=('libgl-dev' 'libegl1') adeps+=('libgl1') || sdl_flags=('--enable-video-opengles2' '--disable-video-opengl') doom_flags=('-DHAVE_GLES2=ON') adeps_build+=('libgles-dev') adeps+=('libgles2')
# -- Disable Vulkan on ARMv6/7 since GZDoom does not full support 32-bit at the moment, failing with "error: cannot convert ‘std::nullptr_t’ to ‘VkSurfaceKHR’ {aka ‘long long unsigned int’} in initialization" in Vulkan-related code block.
(( $G_HW_ARCH > 2 )) && sdl_flags+=('--enable-video-vulkan') doom_flags+=('-DHAVE_VULKAN=ON') adeps_build+=('libvulkan-dev') adeps+=('libvulkan1') || sdl_flags+=('--disable-video-vulkan') doom_flags+=('-DHAVE_VULKAN=OFF')
# - ZMusic
adeps_build+=('cmake' 'g++' 'libglib2.0-dev' 'libopenal1')
adeps+=('libglib2.0-0' 'libopenal1') # OpenAL needed for MIDI synthesizer to work
# - GZDoom
adeps_build+=('git' 'libvpx-dev')
case $G_DISTRO in
	6) adeps+=('libvpx6');;
	7) adeps+=('libvpx7');;
	8) adeps+=('libvpx9');;
	*) G_DIETPI-NOTIFY 1 "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)"; exit 1;;
esac

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Trixie: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Build libSDL2
NAME='SDL2'
PRETTY='libSDL2'
version=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL/releases/download/release-$version/$NAME-$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$NAME-$version.tar.gz"
G_EXEC rm "$NAME-$version.tar.gz"
G_EXEC cd "$NAME-$version"
G_EXEC_OUTPUT=1 G_EXEC ./configure --prefix='/tmp/deps' --exec-prefix='/tmp/deps' CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3' --enable-{alsa,video-kmsdrm,libudev} "${sdl_flags[@]}" --disable-{video-{rpi,x11,wayland,opengles1,offscreen,dummy},pipewire,jack,diskaudio,sndio,dummyaudio,oss,dbus,ime,joystick,hidapi,hidapi-joystick,sdl2-config}
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
[[ -d '/tmp/deps' ]] && G_EXEC rm -R /tmp/deps
G_EXEC_OUTPUT=1 G_EXEC make install

# Build ZMusic
NAME='ZMusic'
PRETTY='ZMusic'
version=$(curl -sSf 'https://api.github.com/repos/ZDoom/ZMusic/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/ZDoom/ZMusic/archive/$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$version.tar.gz"
G_EXEC rm "$version.tar.gz"
G_EXEC cd "$NAME-$version"
export CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3'
# - 32-bit ARM flags
case $G_HW_ARCH in
	1) CFLAGS+=' -march=armv6zk+fp' CXXFLAGS+=' -march=armv6zk+fp';;
	2) CFLAGS+=' -march=armv7-a+neon-vfpv4' CXXFLAGS+=' -march=armv7-a+neon-vfpv4';;
	*) :;;
esac
G_EXEC_OUTPUT=1 G_EXEC cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='/tmp/deps'
G_EXEC_OUTPUT=1 G_EXEC make -C build "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC_OUTPUT=1 G_EXEC make -C build install

# Build GZDoom
NAME='gzdoom'
PRETTY='GZDoom'
version=$(curl -sSf 'https://api.github.com/repos/ZDoom/gzdoom/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
version=${version#g}
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
[[ -d $NAME ]] && G_EXEC rm -R "$NAME"
G_EXEC_OUTPUT=1 G_EXEC git clone -b "$version" 'https://github.com/ZDoom/gzdoom'
G_EXEC cd "$NAME"
export LDFLAGS='-L/tmp/deps/lib'
G_EXEC sed --follow-symlinks -i -e '1a\include_directories(/tmp/deps/include)' -e '1a\set(CMAKE_INSTALL_RPATH "/usr/lib/gzdoom")' CMakeLists.txt
# Prevent src/CMakeLists.txt from overwriting rpath if INSTALL_RPATH is not set, which is however expected at this point. ToDo: open PR to check for CMAKE_INSTALL_RPATH instead.
G_EXEC sed --follow-symlinks -i '1a\set(INSTALL_RPATH "/usr/lib/gzdoom")' src/CMakeLists.txt
# Fix ARMv6/7 builds due to bug in old lzma/7zip code: https://salsa.debian.org/debian/7zip/-/raw/debian/bullseye-backports/debian/patches/0004-Guard-ARM-v8-feature-from-old-architecture.patch
(( $G_HW_ARCH > 2 )) || G_EXEC sed --follow-symlinks -i 's/(__GNUC__ > 4))$/(__GNUC__ > 4) \&\& (__ARM_ARCH >= 8))/' libraries/lzma/C/7zCrc.c
DIR="/tmp/${NAME}_$G_HW_ARCH_NAME"
G_EXEC_OUTPUT=1 G_EXEC cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH='/tmp/deps' -DCMAKE_INSTALL_PREFIX="$DIR/usr" "${doom_flags[@]}"
G_EXEC_OUTPUT=1 G_EXEC make -C build "-j$(nproc)"
G_EXEC strip --remove-section=.comment --remove-section=.note "build/$NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC_OUTPUT=1 G_EXEC make -C build install

# Prepare DEB package
G_DIETPI-NOTIFY 2 "Building $PRETTY DEB package"
G_EXEC mkdir -p "$DIR/"{DEBIAN,usr/lib/gzdoom}

# - Libraries
G_EXEC cp -aL /tmp/deps/lib/{libSDL2-2.0,libzmusic}.so.[0-9] "$DIR/usr/lib/gzdoom/"

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Trixie: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}

# - Obtain version suffix
G_EXEC_NOHALT=1 G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${NAME}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC_NOHALT=1 G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && version+="-dietpi$((suffix+1))" || version+="-dietpi1"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: $NAME
Version: $version
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: games
Priority: optional
Homepage: https://zdoom.org
Description: Modder-friendly OpenGL and Vulkan source port based on the DOOM engine
 This package ships with an optimised libSDL2 build.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/usr/bin/$NAME"

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

exit 0
}
