#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

[[ $1 ]] && PLATFORM=$1
[[ $PLATFORM ]] || { G_WHIP_INPUTBOX 'Build Amiberry? Enter platform: https://github.com/BlitterStudio/amiberry/blob/master/Makefile' && PLATFORM=$G_WHIP_RETURNED_VALUE || exit 0; }
G_DIETPI-NOTIFY 2 "Amiberry will be built for platform: \e[33m$PLATFORM"

# APT dependencies
# - wget: Used for WHDLoad database update: https://github.com/BlitterStudio/amiberry/commit/d6c103e
# - kbd: For "chvt" used in systemd service
adeps_build=('autoconf' 'make' 'cmake' 'g++' 'pkg-config' 'libdrm-dev' 'libgbm-dev' 'libudev-dev' 'libxml2-dev' 'libpng-dev' 'libfreetype6-dev' 'libflac-dev' 'libmpg123-dev' 'libmpeg2-4-dev' 'libasound2-dev' 'libserialport-dev' 'libportmidi-dev' 'wget' 'kbd')
adeps=('libdrm2' 'libgl1-mesa-dri' 'libgbm1' 'libegl1' 'libudev1' 'libxml2' 'libpng16-16' 'libfreetype6' 'libmpg123-0' 'libmpeg2-4' 'libasound2' 'libserialport0' 'libportmidi0' 'wget' 'kbd')
(( $G_DISTRO > 6 )) && adeps+=('libflac12') || adeps+=('libflac8')
# - Deps for RPi DispmanX builds
[[ $PLATFORM == 'rpi'[1-5] || $PLATFORM == 'rpi'[345]'-64-dmx' ]] && adeps_build+=('libraspberrypi-dev') adeps+=('libraspberrypi0')
# - Graphics rendering flags and deps
(( $G_HW_ARCH == 10 )) && opengl_flags=('--disable-video-opengles2' '--enable-video-opengl') adeps_build+=('libgl1-mesa-dev') adeps+=('libgl1') || opengl_flags=('--enable-video-opengles2' '--disable-video-opengl') adeps_build+=('libgles2-mesa-dev') adeps+=('libgles2')

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

# Build libSDL2
v_sdl=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL/releases/latest' | mawk -F\" '/^  "name"/{print $4}')
[[ $v_sdl ]] || { G_DIETPI-NOTIFY 1 'No latest LibSDL2 version found, aborting ...'; exit 1; }
if [[ ! -d /tmp/SDL2-$v_sdl ]]
then
	G_DIETPI-NOTIFY 2 "Building libSDL2 version \e[33m$v_sdl"
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL/releases/download/release-$v_sdl/SDL2-$v_sdl.tar.gz"
	G_EXEC tar xf "SDL2-$v_sdl.tar.gz"
	G_EXEC rm "SDL2-$v_sdl.tar.gz"
	G_EXEC cd "SDL2-$v_sdl"
	G_EXEC_OUTPUT=1 G_EXEC ./configure CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3' --enable-video-kmsdrm "${opengl_flags[@]}" --disable-video-rpi --disable-video-x11 --disable-video-wayland --disable-video-opengles1 --disable-video-vulkan --disable-video-offscreen --disable-video-dummy --disable-diskaudio --disable-sndio --disable-dummyaudio --disable-oss --disable-dbus
	G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
	find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
	G_EXEC rm -f /usr/local/lib/libSDL2[.-]*
	G_EXEC_OUTPUT=1 G_EXEC make install
else
	G_DIETPI-NOTIFY 2 'Skipping libSDL2 which has been built already'
fi

# Build libSDL2_image
v_img=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL_image/releases/latest' | mawk -F\" '/^  "name"/{print $4}')
[[ $v_img ]] || { G_DIETPI-NOTIFY 1 'No latest libSDL2_image version found, aborting ...'; exit 1; }
if [[ ! -d /tmp/SDL2_image-$v_img ]]
then
	G_DIETPI-NOTIFY 2 "Building libSDL2_image version \e[33m$v_img"
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL_image/releases/download/release-$v_img/SDL2_image-$v_img.tar.gz"
	G_EXEC tar xf "SDL2_image-$v_img.tar.gz"
	G_EXEC rm "SDL2_image-$v_img.tar.gz"
	G_EXEC cd "SDL2_image-$v_img"
	G_EXEC_OUTPUT=1 G_EXEC ./configure CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3'
	G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
	find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
	G_EXEC rm -f /usr/local/lib/libSDL2_image[.-]*
	G_EXEC_OUTPUT=1 G_EXEC make install
else
	G_DIETPI-NOTIFY 2 'Skipping libSDL2_image which has been built already'
fi

