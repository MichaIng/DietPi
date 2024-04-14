#!/bin/bash
{
. /boot/dietpi/func/dietpi-globals || exit 1

# APT dependencies: https://github.com/dani-garcia/vaultwarden/wiki/Building-binary#dependencies
# - Git for ARMv8 workaround below: https://github.com/rust-lang/cargo/issues/10583
adeps_build=('gcc' 'libc6-dev' 'pkg-config' 'libssl-dev' 'git')
adeps=('libc6' 'openssl')
(( $G_DISTRO > 6 )) && adeps+=('libssl3') || adeps+=('libssl1.1')
G_AGUP
G_AGDUG "${adeps_build[@]}"
for i in "${adeps[@]}"
do
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || dpkg-query -s "${i}t64" &> /dev/null && continue
	G_DIETPI-NOTIFY 1 "Expected dependency package was not installed: $i"
	exit 1
done

G_DIETPI-NOTIFY 2 'Installing Rust via rustup'
# - ARMv6: Set default target explicitly, otherwise it compiles for ARMv7 in emulated container
grep -q '^ID=raspbian' /etc/os-release && G_HW_ARCH_NAME='armv6l' host=('--default-host' 'arm-unknown-linux-gnueabihf') || host=()
# - ARMv7: Apply workaround for failing crates index update in in emulated 32-bit ARM environments: https://github.com/rust-lang/cargo/issues/8719. CARGO_REGISTRIES_CRATES_IO_PROTOCOL='sparse' does not solve everything: https://github.com/rust-lang/cargo/issues/8719#issuecomment-1928540617
# - ARMv8: Apply workaround for increased cargo fetch RAM usage: https://github.com/rust-lang/cargo/issues/10583
# - Trixie: Set missing HOME, since the script runs from a systemd unit without login shell and hence no HOME set.
export HOME=$(mktemp -d) CARGO_NET_GIT_FETCH_WITH_CLI='true'
G_EXEC cd "$HOME"
G_EXEC curl -sSfo rustup-init.sh 'https://sh.rustup.rs'
G_EXEC chmod +x rustup-init.sh
G_EXEC_OUTPUT=1 G_EXEC ./rustup-init.sh -y --profile minimal --default-toolchain none "${host[@]}"
G_EXEC rm rustup-init.sh
export PATH="$HOME/.cargo/bin:$PATH"

# Obtain latest versions
# - vaultwarden
version=$(curl -sSf 'https://api.github.com/repos/dani-garcia/vaultwarden/releases/latest' | mawk -F\" '/^ *"tag_name": "[^"]*",$/{print $4}')
[[ $version ]] || { G_DIETPI-NOTIFY 1 'No latest vaultwarden version found, aborting ...'; exit 1; }
# - web vault
wv_url=$(curl -sSf 'https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest' | mawk -F\" '/^ *"browser_download_url": ".*\.tar\.gz"$/{print $4}')
[[ $wv_url ]] || { G_DIETPI-NOTIFY 1 'No latest web vault version found, aborting ...'; exit 1; }

# Build
G_DIETPI-NOTIFY 2 "Building vaultwarden version \e[33m$version"
G_EXEC curl -sSfLO "https://github.com/dani-garcia/vaultwarden/archive/$version.tar.gz"
[[ -d vaultwarden-$version ]] && G_EXEC rm -R "vaultwarden-$version"
G_EXEC tar xf "$version.tar.gz"
G_EXEC rm "$version.tar.gz"
G_EXEC cd "vaultwarden-$version"
# - Use new "release-micro" profile, which fixes 32-bit ARM builds and produces smaller binaries: https://github.com/dani-garcia/vaultwarden/issues/4320
PROFILE='release-micro'
G_EXEC_OUTPUT=1 G_EXEC cargo build --features sqlite --profile "$PROFILE"
G_EXEC_OUTPUT=1 G_EXEC rustup self uninstall -y
G_EXEC strip --remove-section=.comment --remove-section=.note "target/$PROFILE/vaultwarden"
G_EXEC cd ..

# Build DEB package
G_DIETPI-NOTIFY 2 'Building vaultwarden DEB package'
DIR="vaultwarden_$G_HW_ARCH_NAME"
[[ -d $DIR ]] && G_EXEC rm -R "$DIR"
G_EXEC mkdir -p "$DIR/"{DEBIAN,opt/vaultwarden,mnt/dietpi_userdata/vaultwarden,lib/systemd/system}

# - Copy files in place
G_EXEC mv "vaultwarden-$version/target/$PROFILE/vaultwarden" "$DIR/opt/vaultwarden/"
G_EXEC mv "vaultwarden-$version/.env.template" "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_EXEC rm -R "vaultwarden-$version"

# - web vault
G_DIETPI-NOTIFY 2 "Downloading web vault from \e[33m$wv_url"
G_EXEC curl -sSfLo archive.tar.gz "$wv_url"
G_EXEC tar xf archive.tar.gz --one-top-level="$DIR/mnt/dietpi_userdata/vaultwarden"
G_EXEC rm archive.tar.gz

# - Configuration
G_CONFIG_INJECT 'DATA_FOLDER=' 'DATA_FOLDER=/mnt/dietpi_userdata/vaultwarden' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_CONFIG_INJECT 'ROCKET_ADDRESS=' 'ROCKET_ADDRESS=0.0.0.0' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_CONFIG_INJECT 'ROCKET_PORT=' 'ROCKET_PORT=8001' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env" # Avoid port conflict with IceCast
G_CONFIG_INJECT 'ROCKET_TLS=' 'ROCKET_TLS={certs="./cert.pem",key="./privkey.pem"}' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"
G_CONFIG_INJECT 'WEB_VAULT_ENABLED=' 'WEB_VAULT_ENABLED=true' "$DIR/mnt/dietpi_userdata/vaultwarden/vaultwarden.env"

# - systemd service: https://github.com/dani-garcia/vaultwarden/wiki/Setup-as-a-systemd-service
cat << '_EOF_' > "$DIR/lib/systemd/system/vaultwarden.service"
[Unit]
Description=vaultwarden (DietPi)
Documentation=https://github.com/dani-garcia/vaultwarden
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=vaultwarden
AmbientCapabilities=CAP_NET_BIND_SERVICE
LimitNOFILE=1048576
LimitNPROC=64
WorkingDirectory=/mnt/dietpi_userdata/vaultwarden
# Workaround for failing systemd.automount since Bookworm: https://dietpi.com/forum/t/automount-option-in-fstab-prevents-automatically-mounting-a-partition-in-due-time-on-bookworm/17463/22
EnvironmentFile=-/mnt/dietpi_userdata/vaultwarden/vaultwarden.env
ExecStartPre=/bin/touch /mnt/dietpi_userdata/vaultwarden/vaultwarden.env
ExecStart=/opt/vaultwarden/vaultwarden
Restart=on-failure
RestartSec=5s

# Hardening
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=-/mnt/dietpi_userdata/vaultwarden

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

# Enable web vault remote access for fresh package installs onto existing pre-v1.25 vaultwarden installs
if [[ ! $2 ]] && grep -q '^# ROCKET_ADDRESS=0.0.0.0$' /mnt/dietpi_userdata/vaultwarden/vaultwarden.env
then
	echo 'Enabling web vault remote access ...'
	sed --follow-symlinks -i '/^# ROCKET_ADDRESS=0.0.0.0$/c\ROCKET_ADDRESS=0.0.0.0' /mnt/dietpi_userdata/vaultwarden/vaultwarden.env
fi

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
		echo 'Generating self-signed HTTPS certificate for vaultwarden ...'
		ip=$(ip -br a s dev "$(ip r l 0/0 | mawk '{print $5;exit}')" | mawk '{print $3;exit}') ip=${ip%/*}
		openssl req -reqexts SAN -subj '/CN=DietPi vaultwarden' -config <(cat /etc/ssl/openssl.cnf <(echo -ne "[SAN]\nsubjectAltName=DNS:$(</etc/hostname),IP:$ip\nbasicConstraints=CA:TRUE,pathlen:0"))\
			-x509 -days 7200 -sha256 -extensions SAN -out /mnt/dietpi_userdata/vaultwarden/cert.pem\
			-newkey rsa:4096 -nodes -keyout /mnt/dietpi_userdata/vaultwarden/privkey.pem
	fi

	echo 'Setting vaultwarden userdata owner ...'
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
	# Temporarily allow lib*t64 packages, while the 64-bit time_t transition is ongoing on Sid: https://bugs.debian.org/1065394
	dpkg-query -s "$i" &> /dev/null || i+='t64'
	DEPS_APT_VERSIONED+=" $i (>= $(dpkg-query -Wf '${VERSION}' "$i")),"
done
DEPS_APT_VERSIONED=${DEPS_APT_VERSIONED%,}
# shellcheck disable=SC2001
[[ $G_HW_ARCH_NAME == 'armv6l' ]] && DEPS_APT_VERSIONED=$(sed 's/+rp[it][0-9]\+[^)]*)/)/g' <<< "$DEPS_APT_VERSIONED") || DEPS_APT_VERSIONED=$(sed 's/+b[0-9]\+)/)/g' <<< "$DEPS_APT_VERSIONED")

# - Obtain version suffix
G_EXEC curl -sSfo package.deb "https://dietpi.com/downloads/binaries/$G_DISTRO_NAME/vaultwarden_$G_HW_ARCH_NAME.deb"
old_version=$(dpkg-deb -f package.deb Version)
G_EXEC rm package.deb
suffix=${old_version#*-dietpi}
[[ $old_version == "$version-"* ]] && version+="-dietpi$((suffix+1))" || version+="-dietpi1"

# - control
cat << _EOF_ > "$DIR/DEBIAN/control"
Package: vaultwarden
Version: $version
Architecture: $(dpkg --print-architecture)
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -uR)
Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')
Depends:$DEPS_APT_VERSIONED
Section: misc
Priority: optional
Homepage: https://github.com/dani-garcia/vaultwarden
Description: Alternative implementation of the Bitwarden server API written in
 Rust and compatible with upstream Bitwarden clients, perfect for self-hosted
 deployment where running the official resource-heavy service might not be ideal.
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk "$DIR" | mawk '{print $1}')" "$DIR/DEBIAN/control"

# Build DEB package
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b "$DIR"
G_EXEC mv "$DIR.deb" /tmp/

# Cleanup
G_EXEC cd ..
G_EXEC rm -R "$HOME"

exit 0
}
