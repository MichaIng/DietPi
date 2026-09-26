#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1
Error_Exit(){ G_DIETPI-NOTIFY 1 "$1, aborting ..."; exit 1; }

# Apply GitHub token if set
header=()
[[ $GH_TOKEN ]] && header=('-H' "Authorization: token $GH_TOKEN")

# APT dependencies
# - SDL2
adeps_build=('make' 'gcc' 'pkg-config' 'libc6-dev' 'libdrm-dev' 'libgbm-dev' 'libegl-dev' 'libasound2-dev' 'libudev-dev')
adeps=('libc6' 'libdrm2' 'libgbm1' 'libegl1' 'libgl1-mesa-dri' 'libudev1')
# - GL or GLES
if (( $G_HW_ARCH == 10 ))
then
	sdl_flags=('--disable-video-opengles2' '--enable-video-opengl')
	adeps_build+=('libgl-dev') adeps+=('libgl1')
else
	sdl_flags=('--enable-video-opengles2' '--disable-video-opengl')
	adeps_build+=('libgles-dev') adeps+=('libgles2')
fi
# - SDL2_image
adeps_build+=('libpng-dev') adeps+=()
# - SDL2_ttf
adeps_build+=('libfreetype-dev') adeps+=('libfreetype6')
# - Amiberry
adeps_build+=('cmake' 'g++' 'libflac-dev' 'libmpg123-dev' 'libpcap0.8-dev' 'libserialport-dev' 'libportmidi-dev' 'libmpeg2-4-dev' 'libenet-dev' 'libzstd-dev')
adeps+=('libserialport0' 'libmpeg2-4' 'libenet7' 'libzstd1')
# - Distro-specific package names
case $G_DISTRO in
	7) adeps+=('libasound2' 'libpng16-16' 'libflac12' 'libmpg123-0' 'libpcap0.8' 'libportmidi0');;
	8) adeps+=('libasound2t64' 'libpng16-16t64' 'libflac14' 'libmpg123-0t64' 'libpcap0.8t64' 'libportmidi0');;
	9) adeps+=('libasound2t64' 'libpng16-16t64' 'libflac14' 'libmpg123-0t64' 'libpcap0.8t64' 'libportmidi2');;
	*) Error_Exit "Unsupported distro version: $G_DISTRO_NAME (ID=$G_DISTRO)";;
esac
# - kbd: For "chvt" used in systemd service
adeps_build+=('kbd') adeps+=('kbd')

G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	dpkg-query -s "$i" &> /dev/null && continue
	Error_Exit "Expected dependency package was not installed: $i"
done

# Build SDL2
NAME='SDL2'
PRETTY=$NAME
version=$(curl -sSf "${header[@]}" 'https://api.github.com/repos/libsdl-org/SDL/releases' | grep -Po '"name": *"\K2\.[^"]+(?=")' | head -1)
[[ $version ]] || Error_Exit "No latest $PRETTY version found"
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL/releases/download/release-$version/$NAME-$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$NAME-$version.tar.gz"
G_EXEC rm "$NAME-$version.tar.gz"
G_EXEC cd "$NAME-$version"
G_EXEC_OUTPUT=1 G_EXEC ./configure --{,exec-}prefix='/tmp/deps' C{,XX}FLAGS='-g0 -O3' --enable-{alsa,video-kmsdrm,libudev,joystick,hidapi,hidapi-joystick} "${sdl_flags[@]}" --disable-{video-{rpi,x11,wayland,opengles1,vulkan,offscreen,dummy},pipewire,jack,diskaudio,sndio,dummyaudio,oss,dbus,ime,sdl2-config}
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
[[ -d '/tmp/deps' ]] && G_EXEC rm -R /tmp/deps
G_EXEC_OUTPUT=1 G_EXEC make install

# Build SDL2_image
NAME='SDL2_image'
PRETTY=$NAME
version=$(curl -sSf "${header[@]}" 'https://api.github.com/repos/libsdl-org/SDL_image/releases' | grep -Po '"name": *"\K2\.[^"]+(?=")')
[[ $version ]] || Error_Exit "No latest $PRETTY version found"
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL_image/releases/download/release-$version/$NAME-$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$NAME-$version.tar.gz"
G_EXEC rm "$NAME-$version.tar.gz"
G_EXEC cd "$NAME-$version"
G_EXEC_OUTPUT=1 G_EXEC ./configure --{,exec-}prefix='/tmp/deps' C{,XX}FLAGS='-g0 -O3'
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC_OUTPUT=1 G_EXEC make install

