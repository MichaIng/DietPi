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
declare -A aURL aCHECK aARCH aARCH_CHECK aREGEX aREPLACE

# RustDesk Server
software_id='rustdeskserver'
aURL[$software_id]='https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/rustdesk-server-linux-$arch\.zip(?=\")"'
aARCH[$software_id]='armv7 arm64v8 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/rustdesk/rustdesk-server/releases/download/.*/rustdesk-server-linux-\$arch\.zip'

# RustDesk Client
software_id='rustdeskclient'
aURL[$software_id]='https://api.github.com/repos/rustdesk/rustdesk/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/rustdesk-[0-9.]*-$arch\.deb(?=\")"'
aARCH[$software_id]='armv7-sciter aarch64 x86_64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/rustdesk/rustdesk/releases/download/.*/rustdesk-.*-\$arch\.deb'

# microblog.pub: Update Python version
software_id='microblogpub'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/pyenv/pyenv/contents/plugins/python-build/share/python-build?ref=master'\'' | grep -Po '\''"name": *"\K3\.11\.[0-9]*(?=")'\'' | sort -Vr | head -1'
aREGEX[$software_id]='micro_python_version='\''[^'\'']*'\'
aREPLACE[$software_id]='micro_python_version='\''$release'\'

# TasmoAdmin
software_id='tasmoadmin'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/TasmoAdmin/TasmoAdmin/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/tasmoadmin_v[^"\/]*\.tar\.gz(?=")'\'
aREGEX[$software_id]='https://github.com/TasmoAdmin/TasmoAdmin/releases/download/.*/tasmoadmin_.*\.tar\.gz'

# NoMachine: Check for riscv64?
#software_id='nomachine'

# Airsonic-Advanced
software_id='airsonic'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/airsonic-advanced/airsonic-advanced/releases'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/airsonic\.war(?=")'\'' | head -1'
aREGEX[$software_id]='https://github.com/airsonic-advanced/airsonic-advanced/releases/download/.*/airsonic.war'

# Lyrion Music Server
software_id='lms'
aURL[$software_id]='https://raw.githubusercontent.com/LMS-Community/lms-server-repository/master/stable.xml'
aCHECK[$software_id]='echo "$response" | grep -om1 "https://[^\"]*_$arch.deb"'
aARCH[$software_id]='arm amd64'
aARCH_CHECK[$software_id]='riscv riscv64'
aREGEX[$software_id]='https://downloads.lms-community.org/nightly/lyrionmusicserver_.*_\$arch.deb'

# FreshRSS
software_id='freshrss'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/FreshRSS/FreshRSS/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\''\;'
aREPLACE[$software_id]='version='\''$release'\''\;'

# Ampache
software_id='ampache'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ampache/ampache/releases'\'' | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/ampache-[0-9\.]*_all_php8.2\.zip(?=\")" | head -1'
aREGEX[$software_id]='https://github.com/ampache/ampache/releases/download/.*/ampache-.*_all_php\$PHP_VERSION.zip'
aREPLACE[$software_id]='${release/8.2/\$PHP_VERSION}'

# Emby
software_id='emby'
aURL[$software_id]='https://api.github.com/repos/MediaBrowser/Emby.Releases/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/emby-server-deb_[^\"\/]*_$arch\.deb(?=\")"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/MediaBrowser/Emby.Releases/releases/download/.*/emby-server-deb_.*_\$arch.deb'

# ownCloud Infinite Scale
software_id='ocis'
aURL[$software_id]='https://api.github.com/repos/owncloud/ocis/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/ocis-[^\"\/]*-linux-$arch(?=\")"'
aARCH[$software_id]='arm arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/owncloud/ocis/releases/download/.*/ocis-.*-linux-\$arch'

# Gogs
software_id='gogs'
aURL[$software_id]='https://api.github.com/repos/gogs/gogs/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/gogs_[^\"\/]*_linux_$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/gogs/gogs/releases/download/.*/gogs_.*_linux_\$arch.tar.gz'

# Syncthing
software_id='syncthing'
aURL[$software_id]='https://api.github.com/repos/syncthing/syncthing/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/syncthing-linux-$arch-[^\"\/]*\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/syncthing/syncthing/releases/download/.*/syncthing-linux-\$arch-.*\.tar\.gz'

# phpBB
software_id='phpbb'
aCHECK[$software_id]='curl -sSf '\''https://version.phpbb.com/phpbb/versions.json'\'' | sed -En '\''/"stable":/,/"unstable":/s/.*"current": "(.+)",.*/\1/p'\'' | sort -Vr | head -1'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# Single File PHP Gallery
software_id='sfpg'
aCHECK[$software_id]='curl -sSf '\''https://sye.dk/sfpg/?latest'\'
aREGEX[$software_id]='file='\''[^'\'']*'\'
aREPLACE[$software_id]='file='\''$release'\'

# Baïkal
software_id='baikal'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/sabre-io/Baikal/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/baikal-[^"\/]*\.zip(?=")'\'
aREGEX[$software_id]='https://github.com/sabre-io/Baikal/releases/download/.*/baikal-.*\.zip'

# Box86
software_id='box86'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ptitSeb/box86/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# phpMyAdmin
software_id='phpmyadmin'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/phpmyadmin/phpmyadmin/releases'\'' | grep -Po '\''"name": *"\K[0-9.]+(?=")'\'' | sort -rV | head -1'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# Prometheus Node Exporter
software_id='prometheusnodeexporter'
aURL[$software_id]='https://api.github.com/repos/prometheus/node_exporter/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/node_exporter-.*\.linux-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github\.com/prometheus/node_exporter/releases/download/.*/node_exporter-.*\.linux-\$arch\.tar\.gz'

