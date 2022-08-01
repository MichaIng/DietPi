{
. /boot/dietpi/func/dietpi-globals || exit 1

G_AGUP
G_AGDUG

# APT dependencies: https://github.com/dani-garcia/vaultwarden/wiki/Building-binary#dependencies
adeps_build=('gcc' 'libc6-dev' 'pkg-config' 'libssl-dev')
adeps=('bash' 'libc6' 'openssl')
(( $G_DISTRO > 6 )) && adeps+=('libssl3') || adeps+=('libssl1.1')
G_AG_CHECK_INSTALL_PREREQ "${adeps_build[@]}"

# Install Rust via https://rustup.rs/
# - Needs to be installed in tmpfs, else builds fail in emulated 32-bit ARM environments: https://github.com/rust-lang/cargo/issues/8719
export HOME='/tmp/vaultwarden'
[[ -d $HOME ]] || G_EXEC mkdir "$HOME"
G_EXEC cd "$HOME"
G_EXEC curl -sSfL 'https://sh.rustup.rs' -o rustup-init.sh
G_EXEC chmod +x rustup-init.sh
# - ARMv6: Set default target explicitly, otherwise it compiles for ARMv7 in emulated container
grep -q 'raspbian' /etc/os-release && host=('--default-host' 'arm-unknown-linux-gnueabihf') || host=()
G_EXEC_OUTPUT=1 G_EXEC ./rustup-init.sh -y --profile minimal --default-toolchain none "${host[@]}"
G_EXEC_NOHALT=1 G_EXEC rm rustup-init.sh
export PATH="$HOME/.cargo/bin:$PATH"

version='1.25.2'
G_DIETPI-NOTIFY 2 "Building vaultwarden version \e[33m$version"
[[ -d vaultwarden-$version ]] && G_EXEC rm -R "vaultwarden-$version"
G_EXEC curl -sSfLO "https://github.com/dani-garcia/vaultwarden/archive/$version.tar.gz"
G_EXEC tar xf "$version.tar.gz"
G_EXEC rm "$version.tar.gz"
G_EXEC cd "vaultwarden-$version"
G_EXEC_OUTPUT=1 G_EXEC cargo build --features sqlite --release
G_EXEC rustup self uninstall -y
G_EXEC strip --remove-section=.comment --remove-section=.note target/release/vaultwarden

# Build DEB package
G_DIETPI-NOTIFY 2 'Building vaultwarden DEB package'
G_EXEC cd "$HOME"
grep -q 'raspbian' /etc/os-release && DIR='vaultwarden_armv6l' || DIR="vaultwarden_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,opt/vaultwarden,mnt/dietpi_userdata/vaultwarden,lib/systemd/system}

# - Copy files in place
G_EXEC mv "vaultwarden-$version/target/release/vaultwarden" "$DIR/opt/vaultwarden/"
G_EXEC mv "vaultwarden-$version/.env.template" "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_EXEC rm -R "vaultwarden-$version"

# - web vault
wv_version='2022.6.2'
G_DIETPI-NOTIFY 2 "Downloading web vault version \e[33m$wv_version"
G_EXEC curl -sSfLO "https://github.com/dani-garcia/bw_web_builds/releases/download/v$wv_version/bw_web_v$wv_version.tar.gz"
G_EXEC tar xf "bw_web_v$wv_version.tar.gz" --one-top-level="$DIR/mnt/dietpi_userdata/vaultwarden"
G_EXEC rm "bw_web_v$wv_version.tar.gz"

# - Configuration
G_CONFIG_INJECT 'DATA_FOLDER=' 'DATA_FOLDER=/mnt/dietpi_userdata/vaultwarden' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_CONFIG_INJECT 'ROCKET_ADDRESS=' 'ROCKET_ADDRESS=0.0.0.0' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_CONFIG_INJECT 'ROCKET_PORT=' 'ROCKET_PORT=8001' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env" # Avoid port conflict with IceCast
G_CONFIG_INJECT 'ROCKET_TLS=' 'ROCKET_TLS={certs="./cert.pem",key="./privkey.pem"}' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_CONFIG_INJECT 'WEB_VAULT_ENABLED=' 'WEB_VAULT_ENABLED=true' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"

# - systemd service
cat << '_EOF_' > "$DIR/lib/systemd/system/vaultwarden.service"
[Unit]
Description=vaultwarden (DietPi)
Documentation=https://github.com/dani-garcia/vaultwarden
Wants=network-online.target
After=network-online.target

# Restart attempt only 5 times
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
# Server sometimes fails to start on startup, this should fix it
Restart=on-failure
RestartSec=5s
# The user vaultwarden is run under. the working directory (see below) should allow write and read access to this user
User=vaultwarden
# The location of the .env file for configuration
EnvironmentFile=/mnt/dietpi_userdata/vaultwarden/vaultwarden.env
# The location of the compiled binary
ExecStart=/opt/vaultwarden/vaultwarden
# Set reasonable connection and process limits
LimitNOFILE=1048576
LimitNPROC=64
# Isolate vaultwarden from the rest of the system
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
# Only allow writes to the following directory and set it to the working directory (user and password data are stored here)
WorkingDirectory=/mnt/dietpi_userdata/vaultwarden
ReadWritePaths=-/mnt/dietpi_userdata/vaultwarden
# Allow vaultwarden to bind ports in the range of 0-1024
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
_EOF_

# - Permissions
G_EXEC find "$DIR" -type f -exec chmod 0644 {} +
G_EXEC find "$DIR" -type d -exec chmod 0755 {} +
G_EXEC chmod +x "$DIR/opt/vaultwarden/vaultwarden"

# Control files

# - conffiles
echo '/mnt/dietpi_userdata/vaultwarden/vaultwarden.env' > "$DIR/DEBIAN/conffiles"

# - postinst
cat << '_EOF_' > "$DIR/DEBIAN/postinst"
#!/bin/bash
if [[ -d '/run/systemd/system' ]]
then
	if getent passwd vaultwarden > /dev/null
	then
		echo 'Configuring vaultwarden service user ...'
		usermod -d /mnt/dietpi_userdata/vaultwarden -s /usr/sbin/nologin vaultwarden
	else
		echo 'Creating vaultwarden service user ...'
		useradd -rMU -d /mnt/dietpi_userdata/vaultwarden -s /usr/sbin/nologin vaultwarden
	fi

	if [[ ! -f '/mnt/dietpi_userdata/vaultwarden/cert.pem' || ! -f '/mnt/dietpi_userdata/vaultwarden/privkey.pem' ]]
	then
		ip=$(ip -br a s dev "$(ip r l 0/0 | mawk '{print $5;exit}')" | mawk '{print $3;exit}') ip=${ip%/*}
		openssl req -reqexts SAN -subj '/CN=DietPi Vaultwarden' -config <(cat /etc/ssl/openssl.cnf <(echo -ne "[SAN]\nsubjectAltName=DNS:$(</etc/hostname),IP:$ip\nbasicConstraints=CA:TRUE,pathlen:0"))\
			-x509 -days 7200 -sha256 -extensions SAN -out /mnt/dietpi_userdata/vaultwarden/cert.pem\
			-newkey rsa:4096 -nodes -keyout /mnt/dietpi_userdata/vaultwarden/privkey.pem
	fi

	echo 'Set vaultwarden userdata owner ...'
	chown -R vaultwarden:vaultwarden /mnt/dietpi_userdata/vaultwarden

	echo 'Configuring vaultwarden systemd service ...'
	systemctl unmask vaultwarden
	systemctl enable --now vaultwarden
fi
_EOF_

# - prerm
cat << '_EOF_' > "$DIR/DEBIAN/prerm"
#!/bin/sh
if [ "$1" = 'remove' ] && [ -d '/run/systemd/system' ] && [ -f '/lib/systemd/system/vaultwarden.service' ]
then
	echo 'Deconfiguring vaultwarden systemd service ...'
	systemctl unmask vaultwarden
	systemctl disable --now vaultwarden
fi
_EOF_

# - postrm
cat << '_EOF_' > "$DIR/DEBIAN/postrm"
#!/bin/sh
if [ "$1" = 'purge' ]
then
	if [ -d '/etc/systemd/system/vaultwarden.service.d' ]
	then
		echo 'Removing vaultwarden systemd service overrides ...'
		rm -Rv /etc/systemd/system/vaultwarden.service.d
	fi

	if getent passwd vaultwarden > /dev/null
	then
		echo 'Removing vaultwarden service user ...'
		userdel vaultwarden
	fi

	if getent group vaultwarden > /dev/null
	then
		echo 'Removing vaultwarden service group ...'
		groupdel vaultwarden
	fi
fi
_EOF_

G_EXEC chmod +x "$DIR/DEBIAN/"{postinst,prerm,postrm}

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
Package: vaultwarden
Version: $version-dietpi2
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -u '+%a, %d %b %Y %T %z')
Standards-Version: 4.6.1.0
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: misc
Priority: optional
Homepage: https://github.com/dani-garcia/vaultwarden
Vcs-Git: https://github.com/dani-garcia/vaultwarden.git
Vcs-Browser: https://github.com/dani-garcia/vaultwarden
Description: Alternative implementation of the Bitwarden server API written in
 Rust and compatible with upstream Bitwarden clients, perfect for self-hosted
 deployment where running the official resource-heavy service might not be ideal.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC rm -Rf "$DIR.deb"
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"
G_EXEC rm -Rf "$DIR"

exit 0
}
