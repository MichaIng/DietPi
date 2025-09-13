#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1
Error_Exit(){ G_DIETPI-NOTIFY 1 "$1, aborting ..."; exit 1; }

[[ $1 ]] && PLATFORM=$1
[[ $PLATFORM ]] || { G_WHIP_DEFAULT_ITEM='rpi1-sdl2' G_WHIP_INPUTBOX 'Enter platform (default: "rpi1-sdl2"): https://github.com/BlitterStudio/amiberry/blob/master/Makefile'; PLATFORM=$G_WHIP_RETURNED_VALUE; }
G_DIETPI-NOTIFY 2 "Amiberry will be built for platform: \e[33m$PLATFORM"

# Apply GitHub token if set
header=()
[[ $GH_TOKEN ]] && header=('-H' "Authorization: token $GH_TOKEN")

# APT dependencies
# - wget: Used for WHDLoad database update: https://github.com/BlitterStudio/amiberry/commit/d6c103e
# - kbd: For "chvt" used in systemd service
adeps_build=('autoconf' 'make' 'cmake' 'g++' 'pkg-config' 'libdrm-dev' 'libgbm-dev' 'libudev-dev' 'libxml2-dev' 'libpng-dev' 'libfreetype6-dev' 'libflac-dev' 'libmpg123-dev' 'libmpeg2-4-dev' 'libasound2-dev' 'libserialport-dev' 'libportmidi-dev' 'wget' 'kbd')
adeps=('libdrm2' 'libgl1-mesa-dri' 'libgbm1' 'libegl1' 'libudev1' 'libfreetype6' 'libmpeg2-4' 'libserialport0' 'libportmidi0' 'wget' 'kbd')
case $G_DISTRO in
	6) adeps+=('libxml2' 'libflac8' 'libpng16-16' 'libmpg123-0' 'libasound2');;
	7) adeps+=('libxml2' 'libflac12' 'libpng16-16' 'libmpg123-0' 'libasound2');;
	8) adeps+=('libxml2' 'libflac14' 'libpng16-16t64' 'libmpg123-0t64' 'libasound2t64');;
	9) adeps+=('libxml2-16' 'libflac14' 'libpng16-16t64' 'libmpg123-0t64' 'libasound2t64');;
	*) Error_Exit "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)";;
esac
# - Deps for RPi DispmanX builds
[[ $PLATFORM == 'rpi'[1-5] || $PLATFORM == 'rpi'[345]'-64-dmx' ]] && adeps_build+=('libraspberrypi-dev') adeps+=('libraspberrypi0')
# - Graphics rendering flags and deps
(( $G_HW_ARCH == 10 )) && opengl_flags=('--disable-video-opengles2' '--enable-video-opengl') adeps_build+=('libgl-dev' 'libegl1') adeps+=('libgl1') || opengl_flags=('--enable-video-opengles2' '--disable-video-opengl') adeps_build+=('libgles-dev') adeps+=('libgles2')

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	dpkg-query -s "$i" &> /dev/null && continue
	Error_Exit "Expected dependency package was not installed: $i"
done