# Lidarr
software_id='lidarr'
aURL[$software_id]='https://api.github.com/repos/Lidarr/Lidarr/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*linux-core-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Lidarr/Lidarr/releases/download/v[^0].*/Lidarr.master\..*\.linux-core-\$arch\.tar\.gz'

# rTorrent
software_id='rtorrent'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/Novik/ruTorrent/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# NAA Daemon: Currently has no fallback URL/version
#software_id='naadaemon'

# BirdNET-Go
software_id='birdnetgo'
aURL[$software_id]='https://api.github.com/repos/tphakala/birdnet-go/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*-linux-$arch-[0-9]*\.tar\.gz(?=\")"'
aARCH[$software_id]='arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/tphakala/birdnet-go/releases/download/.*-linux-\$arch-[0-9]*\.tar\.gz'

# YaCy
software_id='yacy'
aCHECK[$software_id]='curl -sSf '\''https://download.yacy.net/?C=N;O=D'\'' | grep -o '\''yacy_v[0-9._a-f]*\.tar\.gz'\'' | head -1'
aREGEX[$software_id]='file='\''[^'\'']*'\'
aREPLACE[$software_id]='file='\''$release'\'

# Koel
software_id='koel'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/koel/koel/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/koel-[^"\/]*\.tar\.gz(?=")'\'
aREGEX[$software_id]='https://github.com/koel/koel/releases/download/v[^8].*/koel-.*\.tar\.gz'

# Sonarr
software_id='sonarr'
aURL[$software_id]='https://api.github.com/repos/Sonarr/Sonarr/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*linux-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Sonarr/Sonarr/releases/download/.*/Sonarr.main\..*\.linux-\$arch\.tar\.gz'

# Radarr
software_id='radarr'
aURL[$software_id]='https://api.github.com/repos/Radarr/Radarr/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*linux-core-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Radarr/Radarr/releases/download/v[^3].*/Radarr.master\..*\.linux-core-\$arch\.tar\.gz'

# Jackett
software_id='jackett'
aURL[$software_id]='https://api.github.com/repos/Jackett/Jackett/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/Jackett\.Binaries\.$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='Mono LinuxARM32 LinuxARM64 LinuxAMDx64'
aARCH_CHECK[$software_id]='LinuxRISCV64'
aREGEX[$software_id]='https://github.com/Jackett/Jackett/releases/download/.*/Jackett.Binaries.$arch.tar.gz'

# NZBGet
software_id='nzbget'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/nzbgetcom/nzbget/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/nzbget-[^"/]*-bin-linux\.run(?=")'\'
aREGEX[$software_id]='https://github.com/nzbgetcom/nzbget/releases/download/.*/nzbget-.*-bin-linux.run'

# Prowlarr
software_id='prowlarr'
aURL[$software_id]='https://api.github.com/repos/Prowlarr/Prowlarr/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*linux-core-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Prowlarr/Prowlarr/releases/download/.*/Prowlarr.master\..*\.linux-core-\$arch\.tar\.gz'

# Gitea
software_id='gitea'
aURL[$software_id]='https://api.github.com/repos/go-gitea/gitea/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/gitea-[^\"\/]*-linux-$arch\.xz(?=\")"'
aARCH[$software_id]='arm-6 arm64 amd64 riscv64'
aARCH_CHECK[$software_id]='arm-7'
aREGEX[$software_id]='https://github.com/go-gitea/gitea/releases/download/.*/gitea-.*-linux-\$arch.xz'