# Build SDL2_ttf
NAME='SDL2_ttf'
PRETTY=$NAME
version=$(curl -sSf "${header[@]}" 'https://api.github.com/repos/libsdl-org/SDL_ttf/releases' | grep -Po '"name": *"\K2\.[^"]+(?=")')
[[ $version ]] || Error_Exit "No latest $PRETTY version found"
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$version/$NAME-$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "$NAME-$version.tar.gz"
G_EXEC rm "$NAME-$version.tar.gz"
G_EXEC cd "$NAME-$version"
G_EXEC_OUTPUT=1 G_EXEC ./configure --{,exec-}prefix='/tmp/deps' C{,XX}FLAGS='-g0 -O3'
G_EXEC_OUTPUT=1 G_EXEC make "-j$(nproc)"
find . -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded --remove-section=.comment --remove-section=.note -v {} +
G_EXEC_OUTPUT=1 G_EXEC make install

# Build Amiberry
ORGA='BlitterStudio'
PRETTY='Amiberry-Lite'
DESC='Optimised Amiga emulator for older/slower ARM SBCs'
version=$(curl -sSf "${header[@]}" "https://api.github.com/repos/$ORGA/$NAME/releases/latest" | grep -Po '"tag_name": *"\K[^"]+(?=")')
[[ $version ]] || Error_Exit "No latest $PRETTY version found"
version=${version#v}
G_DIETPI-NOTIFY 2 "Building $PRETTY version \e[33m$version"
G_EXEC cd /tmp
G_EXEC curl -sSfLO "https://github.com/$ORGA/$NAME/archive/v$version.tar.gz"
[[ -d $NAME-$version ]] && G_EXEC rm -R "$NAME-$version"
G_EXEC tar xf "v$version.tar.gz"
G_EXEC rm "v$version.tar.gz"
G_EXEC cd "$NAME-$version"
# - Add SDL2 to rpath
# shellcheck disable=SC2015
grep -q '^include(GNUInstallDirs)$' CMakeLists.txt && G_EXEC sed --follow-symlinks -i "/^include(GNUInstallDirs)$/a\set(CMAKE_INSTALL_RPATH \"\${CMAKE_INSTALL_FULL_LIBDIR}/$NAME\")" CMakeLists.txt || Error_Exit 'CMakeLists.txt does not contain "include(GNUInstallDirs)" line anymore'
G_EXEC_OUTPUT=1 G_EXEC cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH='/tmp/deps' -DCMAKE_INSTALL_PREFIX='/usr' -DUSE_IPC_SOCKET=0
G_EXEC_OUTPUT=1 G_EXEC cmake --build build
G_EXEC strip --remove-section=.comment --remove-section=.note "build/$NAME"

# Prepare DEB package
G_DIETPI-NOTIFY 2 "Building $PRETTY DEB package"
G_EXEC cd /tmp
DIR="${NAME}_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,"mnt/dietpi_userdata/$NAME",lib/systemd/system}

# - Copy files in place
G_EXEC_OUTPUT=1 G_EXEC cmake --install "$NAME-$version/build" --prefix "$DIR/usr"
# - Obtain library dir
LIB_DIR=$(find "$DIR/usr/lib/"*"/$NAME" -maxdepth 0)
G_EXEC cp -aL /tmp/deps/lib/libSDL2{,_image,_ttf}.so.0 "$LIB_DIR/"

# - systemd service
cat << _EOF_ > "$DIR/lib/systemd/system/$NAME.service" || exit 1
[Unit]
Description=$PRETTY Amiga Emulator (DietPi)
Documentation=https://github.com/BlitterStudio/amiberry/wiki

[Service]
Environment=HOME=/mnt/dietpi_userdata/$NAME
Environment=XDG_DATA_HOME=/mnt/dietpi_userdata
Environment=XDG_CONFIG_HOME=/mnt/dietpi_userdata
Environment=AMIBERRY_HOME_DIR=/mnt/dietpi_userdata/$NAME
Environment=AMIBERRY_CONFIG_DIR=/mnt/dietpi_userdata/$NAME/conf
WorkingDirectory=/mnt/dietpi_userdata/$NAME
StandardInput=tty
TTYPath=/dev/tty3
ExecStartPre=/bin/chvt 3
ExecStart=/usr/bin/$NAME
ExecStopPost=/bin/chvt 1

[Install]
WantedBy=multi-user.target
_EOF_

# - preinst
cat << '_EOF_' > "$DIR/DEBIAN/preinst" || exit 1
#!/bin/dash -e
if [ -d '/mnt/dietpi_userdata/amiberry_v5_bak' ] && [ ! -d '/mnt/dietpi_userdata/amiberry-lite' ]
then
	echo 'Using Amiberry v5 config/data backup for Amiberry-Lite ...'
	mv /mnt/dietpi_userdata/amiberry_v5_bak /mnt/dietpi_userdata/amiberry-lite
	echo 'Migrating Amiberry v5 config/data directory ...'
	[ -f '/mnt/dietpi_userdata/amiberry-lite/conf/amiberry.conf' ] && mv -v /mnt/dietpi_userdata/amiberry-lite/conf/amiberry.conf /mnt/dietpi_userdata/amiberry-lite/amiberry.conf
	rm -fv /mnt/dietpi_userdata/amiberry-lite/conf/amiberry.conf.dpkg-*
	[ -d '/mnt/dietpi_userdata/amiberry-lite/kickstarts' ] && [ ! -d '/mnt/dietpi_userdata/amiberry-lite/roms' ] && mv -v /mnt/dietpi_userdata/amiberry-lite/kickstarts /mnt/dietpi_userdata/amiberry-lite/roms
	sed --follow-symlinks -Ei '/^(rom_path|floppy_sounds_dir|saveimage_dir|data_dir|plugins_dir|saveimage_dir)=/d' /mnt/dietpi_userdata/amiberry-lite/amiberry.conf
	sed --follow-symlinks -Ei 's#dietpi_userdata/amiberry(/|$)#dietpi_userdata/amiberry-lite\1#' /mnt/dietpi_userdata/amiberry-lite/amiberry.conf
fi
_EOF_

# - prerm
cat << _EOF_ > "$DIR/DEBIAN/prerm" || exit 1
#!/bin/dash -e
if [ "\$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/$NAME.service' ]
then
	echo 'Deconfiguring $PRETTY systemd service ...'
	systemctl --no-reload unmask $NAME
	systemctl --no-reload disable --now $NAME
fi
_EOF_

# - postrm
cat << _EOF_ > "$DIR/DEBIAN/postrm" || exit 1
#!/bin/dash -e
if [ "\$1" = 'purge' ] && [ -d '/etc/systemd/system/$NAME.service.d' ]
then
	echo 'Removing $PRETTY systemd service overrides ...'
	rm -Rv /etc/systemd/system/$NAME.service.d
fi
_EOF_

# - md5sums
find "$DIR" ! \( -path "$DIR/DEBIAN" -prune \) -type f -exec md5sum {} + | sed "s|$DIR/||" > "$DIR/DEBIAN/md5sums" || exit 1

# - Obtain DEB dependency versions
DEPS_APT_VERSIONED=
for i in "${adeps[@]}"
do
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/${NAME}_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && version+="-dietpi$((suffix+1))" || version+='-dietpi1'
G_DIETPI-NOTIFY 2 "Old package version is:       \e[33m${old_version:-N/A}"
G_DIETPI-NOTIFY 2 "Building new package version: \e[33m$version"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control" || exit 1
Package: $NAME
Version: $version
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: games
Priority: optional
Homepage: https://amiberry.com/
Description: $DESC
 This package ships with optimised SDL2 builds.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# - Permissions
G_EXEC chown -R 0:0 "$DIR"
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/usr/bin/$NAME" "$DIR/DEBIAN/"{preinst,prerm,postrm}

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"

exit 0
}
