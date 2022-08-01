{
. /boot/dietpi/func/dietpi-globals || exit 1

[[ $1 ]] && PLATFORM=$1
[[ $PLATFORM ]] || { G_WHIP_INPUTBOX 'Build Amiberry? Enter platform: https://github.com/midwan/amiberry/blob/master/Makefile' && PLATFORM=$G_WHIP_RETURNED_VALUE || exit 0; }
G_DIETPI-NOTIFY 2 "Amiberry will be built for platform: \e[33m$PLATFORM"

# APT dependencies
opengl_flags=('--enable-video-opengles2' '--disable-video-opengl')
adeps_build=('autoconf' 'make' 'g++' 'pkg-config' 'libdrm-dev' 'libgbm-dev' 'libudev-dev' 'libxml2-dev' 'libpng-dev' 'libfreetype6-dev' 'libflac-dev' 'libmpg123-dev' 'libmpeg2-4-dev' 'libasound2-dev' 'wget' 'kbd')
adeps=('libdrm2' 'libgl1-mesa-dri' 'libgbm1' 'libegl1' 'libudev1' 'libxml2' 'libpng16-16' 'libfreetype6' 'libflac8' 'libmpg123-0' 'libmpeg2-4' 'libasound2' 'wget' 'kbd')
(( $G_HW_ARCH == 10 )) && opengl_flags=('--disable-video-opengles2' '--enable-video-opengl') adeps_build+=('libgl1-mesa-dev') adeps+=('libgl1') || adeps_build+=('libgles2-mesa-dev') adeps+=('libgles2')
# - wget: Used for WHDLoad database update: https://github.com/midwan/amiberry/commit/d6c103e3310bcf75c2d72a15849fbdf5eb7432b5
# - kbd: For "chvt" used in systemd unit as SDL2 spams the console with every key press
if [[ $PLATFORM == 'rpi'* ]]
then
	adeps_build+=('libraspberrypi-dev')
	adeps+=('libraspberrypi0')
fi

G_AGUP
G_AGDUG
G_AG_CHECK_INSTALL_PREREQ "${adeps_build[@]}"

# Build libSDL2
v_sdl='2.0.22'
if [[ ! -d /tmp/SDL2-$v_sdl ]]
then
	G_DIETPI-NOTIFY 2 "Building libSDL2 version \e[33m$v_sdl"
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO "https://libsdl.org/release/SDL2-$v_sdl.tar.gz"
	G_EXEC tar xf "SDL2-$v_sdl.tar.gz"
	G_EXEC rm "SDL2-$v_sdl.tar.gz"
	G_EXEC cd "SDL2-$v_sdl"
	G_EXEC_OUTPUT=1 G_EXEC ./configure CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3' --enable-video-kmsdrm "${opengl_flags[@]}" --disable-video-rpi --disable-video-x11 --disable-video-wayland --disable-video-opengles1 --disable-video-vulkan --disable-video-dummy --disable-diskaudio --disable-sndio --disable-dummyaudio --disable-oss --disable-dbus
	G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
	find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
	G_EXEC rm -f /usr/local/lib/libSDL2[.-]*
	G_EXEC_OUTPUT=1 G_EXEC make install
else
	G_DIETPI-NOTIFY 2 'Skipping libSDL2 which has been built already'
fi

# Build libSDL2_image
v_img='2.6.1'
if [[ ! -d /tmp/SDL2_image-$v_img ]]
then
	G_DIETPI-NOTIFY 2 "Building libSDL2_image version \e[33m$v_img"
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO "https://libsdl.org/projects/SDL_image/release/SDL2_image-$v_img.tar.gz"
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
v_ttf='2.20.0'
if [[ ! -d /tmp/SDL2_ttf-$v_ttf ]]
then
	G_DIETPI-NOTIFY 2 "Building libSDL2_ttf version \e[33m$v_ttf"
	G_EXEC cd /tmp
	G_EXEC curl -sSfLO "https://libsdl.org/projects/SDL_ttf/release/SDL2_ttf-$v_ttf.tar.gz"
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
	G_EXEC_OUTPUT=1 G_EXEC ./bootstrap
	G_EXEC_OUTPUT=1 G_EXEC ./configure CFLAGS='-g0 -O3' CXXFLAGS='-g0 -O3'
	G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
	G_EXEC strip --strip-unneeded --remove-section=.comment --remove-section=.note capsimg.so
else
	G_DIETPI-NOTIFY 2 'Skipping capsimg which has been built already'
fi

# Build Amiberry
v_ami='5.3'
G_DIETPI-NOTIFY 2 "Building Amiberry version \e[33m$v_ami\e[90m for platform: \e[33m$PLATFORM"
[[ -d /tmp/amiberry-$v_ami ]] && G_EXEC rm -R "/tmp/amiberry-$v_ami"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/midwan/amiberry/archive/v$v_ami.tar.gz"
G_EXEC tar xf "v$v_ami.tar.gz"
G_EXEC rm "v$v_ami.tar.gz"
G_EXEC cd "amiberry-$v_ami"
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)" "PLATFORM=$PLATFORM" # Passing flags here overrides some mandatory flags in the Makefile, where -O3 is set as well.
G_EXEC strip --remove-section=.comment --remove-section=.note amiberry

# Build DEB package
G_DIETPI-NOTIFY 2 'Building Amiberry DEB package'
G_EXEC cd /tmp
DIR="amiberry_$PLATFORM"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,mnt/dietpi_userdata/amiberry/lib,lib/systemd/system}

# - Copy files in place
G_EXEC cp -a "/tmp/amiberry-$v_ami/"{abr,conf,controllers,data,kickstarts,savestates,screenshots,whdboot,amiberry} "$DIR/mnt/dietpi_userdata/amiberry/"
G_EXEC cp -aL /usr/local/lib/libSDL2{,_image,_ttf}-2.0.so.0 "$DIR/mnt/dietpi_userdata/amiberry/lib/"
G_EXEC cp -a /tmp/capsimg-master/capsimg.so "$DIR/mnt/dietpi_userdata/amiberry/lib/"

# - systemd service
cat << '_EOF_' > "$DIR/lib/systemd/system/amiberry.service"
[Unit]
Description=Amiberry Amiga Emulator (DietPi)
Documentation=https://github.com/midwan/amiberry/wiki

[Service]
WorkingDirectory=/mnt/dietpi_userdata/amiberry
Environment=LD_LIBRARY_PATH=/mnt/dietpi_userdata/amiberry/lib
ExecStartPre=/bin/chvt 3
ExecStart=/mnt/dietpi_userdata/amiberry/amiberry
ExecStopPost=/bin/chvt 1

[Install]
WantedBy=local-fs.target
_EOF_

# - Permissions
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/mnt/dietpi_userdata/amiberry/amiberry"

# Control files

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

G_EXEC chmod +x "$DIR/DEBIAN/"{prerm,postrm}

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
grep -q 'raspbian' /etc/os-release && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: amiberry
Version: $v_ami-dietpi3
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -u '+%a, %d %b %Y %T %z')
Standards-Version: 4.6.1.0
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: games
Priority: optional
Homepage: https://amiberry.com/
Vcs-Git: https://github.com/midwan/amiberry.git
Vcs-Browser: https://github.com/midwan/amiberry
Description: Optimized Amiga emulator for the Raspberry Pi and other ARM boards
 This package ships with optimized libSDL2 and capsimg builds.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC rm -Rf "$DIR.deb"
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"
G_EXEC rm -Rf "$DIR"

exit 0
}