# frp
software_id='frp'
aURL[$software_id]='https://api.github.com/repos/fatedier/frp/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/frp_[0-9.]*_linux_$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm_hf arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/fatedier/frp/releases/download/.*/frp_.*_linux_\$arch.tar.gz'

# Uptime Kuma
software_id='uptimekuma'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/louislam/uptime-kuma/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\''; '
aREPLACE[$software_id]='version='\''$release'\''; '

# Forgejo
software_id='forgejo'
aURL[$software_id]='https://codeberg.org/api/v1/repos/forgejo/forgejo/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*-linux-$arch\.xz(?=\")"'
aARCH[$software_id]='arm-6 arm64 amd64'
aARCH_CHECK[$software_id]='arm-7 riscv64'
aREGEX[$software_id]='https://codeberg.org/forgejo/forgejo/releases/download/.*/forgejo-.*-linux-\$arch.xz'

# Komga
software_id='komga'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/gotson/komga/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/komga-[^"\/]*\.jar(?=")'\'
aREGEX[$software_id]='https://github.com/gotson/komga/releases/download/.*/komga-.*\.jar'

# PaperMC
software_id='papermc'
aCHECK[$software_id]='url='\''https://fill.papermc.io/v3/projects/paper'\''; version=$(curl -sSf "$url"); version=${version#*:\[\"} version=${version%%\"*}; build=$(curl -sSf "$url/versions/$version"); build=${build##*\":\[} build=${build%%,*}; url=$(curl -sSf "$url/versions/$version/builds/$build"); url=${url##*\"url\":\"} url=${url%%\"*}; echo "$url"'
aREGEX[$software_id]='https://fill-data.papermc.io/v1/objects/.*/paper-[^1].*\.jar'

# PaperMC v1.21
software_id='papermc-alt1'
aCHECK[$software_id]='url='\''https://fill.papermc.io/v3/projects/paper'\''; version=$(curl -sSf "$url"); version=${version#*\"1.21\":\[\"} version=${version%%\"*}; build=$(curl -sSf "$url/versions/$version"); build=${build##*\":\[} build=${build%%,*}; url=$(curl -sSf "$url/versions/$version/builds/$build"); url=${url##*\"url\":\"} url=${url%%\"*}; echo "$url"'
aREGEX[$software_id]='https://fill-data.papermc.io/v1/objects/.*/paper-1\.21\..*\.jar'

# Kubo
software_id='kubo'
aURL[$software_id]='https://api.github.com/repos/ipfs/kubo/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/kubo_[^\"\/]*_linux-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/ipfs/kubo/releases/download/.*/kubo_.*_linux-\$arch\.tar\.gz'

# Go
software_id='go'
aURL[$software_id]='https://go.dev/dl/?mode=json'
aCHECK[$software_id]='echo "$response" | grep -o "go[0-9.]*\.linux-$arch\.tar\.gz" | head -1'
aARCH[$software_id]='armv6l arm64 amd64 riscv64'
aARCH_CHECK[$software_id]='armv7l'
aREGEX[$software_id]='go[0-9.]*\.linux-\$arch\.tar\.gz'

# Snapcast Server: Implement distro loop?
software_id='snapcastserver'
aURL[$software_id]='https://api.github.com/repos/snapcast/snapcast/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/snapserver_[^\"\/]*_${arch}_bookworm\.deb(?=\")"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/snapcast/snapcast/releases/download/.*/snapserver_.*_\${arch}_\$dist.deb'
aREPLACE[$software_id]='${release/bookworm/\$dist}'

# Snapcast Server: snapweb
software_id='snapcastserver-alt1'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/snapcast/snapweb/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/snapweb_[^"\/]*_all\.deb(?=")'\'
aREGEX[$software_id]='https://github.com/snapcast/snapweb/releases/download/.*/snapweb_.*_all\.deb'

# Snapcast Client: Implement distro loop?
software_id='snapcastclient'
aURL[$software_id]='https://api.github.com/repos/snapcast/snapcast/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/snapclient_[^\"\/]*_${arch}_bookworm\.deb(?=\")"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/snapcast/snapcast/releases/download/.*/snapclient_.*_\${arch}_\$dist.deb'
aREPLACE[$software_id]='${release/bookworm/\$dist}'

# Box64
software_id='box64'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/ptitSeb/box64/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# File Browser
software_id='filebrowser'
aURL[$software_id]='https://api.github.com/repos/filebrowser/filebrowser/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/linux-$arch-filebrowser\.tar\.gz(?=\")"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/filebrowser/filebrowser/releases/download/.*/linux-\$arch-filebrowser\.tar\.gz'

