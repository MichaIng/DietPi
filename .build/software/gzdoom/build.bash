#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

# APT dependencies
# - SDL2
adeps_build=('make' 'gcc' 'pkg-config' 'libc6-dev' 'libdrm-dev' 'libgbm-dev' 'libvulkan-dev' 'libasound2-dev' 'libudev-dev')
adeps=('libc6' 'libdrm2' 'libgbm1' 'libvulkan1' 'libegl1' 'libgl1-mesa-dri' 'libasound2' 'libudev1')
if (( $G_HW_ARCH == 10 ))
then
	# OpenGL for x86_64
	sdl_flags=('--disable-video-opengles2' '--enable-video-opengl')
	doom_flags=('-DHAVE_GLES2=0')
	adeps_build+=('libgl-dev' 'libegl1')
	adeps+=('libgl1')
else
	# OpenGLES2 for ARM/RISC-V
	sdl_flags=('--enable-video-opengles2' '--disable-video-opengl')
	doom_flags=('-DHAVE_GLES2=1')
	adeps_build+=('libgles-dev')
	adeps+=('libgles2')
fi
# - ZMusic: OpenAL needed for MIDI synthesizer to work. With DYN_OPENAL=1 (default), the library is not linked, so the GZDoom starts without it, and no headers needed. It is detected and in case loaded "dynamically" (opposed to linking a dynamic/shared library).
doom_flags+=('-DDYN_OPENAL=0')
adeps_build+=('cmake' 'g++' 'libglib2.0-dev' 'libopenal-dev')
adeps+=('libglib2.0-0' 'libopenal1')
# - Freedoom
adeps_build+=('unzip')
# - GZDoom
adeps_build+=('git' 'libvpx-dev' 'libbz2-dev')
adeps+=('libbz2-1.0')
case $G_DISTRO in
	6) adeps+=('libvpx6');;
	7) adeps+=('libvpx7');;
	8) adeps+=('libvpx9');;
	9) adeps+=('libvpx11');;
	*) G_DIETPI-NOTIFY 1 "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)"; exit 1;;
esac

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	# Trixie library package names often have a t64 suffix due to 64-but time_t transition: https://wiki.debian.org/ReleaseGoals/64bit-time
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Build SDL2
NAME='SDL2'
PRETTY='SDL2'
version=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL/releases/download/release-$version/$NAME-$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$NAME-$version.tar.gz"
G_EXEC rm "$NAME-$version.tar.gz"
G_EXEC cd "$NAME-$version"
G_EXEC_OUTPUT=1 G_EXEC ./configure --{,exec-}prefix='/tmp/deps' C{,XX}FLAGS='-g0 -O3' --enable-{alsa,video-{kmsdrm,vulkan},libudev} "${sdl_flags[@]}" --disable-{video-{rpi,x11,wayland,opengles1,offscreen,dummy},pipewire,jack,diskaudio,sndio,dummyaudio,oss,dbus,ime,joystick,hidapi,hidapi-joystick,sdl2-config}
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
G_EXEC_OUTPUT=1 G_EXEC cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='/tmp/deps'
G_EXEC_OUTPUT=1 G_EXEC make -C build "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC_OUTPUT=1 G_EXEC make -C build install

# Download Freedoom
NAME='freedoom'
PRETTY='Freedoom'
version=$(curl -sSf 'https://api.github.com/repos/freedoom/freedoom/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 "No latest $PRETTY version found, aborting ..."; exit 1; }
version=${version#v}
G_DIETPI-NOTIFY 2 "Downloading $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/freedoom/freedoom/releases/download/v$version/$NAME-$version.zip"
G_EXEC curl -sSfLO "https://github.com/freedoom/freedoom/releases/download/v$version/freedm-$version.zip"
[[ -d $NAME ]] && G_EXEC rm -R "$NAME"
G_EXEC unzip -j "$NAME-$version.zip" -d "$NAME"
G_EXEC unzip -j "freedm-$version.zip" "freedm-$version/freedm.wad" -d "$NAME"
G_EXEC rm {"$NAME",freedm}"-$version.zip"

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
DIR="/tmp/${NAME}_$G_HW_ARCH_NAME"
G_EXEC_OUTPUT=1 G_EXEC cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH='/tmp/deps' -DCMAKE_INSTALL_PREFIX="$DIR/usr" -DPK3_QUIET_ZIPDIR=1 -DHAVE_VULKAN=1 "${doom_flags[@]}"
G_EXEC_OUTPUT=1 G_EXEC make -C build "-j$(nproc)"
G_EXEC strip --remove-section=.comment --remove-section=.note "build/$NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC_OUTPUT=1 G_EXEC make -C build install

# Prepare DEB package
G_DIETPI-NOTIFY 2 "Building $PRETTY DEB package"
G_EXEC mkdir -p "$DIR/"{DEBIAN,usr/lib/gzdoom}

# - Libraries
G_EXEC cp -aL /tmp/deps/lib/{libSDL2-2.0,libzmusic}.so.[0-9] "$DIR/usr/lib/gzdoom/"

# - Freedoom
G_EXEC mv /tmp/freedoom/*.wad "$DIR/usr/share/games/doom/"
G_EXEC mv /tmp/freedoom "$DIR/usr/share/doc/"

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
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${NAME}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && version+="-dietpi$((suffix+1))" || version+="-dietpi1"
G_DIETPI-NOTIFY 2 "Old package version is:       \e[33m${old_version:-N/A}"
G_DIETPI-NOTIFY 2 "Building new package version: \e[33m$version"

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
 This package ships with an optimised SDL2 build, ZMusic and Freedoom.
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
