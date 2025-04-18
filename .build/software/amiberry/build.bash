#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

# APT dependencies
# - kbd: For "chvt" used in systemd service
adeps_build=('autoconf' 'make' 'cmake' 'g++' 'pkg-config' 'libdrm-dev' 'libgbm-dev' 'libudev-dev' 'libxml2-dev' 'libpng-dev' 'libfreetype6-dev' 'libflac-dev' 'libmpg123-dev' 'libmpeg2-4-dev' 'libasound2-dev' 'libserialport-dev' 'libportmidi-dev' 'libenet-dev' 'kbd')
adeps=('libdrm2' 'libgl1-mesa-dri' 'libgbm1' 'libegl1' 'libudev1' 'libxml2' 'libpng16-16' 'libfreetype6' 'libmpg123-0' 'libmpeg2-4' 'libasound2' 'libserialport0' 'libportmidi0' 'libenet7' 'kbd')
case $G_DISTRO in
	6) adeps+=('libflac8');;
	7) adeps+=('libflac12');;
	8) adeps+=('libflac14');;
	*) G_DIETPI-NOTIFY 1 "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)"; exit 1;;
esac
# - Graphics rendering flags and deps
(( $G_HW_ARCH == 10 )) && opengl_flags=('--disable-video-opengles2' '--enable-video-opengl') adeps_build+=('libgl1-mesa-dev') adeps+=('libgl1') || opengl_flags=('--enable-video-opengles2' '--disable-video-opengl') adeps_build+=('libgles2-mesa-dev') adeps+=('libgles2')

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
v_sdl=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
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
v_img=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL_image/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
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
v_ttf=$(curl -sSf 'https://api.github.com/repos/libsdl-org/SDL_ttf/releases' | mawk -F\" '/^ *"name": "2./{print $4}' | head -1)
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

# Build Amiberry
v_ami=$(curl -sSf 'https://api.github.com/repos/BlitterStudio/amiberry/releases/latest' | mawk -F\" '/^  "tag_name"/{print $4}')
[[ $v_ami ]] || { G_DIETPI-NOTIFY 1 'No latest Amiberry version found, aborting ...'; exit 1; }
v_ami=${v_ami#v}
G_DIETPI-NOTIFY 2 "Building Amiberry version \e[33m$v_ami"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/BlitterStudio/amiberry/archive/v$v_ami.tar.gz"
[[ -d amiberry-$v_ami ]] && G_EXEC rm -R "amiberry-$v_ami"
G_EXEC tar xf "v$v_ami.tar.gz"
G_EXEC rm "v$v_ami.tar.gz"
G_EXEC cd "amiberry-$v_ami"
# - RISC-V: Workaround for missing ld.gold: https://github.com/BlitterStudio/amiberry/issues/1213
#RISCV_LD=()
#(( $G_HW_ARCH == 11 )) && RISCV_LD=('USE_LD=bfd')
G_EXEC_OUTPUT=1 G_EXEC cmake -B build -DCMAKE_INSTALL_PREFIX=/usr
G_EXEC_OUTPUT=1 G_EXEC cmake --build build
G_EXEC strip --remove-section=.comment --remove-section=.note build/amiberry

# Prepare DEB package
G_DIETPI-NOTIFY 2 'Building Amiberry DEB package'
G_EXEC cd /tmp
DIR="amiberry_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,mnt/dietpi_userdata/amiberry,lib/systemd/system}

# - Copy files in place
G_EXEC_OUTPUT=1 G_EXEC cmake --install "amiberry-$v_ami/build" --prefix "$DIR/usr"
# - Obtain library dir
LIB_DIR=$(find "$DIR/usr/lib/"*'/amiberry' -maxdepth 0)
G_EXEC cp -aL /usr/local/lib/libSDL2{,_image,_ttf}-2.0.so.0 "$LIB_DIR/"

# - systemd service
cat << _EOF_ > "$DIR/lib/systemd/system/amiberry.service"
[Unit]
Description=Amiberry Amiga Emulator (DietPi)
Documentation=https://github.com/BlitterStudio/amiberry/wiki

[Service]
Environment=LD_LIBRARY_PATH=${LIB_DIR#"$DIR"}
Environment=HOME=/mnt/dietpi_userdata/amiberry
Environment=XDG_DATA_HOME=/mnt/dietpi_userdata
Environment=XDG_CONFIG_HOME=/mnt/dietpi_userdata
Environment=AMIBERRY_HOME_DIR=/mnt/dietpi_userdata/amiberry
Environment=AMIBERRY_CONFIG_DIR=/mnt/dietpi_userdata/amiberry/conf
WorkingDirectory=/mnt/dietpi_userdata/amiberry
StandardInput=tty
TTYPath=/dev/tty3
ExecStartPre=/bin/chvt 3
ExecStart=/usr/bin/amiberry
ExecStopPost=/bin/chvt 1

[Install]
WantedBy=multi-user.target
_EOF_

# - preinst
cat << '_EOF_' > "$DIR/DEBIAN/preinst"
#!/bin/sh
if [ -d '/mnt/dietpi_userdata/amiberry' ] && [ ! -d '/mnt/dietpi_userdata/amiberry_v5_bak' ] && dpkg --compare-versions "$2" lt '5.7.5'
then
	echo 'Backing up Amiberry v5 config/data dir to /mnt/dietpi_userdata/amiberry_v5_bak ...'
	rm -Rf /mnt/dietpi_userdata/amiberry/amiberry /mnt/dietpi_userdata/amiberry/data /mnt/dietpi_userdata/amiberry/lib
	cp -a /mnt/dietpi_userdata/amiberry /mnt/dietpi_userdata/amiberry_v5_bak
	echo 'Migrating Amiberry v5 config/data directory ...'
	[ -f '/mnt/dietpi_userdata/amiberry/conf/amiberry.conf' ] && mv -v /mnt/dietpi_userdata/amiberry/conf/amiberry.conf /mnt/dietpi_userdata/amiberry/amiberry.conf
	rm -fv /mnt/dietpi_userdata/amiberry/conf/amiberry.conf.dpkg-*
	[ -d '/mnt/dietpi_userdata/amiberry/kickstarts' ] && [ ! -d '/mnt/dietpi_userdata/amiberry/roms' ] && mv -v /mnt/dietpi_userdata/amiberry/kickstarts /mnt/dietpi_userdata/amiberry/roms
	sed --follow-symlinks -Ei '/^(rom_path|floppy_sounds_dir|saveimage_dir|data_dir|plugins_dir|saveimage_dir)=/d' /mnt/dietpi_userdata/amiberry/amiberry.conf
fi
_EOF_

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
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Trixie: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}

# - Obtain version suffix
G_EXEC_NOHALT=1 G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/amiberry_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC_NOHALT=1 G_EXEC rm package.deb
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
Description: Optimised Amiga emulator for multiple platforms
 This package ships with optimised libSDL2 builds.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/usr/bin/amiberry" "$DIR/DEBIAN/"{preinst,prerm,postrm}

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

# Cleanup
G_EXEC rm -R "$DIR"

exit 0
}