# HomeBox
software_id='homebox'
aURL[$software_id]='https://api.github.com/repos/sysadminsmedia/homebox/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/homebox_Linux_$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm64 x86_64 riscv64'
aREGEX[$software_id]='https://github.com/sysadminsmedia/homebox/releases/download/.*/homebox_Linux_\$arch\.tar\.gz'

# Spotifyd: only full variants for now
software_id='spotifyd'
aURL[$software_id]='https://api.github.com/repos/Spotifyd/spotifyd/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/spotifyd-linux-$arch-full\.tar\.gz(?=\")"'
aARCH[$software_id]='armv7 aarch64 x86_64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Spotifyd/spotifyd/releases/download/v[^$].*/spotifyd-linux-\$arch-\$variant\.tar\.gz'
aREPLACE[$software_id]='${release/full/\$variant}'

# Rclone
software_id='rclone'
aURL[$software_id]='https://api.github.com/repos/rclone/rclone/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/rclone-v[^\"\/]*-linux-$arch\.deb(?=\")"'
aARCH[$software_id]='arm-v6 arm-v7 arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/rclone/rclone/releases/download/.*/rclone-.*-linux-\$arch\.deb'

# Readarr
software_id='readarr'
aURL[$software_id]='https://api.github.com/repos/Readarr/Readarr/releases'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*linux-core-$arch\.tar\.gz(?=\")" | head -1'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Readarr/Readarr/releases/download/.*/Readarr.develop\..*\.linux-core-\$arch\.tar\.gz'

# Navidrome
software_id='navidrome'
aURL[$software_id]='https://api.github.com/repos/navidrome/navidrome/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/navidrome_[0-9.]*_linux_$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/navidrome/navidrome/releases/download/.*/navidrome_.*_linux_\$arch.tar.gz'

# Restic
software_id='restic'
aURL[$software_id]='https://api.github.com/repos/restic/restic/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/restic_[^\"\/]*_linux_$arch\.bz2(?=\")"'
aARCH[$software_id]='arm arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/restic/restic/releases/download/.*/restic_.*_linux_\$arch.bz2'

# MediaWiki
software_id='mediawiki'
aCHECK[$software_id]='curl -sSf '\''https://www.mediawiki.org/wiki/Download'\'' | grep -o '\''https://releases\.wikimedia\.org/mediawiki/[^/"]*/mediawiki-[^"]*\.tar\.gz'\'' | head -1'
aREGEX[$software_id]='https://releases.wikimedia.org/mediawiki/.*/mediawiki-.*\.tar\.gz'

# Kavita
software_id='kavita'
aURL[$software_id]='https://api.github.com/repos/Kareadita/Kavita/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/kavita-linux-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm arm64 x64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/Kareadita/Kavita/releases/download/.*/kavita-linux-\$arch\.tar\.gz'

# soju
software_id='soju'
aCHECK[$software_id]='curl -sSf '\''https://codeberg.org/api/v1/repos/emersion/soju/releases/latest'\'' | grep -Po '\''"browser_download_url": *"\K[^"]*\/soju-[^"\/]*\.tar\.gz(?=")'\'
aREGEX[$software_id]='https://codeberg.org/emersion/soju/releases/download/.*/soju-.*\.tar\.gz'

# WhoDB
software_id='whodb'
aURL[$software_id]='https://api.github.com/repos/clidey/whodb/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/whodb-[0-9][^\"\/]*-linux-$arch(?=\")"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github.com/clidey/whodb/releases/download/.*/whodb-[0-9].*-linux-\$arch'

# Immich
software_id='immich'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/immich-app/immich/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# VectorChord (for Immich)
software_id='immich-alt1'
aURL[$software_id]='https://api.github.com/repos/supervc-stack/VectorChord/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*-15-vchord_[^\"\/]*_$arch\.deb(?=\")"'
aARCH[$software_id]='arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/supervc-stack/VectorChord/releases/download/.*/postgresql-.*-vchord_.*_$arch.deb'
aREPLACE[$software_id]='${release/-15-vchord_/-\$version-vchord_}'

# extism-js (for Immich corePlugin build)
software_id='immich-alt2'
aURL[$software_id]='https://api.github.com/repos/extism/js-pdk/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/extism-js-$arch-linux-[^\"\/]*\.gz(?=\")"'
aARCH[$software_id]='aarch64 x86_64'
aREGEX[$software_id]='https://github.com/extism/js-pdk/releases/download/.*/extism-js-$arch-linux-.*.gz'

# binaryen wasm-merge (for Immich corePlugin build)
software_id='immich-alt3'
aURL[$software_id]='https://api.github.com/repos/WebAssembly/binaryen/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/binaryen-[^\"\/]*-$arch-linux\.tar\.gz(?=\")"'
aARCH[$software_id]='aarch64 x86_64'
aREGEX[$software_id]='https://github.com/WebAssembly/binaryen/releases/download/.*/binaryen-.*-$arch-linux.tar.gz'

# Immich Machine Learning (same Immich release)
software_id='immichml'
aCHECK[$software_id]='curl -sSf '\''https://api.github.com/repos/immich-app/immich/releases/latest'\'' | grep -Po '\''"tag_name": *"\K[^"]+(?=")'\'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$release'\'

# uv
software_id='uv'
aURL[$software_id]='https://api.github.com/repos/astral-sh/uv/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/uv-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='arm-unknown-linux-musleabihf armv7-unknown-linux-gnueabihf aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu riscv64gc-unknown-linux-gnu'
aREGEX[$software_id]='https://github.com/astral-sh/uv/releases/download/.*/uv-$arch.tar.gz'

# Prometheus
software_id='prometheus'
aURL[$software_id]='https://api.github.com/repos/prometheus/prometheus/releases/latest'
aCHECK[$software_id]='echo "$response" | grep -Po "\"browser_download_url\": *\"\K[^\"]*\/prometheus-[0-9][^\"\/]*\.linux-$arch\.tar\.gz(?=\")"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github\.com/prometheus/prometheus/releases/download/.*/prometheus-[0-9][^/]*\.linux-\$arch\.tar\.gz'

### URL check loop ###

for i in "${!aCHECK[@]}"
do
	echo '------------------------------------------'
	echo "Checking software ID $i ..."
	# Fetch response once for entries with aARCH, to avoid redundant curl calls per architecture
	# set -e ensures the script exits on any curl failure
	response=
	if [[ ${aURL[$i]} ]]
	then
		if [[ $GH_TOKEN && ${aURL[$i]} == 'https://api.github.com/'* ]]
		then
			response=$(curl -sSf -H "Authorization: token $GH_TOKEN" "${aURL[$i]}")
		else
			# shellcheck disable=SC2034
			response=$(curl -sSf "${aURL[$i]}")
		fi
	fi
	# Add GitHub token if set: only relevant for entries without aURL, since those still use curl in aCHECK
	[[ $GH_TOKEN ]] && aCHECK[$i]=${aCHECK[$i]//curl -sSf \'https:\/\/api.github.com/curl -H \'Authorization: token $GH_TOKEN\' -sSf \'https://api.github.com}

	# Loop through architectures
	for arch in ${aARCH[$i]:-dummy}
	do
		[[ $arch == 'dummy' ]] && arch=''
		[[ $arch ]] && echo "Checking for architecture $arch ..."
		release=$(eval "${aCHECK[$i]}") || { (( $i == 56 )) && continue 2; }
		[[ $release ]] || Exit_Error "No release found${arch:+ for architecture $arch}"
	done
	[[ $arch ]] && release=${release/${arch}_/\$\{arch\}_} release=${release/$arch/\$arch}
	echo "Found release \"$release\""

	# Replace regex with new release if given
	if [[ ${aREGEX[$i]} ]]
	then
		# Apply replacement string if given, else unmodified release string is used
		[[ ${aREPLACE[$i]} ]] && eval "release=\"${aREPLACE[$i]}\""

		echo "Replacing \"${aREGEX[$i]}\" with \"$release\" ..."

		# Check whether regex exists in related code block
		sed -n "/^\t\tif To_Install ${i%-alt?}\([[:blank:]]\|$\)/,/^\t\tfi$/p" dietpi/dietpi-software | grep -q "${aREGEX[$i]}" || Exit_Error "Regex \"${aREGEX[$i]}\" does not exist"

		# Replace URL/version in dietpi-software
		sed -i "/^\t\tif To_Install ${i%-alt?}\([[:blank:]]\|$\)/,/^\t\tfi$/s|${aREGEX[$i]}|$release|" dietpi/dietpi-software

		# Verify that release has been added
		sed -n "/^\t\tif To_Install ${i%-alt?}\([[:blank:]]\|$\)/,/^\t\tfi$/p" dietpi/dietpi-software | grep -q "$release" || Exit_Error "Release \"$release\" failed to be added"
	fi

	# Check for possibly newly supported architectures
	for arch in ${aARCH_CHECK[$i]}
	do
		echo "Checking for possibly newly supported architecture $arch ..."
		release=$(eval "${aCHECK[$i]}") || :
		[[ $release ]] && Exit_Error "New architecture $arch is now supported"
	done
done

exit 0
}