# Build libSDL2
v_sdl=$(curl -sSf "${header[@]}" 'https://api.github.com/repos/libsdl-org/SDL/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
[[ $v_sdl ]] || Error_Exit 'No latest LibSDL2 version found'
G_DIETPI-NOTIFY 2 "Building libSDL2 version \e[33m$v_sdl"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL/releases/download/release-$v_sdl/SDL2-$v_sdl.tar.gz"
[[ -d /tmp/SDL2-$v_sdl ]] && G_EXEC rm -R "/tmp/SDL2-$v_sdl"
G_EXEC tar xf "SDL2-$v_sdl.tar.gz"
G_EXEC rm "SDL2-$v_sdl.tar.gz"
G_EXEC cd "SDL2-$v_sdl"
G_EXEC_OUTPUT=1 G_EXEC ./configure C{,XX}FLAGS='-g0 -O3' --enable-{alsa,video-kmsdrm,libudev,sdl2-config,joystick,hidapi,hidapi-joystick} "${opengl_flags[@]}" --disable-{video-{rpi,x11,wayland,opengles1,vulkan,offscreen,dummy},pipewire,jack,diskaudio,sndio,dummyaudio,oss,dbus,ime}
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC rm -f /usr/local/lib/libSDL2[.-]*
G_EXEC_OUTPUT=1 G_EXEC make install

# Build libSDL2_image
v_img=$(curl -sSf "${header[@]}" 'https://api.github.com/repos/libsdl-org/SDL_image/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
[[ $v_img ]] || Error_Exit 'No latest libSDL2_image version found'
G_DIETPI-NOTIFY 2 "Building libSDL2_image version \e[33m$v_img"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL_image/releases/download/release-$v_img/SDL2_image-$v_img.tar.gz"
[[ -d /tmp/SDL2_image-$v_img ]] && G_EXEC rm -R "/tmp/SDL2_ttf-$v_img"
G_EXEC tar xf "SDL2_image-$v_img.tar.gz"
G_EXEC rm "SDL2_image-$v_img.tar.gz"
G_EXEC cd "SDL2_image-$v_img"
G_EXEC_OUTPUT=1 G_EXEC ./configure C{,XX}FLAGS='-g0 -O3'
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC rm -f /usr/local/lib/libSDL2_image[.-]*
G_EXEC_OUTPUT=1 G_EXEC make install

# Build libSDL2_ttf
v_ttf=$(curl -sSf "${header[@]}" 'https://api.github.com/repos/libsdl-org/SDL_ttf/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
[[ $v_ttf ]] || Error_Exit 'No latest libSDL2_ttf version found'
G_DIETPI-NOTIFY 2 "Building libSDL2_ttf version \e[33m$v_ttf"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$v_ttf/SDL2_ttf-$v_ttf.tar.gz"
[[ -d /tmp/SDL2_ttf-$v_ttf ]] && G_EXEC rm -R "/tmp/SDL2_ttf-$v_ttf"
G_EXEC tar xf "SDL2_ttf-$v_ttf.tar.gz"
G_EXEC rm "SDL2_ttf-$v_ttf.tar.gz"
G_EXEC cd "SDL2_ttf-$v_ttf"
G_EXEC_OUTPUT=1 G_EXEC ./configure C{,XX}FLAGS='-g0 -O3'
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC rm -f /usr/local/lib/libSDL2_ttf[.-]*
G_EXEC_OUTPUT=1 G_EXEC make install

# Build capsimg: IPF support
G_DIETPI-NOTIFY 2 'Building capsimg'
G_EXEC cd /tmp
G_EXEC curl -sSfLO 'https://github.com/FrodeSolheim/capsimg/archive/master.tar.gz'
[[ -d '/tmp/capsimg-master' ]] && G_EXEC rm -R /tmp/capsimg-master
G_EXEC tar xf master.tar.gz
G_EXEC rm master.tar.gz
G_EXEC cd capsimg-master
# RISC-V: "checking build system type... ./config.guess: unable to guess system type"
G_EXEC curl -sSfo CAPSImg/config.guess 'https://gitweb.git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
G_EXEC curl -sSfo CAPSImg/config.sub 'https://gitweb.git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
G_EXEC_OUTPUT=1 G_EXEC ./bootstrap
G_EXEC_OUTPUT=1 G_EXEC ./configure C{,XX}FLAGS='-g0 -O3'
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
G_EXEC strip --strip-unneeded --remove-section=.comment --remove-section=.note capsimg.so

# Build Amiberry
# - ARMv6: v5.7.2 dropped support for Raspberry Pi 1, hence use v5.7.1
# - Build v5.7.4 until v7.0.0 stable has been released. It requires a major rework, using cmake and no device-specific targets anymore.
[[ $PLATFORM == 'rpi1'* ]] && v_ami='5.7.1' || v_ami='5.7.4'
G_DIETPI-NOTIFY 2 "Building Amiberry version \e[33m$v_ami\e[90m for platform: \e[33m$PLATFORM"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/BlitterStudio/amiberry/archive/v$v_ami.tar.gz"
[[ -d amiberry-$v_ami ]] && G_EXEC rm -R "amiberry-$v_ami"
G_EXEC tar xf "v$v_ami.tar.gz"
G_EXEC rm "v$v_ami.tar.gz"
G_EXEC cd "amiberry-$v_ami"
# - Add lib to rpath
G_EXEC sed --follow-symlinks -i '/^LDFLAGS = /s|$| -Wl,-rpath,/mnt/dietpi_userdata/amiberry/lib|' Makefile
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)" "PLATFORM=$PLATFORM" # Passing compiler flags here overrides some mandatory ones in the Makefile, where -O3 is set as well.
G_EXEC strip --remove-section=.comment --remove-section=.note amiberry

# Prepare DEB package
G_DIETPI-NOTIFY 2 'Building Amiberry DEB package'
G_EXEC cd /tmp
#DIR="amiberry_$PLATFORM"
DIR='amiberry_armv6l'
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,mnt/dietpi_userdata/amiberry/lib,lib/systemd/system}

# - Copy files in place
G_EXEC mv "/tmp/amiberry-$v_ami/"{abr,conf,controllers,data,kickstarts,plugins,savestates,screenshots,whdboot,amiberry} "$DIR/mnt/dietpi_userdata/amiberry/"
G_EXEC cp -aL /usr/local/lib/libSDL2{,_image,_ttf}-2.0.so.0 "$DIR/mnt/dietpi_userdata/amiberry/lib/"
G_EXEC cp -a /tmp/capsimg-master/capsimg.so "$DIR/mnt/dietpi_userdata/amiberry/lib/"

# - systemd service
cat << '_EOF_' > "$DIR/lib/systemd/system/amiberry.service"
[Unit]
Description=Amiberry Amiga Emulator (DietPi)
Documentation=https://github.com/BlitterStudio/amiberry/wiki

[Service]
WorkingDirectory=/mnt/dietpi_userdata/amiberry
StandardInput=tty
TTYPath=/dev/tty3
ExecStartPre=/bin/chvt 3
ExecStart=/mnt/dietpi_userdata/amiberry/amiberry
ExecStopPost=/bin/chvt 1

[Install]
WantedBy=local-fs.target
_EOF_

# - conffiles
echo '/mnt/dietpi_userdata/amiberry/conf/amiberry.conf' > "$DIR/DEBIAN/conffiles"

# - prerm
cat << '_EOF_' > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/amiberry.service' ]
then
	echo 'Deconfiguring Amiberry systemd service ...'
	systemctl --no-reload unmask amiberry
	systemctl --no-reload disable --now amiberry
fi
_EOF_

# - postrm
cat << '_EOF_' > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "$1" = 'purge' ] && [ -d '/etc/systemd/system/amiberry.service.d' ]
then
	echo 'Removing Amiberry systemd service overrides ...'
	rm -Rv /etc/systemd/system/amiberry.service.d
fi
_EOF_

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums"

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
grep -q '^ID=raspbian' /etc/os-release && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/amiberry_armv6l.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$v_ami-"* ]] && v_ami+="-dietpi$((suffix+1))" || v_ami+="-dietpi1"
G_DIETPI-NOTIFY 2 "Old package version is:       \e[33m${old_version:-N/A}"
G_DIETPI-NOTIFY 2 "Building new package version: \e[33m$v_ami"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: amiberry
Version: $v_ami
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: games
Priority: optional
Homepage: https://amiberry.com/
Description: Optimized Amiga emulator for the Raspberry Pi and other ARM boards
 This package ships with optimized libSDL2 and capsimg builds.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/mnt/dietpi_userdata/amiberry/amiberry" "$DIR/DEBIAN/"{prerm,postrm}

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

exit 0
}