# Build libSDL2_ttf
v_ttf=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL_ttf/releases/latest' | mawk -F\" '/^  "name"/{print $4}')
[[ $v_ttf ]] || { G_DIETPI-NOTIFY 1 'No latest libSDL2_ttf version found, aborting ...'; exit 1; }
if [[ ! -d /tmp/SDL2_ttf-$v_ttf ]]
then
	G_DIETPI-NOTIFY 2 "Building libSDL2_ttf version \e[33m$v_ttf"
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$v_ttf/SDL2_ttf-$v_ttf.tar.gz"
	G_EXEC tar xf "SDL2_ttf-$v_ttf.tar.gz"
	G_EXEC rm "SDL2_ttf-$v_ttf.tar.gz"
	G_EXEC cd "SDL2_ttf-$v_ttf"
	G_EXEC_OUTPUT=1 G_EXEC ./configure CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3'
	G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
	find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
	G_EXEC rm -f /usr/local/lib/libSDL2_ttf[.-]*
	G_EXEC_OUTPUT=1 G_EXEC make install
else
	G_DIETPI-NOTIFY 2 'Skipping libSDL2_ttf which has been built already'
fi

# Build capsimg: IPF support
if [[ ! -d '/tmp/capsimg-master' ]]
then
	G_DIETPI-NOTIFY 2 'Building capsimg'
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO 'https://github.com/FrodeSolheim/capsimg/archive/master.tar.gz'
	G_EXEC tar xf master.tar.gz
	G_EXEC rm master.tar.gz
	G_EXEC cd capsimg-master
	# RISC-V: "checking build system type... ./config.guess: unable to guess system type"
	G_EXEC curl -sSfo CAPSImg/config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
	G_EXEC curl -sSfo CAPSImg/config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
	G_EXEC_OUTPUT=1 G_EXEC ./bootstrap
	G_EXEC_OUTPUT=1 G_EXEC ./configure CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3'
	G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
	G_EXEC strip --strip-unneeded --remove-section=.comment --remove-section=.note capsimg.so
else
	G_DIETPI-NOTIFY 2 'Skipping capsimg which has been built already'
fi

# Build Amiberry
v_ami=$(curl -sSf 'https://api.github.com/repos/BlitterStudio/amiberry/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $v_ami ]] || { G_DIETPI-NOTIFY 1 'No latest Amiberry version found, aborting ...'; exit 1; }
v_ami=${v_ami#v}
# - ARMv6: v5.7.2 dropped support for Raspberry Pi 1, hence use v5.7.1
[[ $PLATFORM == 'rpi1'* ]] && v_ami='5.7.1'
G_DIETPI-NOTIFY 2 "Building Amiberry version \e[33m$v_ami\e[90m for platform: \e[33m$PLATFORM"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/BlitterStudio/amiberry/archive/v$v_ami.tar.gz"
[[ -d amiberry-$v_ami ]] && G_EXEC rm -R "amiberry-$v_ami"
G_EXEC tar xf "v$v_ami.tar.gz"
G_EXEC rm "v$v_ami.tar.gz"
G_EXEC cd "amiberry-$v_ami"
# - RISC-V: Workaround for missing ld.gold: https://github.com/BlitterStudio/amiberry/issues/1213
RISCV_LD=()
(( $G_HW_ARCH == 11 )) && RISCV_LD=('USE_LD=bfd')
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)" "PLATFORM=$PLATFORM" "${RISCV_LD[@]}" # Passing flags here overrides some mandatory flags in the Makefile, where -O3 is set as well.
G_EXEC strip --remove-section=.comment --remove-section=.note amiberry

# Prepare DEB package
G_DIETPI-NOTIFY 2 'Building Amiberry DEB package'
G_EXEC cd /tmp
DIR="amiberry_$PLATFORM"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,mnt/dietpi_userdata/amiberry/lib,lib/systemd/system}

# - Copy files in place
G_EXEC mv "/tmp/amiberry-$v_ami/"{abr,conf,controllers,data,kickstarts,savestates,screenshots,whdboot,amiberry} "$DIR/mnt/dietpi_userdata/amiberry/"
G_EXEC cp -aL /usr/local/lib/libSDL2{,_image,_ttf}-2.0.so.0 "$DIR/mnt/dietpi_userdata/amiberry/lib/"
G_EXEC cp -a /tmp/capsimg-master/capsimg.so "$DIR/mnt/dietpi_userdata/amiberry/lib/"

# - systemd service
cat << '_EOF_' > "$DIR/lib/systemd/system/amiberry.service"
[Unit]
Description=Amiberry Amiga Emulator (DietPi)
Documentation=https://github.com/BlitterStudio/amiberry/wiki

[Service]
WorkingDirectory=/mnt/dietpi_userdata/amiberry
Environment=LD_LIBRARY_PATH=/mnt/dietpi_userdata/amiberry/lib
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
	systemctl unmask amiberry
	systemctl disable --now amiberry
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
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
grep -q '^ID=raspbian' /etc/os-release && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/amiberry_$PLATFORM.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$v_ami-"* ]] && v_ami+="-dietpi$((suffix+1))" || v_ami+="-dietpi1"

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

# Cleanup
G_EXEC rm -R "$DIR"

exit 0
}
