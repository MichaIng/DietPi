#!/bin/bash
# Created by MichaIng / micha@dietpi.com / dietpi.com
# shellcheck disable=SC2016
{
set -e

Exit_Error()
{
	echo "ERROR: $*"
	exit 1
}

### Software definitions ###

# RustDesk Server
software_id=12
aCHECK[$software_id]='curl -sSfL '\''https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/rustdesk-server-linux-$arch\.zip\"$/{print \$4}"'
aARCH[$software_id]='armv7 arm64v8 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/rustdesk/rustdesk-server/releases/download/.*/rustdesk-server-linux-\$arch\.zip'

# microblog.pub: Update Python version
software_id=16
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/pyenv/pyenv/contents/plugins/python-build/share/python-build?ref=master'\'' | mawk -F\" '\''/^ *"name": "3\.11\.[0-9]*",$/{print $4}'\'' | sort -Vr | head -1'
aREGEX[$software_id]='micro_python_version='\''[^'\'']*'\'
aREPLACE[$software_id]='micro_python_version='\''$release'\'

# TasmoAdmin (only latest/v4 for now)
software_id=27
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/TasmoAdmin/TasmoAdmin/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/tasmoadmin_v[^"\/]*\.tar\.gz"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/TasmoAdmin/TasmoAdmin/releases/download/v[^2].*/tasmoadmin_.*\.tar\.gz'

# NoMachine: Check for riscv64?
software_id=30

# Airsonic-Advanced
software_id=33
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/airsonic-advanced/airsonic-advanced/releases'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/airsonic\.war"$/{print $4}'\'' | head -1'
aREGEX[$software_id]='https://github.com/airsonic-advanced/airsonic-advanced/releases/download/.*/airsonic.war'

# Lyrion Music Server
software_id=35
aCHECK[$software_id]='curl -sSf '\''https://raw.githubusercontent.com/LMS-Community/lms-server-repository/master/stable.xml'\'' | grep -om1 "https://[^\"]*_$arch.deb"'
aARCH[$software_id]='arm amd64'
aARCH_CHECK[$software_id]='riscv riscv64'
aREGEX[$software_id]='https://downloads.lms-community.org/nightly/lyrionmusicserver_.*_\$arch.deb'

# FreshRSS
software_id=38
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/FreshRSS/FreshRSS/releases/latest'\'' | mawk -F\" '\''/^ *"tag_name": "[^"]*",$/{print $4}'\'
aREGEX[$software_id]='version='\''[^'\'']*'\''\;'
aREPLACE[$software_id]='version='\''$release'\''\;'

# Ampache v7+
software_id=40
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ampache/ampache/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/ampache-[0-9\.]*_all_php8.2.zip\"$/{print \$4}"'
aREGEX[$software_id]='https://github.com/ampache/ampache/releases/download/[^6].*/ampache-.*_all_php\$PHP_VERSION.zip'
aREPLACE[$software_id]='${release/8.2/\$PHP_VERSION}'

# Ampache v6
software_id=40000
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ampache/ampache/releases'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/ampache-[0-9\.]*_all_php7.4.zip\"$/{print \$4}" | head -1'
aREGEX[$software_id]='https://github.com/ampache/ampache/releases/download/6\..*/ampache-.*_all_php\$PHP_VERSION.zip'
aREPLACE[$software_id]='${release/7.4/\$PHP_VERSION}'

# Emby
software_id=41
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/MediaBrowser/Emby.Releases/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/emby-server-deb_[^\"\/]*_$arch\.deb\"$/{print \$4}"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/MediaBrowser/Emby.Releases/releases/download/.*/emby-server-deb_.*_\$arch.deb'

# Gogs
software_id=49
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/gogs/gogs/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/gogs_[^\"\/]*_linux_$arch.tar.gz\"$/{print \$4}"'
aARCH[$software_id]='armv8 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/gogs/gogs/releases/download/.*/gogs_.*_linux_\$arch.tar.gz'

# Syncthing
software_id=50
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/syncthing/syncthing/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/syncthing-linux-$arch-[^\"\/]*\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/syncthing/syncthing/releases/download/.*/syncthing-linux-\$arch-.*\.tar\.gz'

# phpBB
software_id=54
aCHECK[$software_id]='curl -sSf '\''https://version.phpbb.com/phpbb/versions.json'\'' | sed -En '\''/"stable":/,/"unstable":/s/.*"current": "(.+)",.*/\1/p'\'' | sort -Vr | head -1'
aREGEX[$software_id]='https://download\.phpbb\.com/pub/release/.*/.*/phpBB-.*\.tar\.bz2'
aREPLACE[$software_id]='https://download\.phpbb\.com/pub/release/${release%.*}/$release/phpBB-$release\.tar\.bz2'

# Single File PHP Gallery
software_id=56
aCHECK[$software_id]='curl -sSf '\''https://sye.dk/sfpg/?latest'\'' || { sleep 5; curl -sSf '\''https://sye.dk/sfpg/?latest'\''; }'
aREGEX[$software_id]='file='\''[^'\'']*'\'
aREPLACE[$software_id]='file='\''$release'\'

# Baïkal (only latest/v0.10 for now)
software_id=57
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/sabre-io/Baikal/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/baikal-[^"\/]*\.zip"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/sabre-io/Baikal/releases/download/0\.[^9].*/baikal-0\.[^9].*\.zip'

# Box86
software_id=62
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ptitSeb/box86/releases/latest'\'' | mawk -F\" '\''/^ *"tag_name": "[^"]*",$/{print $4}'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# Grafana ARMv6: Currently distributed from our APT repository
software_id=77
#aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/grafana/grafana/releases/latest'\'' | mawk -F\" '\''/^ *"name": "[^"]*",$/{print $4}'\'
#aREGEX[$software_id]='version='\''[^'\'']*'\'
#aREPLACE[$software_id]='version='\''$release'\'

# phpMyAdmin
software_id=90
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/phpmyadmin/phpmyadmin/releases'\'' | mawk -F\" '\''/^ *"name": "/ && $4!~/rc/ {print $4}'\'' | sort -rV | head -1'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# HAProxy
software_id=98
aCHECK[$software_id]='url=$(curl -sSf '\''https://www.haproxy.org/'\'' | grep -Po '\''(?<=href=")/download/.*/src/haproxy-.*\.tar\.gz(?=")'\'' | head -1); echo "${url:+https://www.haproxy.org$url}"'
aREGEX[$software_id]='https://www.haproxy.org/download/.*/src/haproxy-.*.tar.gz'

# Prometheus Node Exporter
software_id=99
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/prometheus/node_exporter/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/node_exporter-.*\.linux-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github\.com/prometheus/node_exporter/releases/download/.*/node_exporter-.*\.linux-\$arch\.tar\.gz'

# Lidarr
software_id=106
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Lidarr/Lidarr/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*linux-core-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Lidarr/Lidarr/releases/download/v[^0].*/Lidarr.master\..*\.linux-core-\$arch\.tar\.gz'

# rTorrent
software_id=107
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Novik/ruTorrent/releases/latest'\'' | mawk -F\" '\''/^ *"tag_name": "[^"]*",$/{print $4}'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# NAA Daemon: Currently has no fallback URL/version
software_id=124

# BirdNET-Go
software_id=127
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/tphakala/birdnet-go/releases'\'' | mawk -F\" '\''/^ *"tag_name": "[^"]*",$/{print $4}'\'' | head -1'
aREGEX[$software_id]='bnet_vers='\''[^'\'']*'\'
aREPLACE[$software_id]='bnet_vers='\''$release'\'

# YaCy
software_id=133
aCHECK[$software_id]='curl -sSf '\''https://download.yacy.net/?C=N;O=D'\'' | grep -o '\''yacy_v[0-9._a-f]*\.tar\.gz'\'' | head -1'
aREGEX[$software_id]='file='\''[^'\'']*'\'
aREPLACE[$software_id]='file='\''$release'\'

# Koel (only latest/v7 for now)
software_id=143
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/koel/koel/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/koel-[^"\/]*\.tar\.gz"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/koel/koel/releases/download/.*/koel-v[^5].*\.tar\.gz'

# Sonarr
software_id=144
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Sonarr/Sonarr/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*linux-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Sonarr/Sonarr/releases/download/.*/Sonarr.main\..*\.linux-\$arch\.tar\.gz'

# Radarr
software_id=145
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Radarr/Radarr/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*linux-core-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Radarr/Radarr/releases/download/v[^3].*/Radarr.master\..*\.linux-core-\$arch\.tar\.gz'

# Jackett
software_id=147
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Jackett/Jackett/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/Jackett\.Binaries\.$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='Mono LinuxARM32 LinuxARM64 LinuxAMDx64'
aARCH_CHECK[$software_id]='LinuxRISCV64'
aREGEX[$software_id]='https://github.com/Jackett/Jackett/releases/download/.*/Jackett.Binaries.$arch.tar.gz'

# NZBGet
software_id=149
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/nzbgetcom/nzbget/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/nzbget-[^"/]*-bin-linux.run"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/nzbgetcom/nzbget/releases/download/.*/nzbget-.*-bin-linux.run'

# Prowlarr
software_id=151
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Prowlarr/Prowlarr/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*linux-core-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Prowlarr/Prowlarr/releases/download/.*/Prowlarr.master\..*\.linux-core-\$arch\.tar\.gz'

# Home Assistant: Update Python version
software_id=157
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/pyenv/pyenv/contents/plugins/python-build/share/python-build?ref=master'\'' | mawk -F\" '\''/^ *"name": "3\.13\.[0-9]*",$/{print $4}'\'' | sort -Vr | head -1'
aREGEX[$software_id]='ha_python_version='\''[^'\'']*'\'
aREPLACE[$software_id]='ha_python_version='\''$release'\'

# Gitea
software_id=165
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/go-gitea/gitea/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/gitea-[^\"\/]*-linux-$arch\.xz\"$/{print \$4}"'
aARCH[$software_id]='arm-6 arm64 amd64 riscv64'
aARCH_CHECK[$software_id]='arm-7'
aREGEX[$software_id]='https://github.com/go-gitea/gitea/releases/download/.*/gitea-.*-linux-\$arch.xz'

# frp
software_id=171
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/fatedier/frp/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/frp_[0-9.]*_linux_$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm_hf arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/fatedier/frp/releases/download/.*/frp_.*_linux_\$arch.tar.gz'

# Forgejo v13+
software_id=177
aCHECK[$software_id]='curl -sSf '\''https://codeberg.org/api/v1/repos/forgejo/forgejo/releases/latest'\'' | mawk -v RS=, -F\" "/^\"browser_download_url\":\".*-linux-$arch\.xz\"$/{print \$4;exit}"'
aARCH[$software_id]='arm-6 arm64 amd64'
aARCH_CHECK[$software_id]='arm-7 riscv64'
aREGEX[$software_id]='https://codeberg.org/forgejo/forgejo/releases/download/v1[^2]\..*/forgejo-.*-linux-\$arch.xz'

# Forgejo v12
software_id=177000
aCHECK[$software_id]='curl -sSfL '\''https://codeberg.org/api/v1/repos/forgejo/forgejo/releases'\'' | mawk -v RS=, -F\" "/^\"browser_download_url\":\".*-12\..*-linux-$arch\.xz\"$/{print \$4}" | head -1'
aARCH[$software_id]='arm-6 arm64 amd64'
aREGEX[$software_id]='https://codeberg.org/forgejo/forgejo/releases/download/v12\..*/forgejo-.*-linux-\$arch.xz'

# Komga
software_id=179
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/gotson/komga/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/komga-[^"\/]*\.jar"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/gotson/komga/releases/download/.*/komga-.*\.jar'

# Kubo
software_id=186
aCHECK[$software_id]='curl -sSf '\''https://dist.ipfs.tech/kubo/versions'\'' | sed '\''/-rc[0-9]*$/d'\'' | tail -1'
aREGEX[$software_id]='version='\''[^'\'']*'\''; '
aREPLACE[$software_id]='version='\''$release'\''; '

# Go
software_id=188
aCHECK[$software_id]='curl -sSf '\''https://go.dev/dl/?mode=json'\'' | grep -o "go[0-9.]*\.linux-$arch\.tar\.gz" | head -1'
aARCH[$software_id]='armv6l arm64 amd64 riscv64'
aARCH_CHECK[$software_id]='armv7l'
aREGEX[$software_id]='go[0-9.]*\.linux-\$arch\.tar\.gz'

# Snapcast Server: Implement distro loop?
software_id=191
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/snapcast/snapcast/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/snapserver_[^\"\/]*_${arch}_bookworm.deb\"$/{print \$4}"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/snapcast/snapcast/releases/download/.*/snapserver_.*_\${arch}_\$dist.deb'
aREPLACE[$software_id]='${release/bookworm/\$dist}'

# Snapcast Server: snapweb
software_id=191000 # 000 appended as little hack to support multiple updates for the same software ID
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/snapcast/snapweb/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/snapweb_[^"\/]*_all.deb"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/snapcast/snapweb/releases/download/.*/snapweb_.*_all\.deb'

# Snapcast Client: Implement distro loop?
software_id=192
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/snapcast/snapcast/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/snapclient_[^\"\/]*_${arch}_bookworm.deb\"$/{print \$4}"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/snapcast/snapcast/releases/download/.*/snapclient_.*_\${arch}_\$dist.deb'
aREPLACE[$software_id]='${release/bookworm/\$dist}'

# Box64
software_id=197
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ptitSeb/box64/releases/latest'\'' | mawk -F\" '\''/^ *"tag_name": "[^"]*",$/{print $4}'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# File Browser
software_id=198
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/filebrowser/filebrowser/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/linux-$arch-filebrowser\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/filebrowser/filebrowser/releases/download/.*/linux-\$arch-filebrowser.tar.gz'

# Spotifyd: only full variants for now
software_id=199
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Spotifyd/spotifyd/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/spotifyd-linux-$arch-full\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='armv7 aarch64 x86_64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Spotifyd/spotifyd/releases/download/v[^$].*/spotifyd-linux-\$arch-\$variant.tar.gz'
aREPLACE[$software_id]='${release/full/\$variant}'

# Rclone
software_id=202
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/rclone/rclone/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/rclone-v[^\"\/]*-linux-$arch.deb\"$/{print \$4}"'
aARCH[$software_id]='arm-v6 arm-v7 arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/rclone/rclone/releases/download/.*/rclone-.*-linux-\$arch.deb'

# Readarr
software_id=203
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Readarr/Readarr/releases'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*linux-core-$arch\.tar\.gz\"$/{print \$4}" | head -1'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Readarr/Readarr/releases/download/.*/Readarr.develop\..*\.linux-core-\$arch\.tar\.gz'

# Navidrome
software_id=204
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/navidrome/navidrome/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/navidrome_[0-9.]*_linux_$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='armv6 armv7 arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/navidrome/navidrome/releases/download/.*/navidrome_.*_linux_\$arch.tar.gz'

# Restic
software_id=209
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/restic/restic/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/restic_[^\"\/]*_linux_$arch\.bz2\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/restic/restic/releases/download/.*/restic_.*_linux_\$arch.bz2'

# MediaWiki
software_id=210
aCHECK[$software_id]='curl -sSf '\''https://www.mediawiki.org/wiki/Download'\'' | grep -o '\''https://releases\.wikimedia\.org/mediawiki/[^/"]*/mediawiki-[^"]*\.tar\.gz'\'' | head -1'
aREGEX[$software_id]='https://releases.wikimedia.org/mediawiki/.*/mediawiki-.*\.tar\.gz'

# Kavita
software_id=212
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Kareadita/Kavita/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/kavita-linux-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Kareadita/Kavita/releases/download/.*/kavita-linux-\$arch.tar.gz'

# soju
software_id=213
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/emersion/soju/releases/latest'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/soju-[^"\/]*\.tar\.gz"$/{print $4}'\'
aREGEX[$software_id]='https://github.com/emersion/soju/releases/download/.*/soju-.*\.tar\.gz'

### URL check loop ###

for i in "${!aCHECK[@]}"
do
	echo '------------------------------------------'
	# Add GitHub token if set
	[[ $GH_TOKEN ]] && aCHECK[i]=${aCHECK[i]//curl -sSf \'https:\/\/api.github.com/curl -H \'Authorization: token $GH_TOKEN\' -sSf \'https://api.github.com}

	echo "Checking software ID $i ..."
	# Loop through architectures
	for arch in ${aARCH[i]:-dummy}
	do
		[[ $arch == 'dummy' ]] && arch=''
		[[ $arch ]] && echo "Checking for architecture $arch ..."
		release=$(eval "${aCHECK[i]}")
		[[ $release ]] || Exit_Error "No release found${arch:+ for architecture $arch}"
	done
	[[ $arch ]] && release=${release/${arch}_/\$\{arch\}_} release=${release/$arch/\$arch}
	echo "Found release \"$release\""

	# Replace regex with new release if given
	if [[ ${aREGEX[i]} ]]
	then
		# Apply replacement string if given, else unmodified release string is used
		[[ ${aREPLACE[i]} ]] && eval "release=\"${aREPLACE[i]}\""

		echo "Replacing \"${aREGEX[i]}\" with \"$release\" ..."

		# Check whether regex exists in related code block
		sed -n "/^\t\tif To_Install ${i%000} /,/^\t\tfi$/p" dietpi/dietpi-software | grep -q "${aREGEX[i]}" || Exit_Error "Regex \"${aREGEX[i]}\" does not exist"

		# Replace URL/version in dietpi-software
		sed -i "/^\t\tif To_Install ${i%000} /,/^\t\tfi$/s|${aREGEX[i]}|$release|" dietpi/dietpi-software

		# Verify that release has been added
		sed -n "/^\t\tif To_Install ${i%000} /,/^\t\tfi$/p" dietpi/dietpi-software | grep -q "$release" || Exit_Error "Release \"$release\" failed to be added"
	fi

	# Check for possibly newly supported architectures
	for arch in ${aARCH_CHECK[i]}
	do
		echo "Checking for possibly newly supported architecture $arch ..."
		release=$(eval "${aCHECK[i]}") || :
		[[ $release ]] && Exit_Error "New architecture $arch is now supported"
	done
done

exit 0
}
