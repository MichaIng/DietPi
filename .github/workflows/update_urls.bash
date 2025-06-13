#!/bin/bash
# Created by MichaIng / micha@dietpi.com / dietpi.com
{
set -e

Exit_Error()
{
	echo "ERROR: $*"
	exit 1
}

# NoMachine: Check for riscv64?
software_id=30

# phpBB
software_id=54
aCHECK[$software_id]='curl -sSfL '\''https://www.phpbb.com/downloads/'\'' | grep -o '\''https://download\.phpbb\.com/pub/release/.*/.*/phpBB-.*\.tar\.bz2'\'
aREGEX[$software_id]='https://download\.phpbb\.com/pub/release/.*/.*/phpBB-.*\.tar\.bz2'

# phpMyAdmin
software_id=90
aCHECK[$software_id]='curl -sSfL '\''https://api.github.com/repos/phpmyadmin/phpmyadmin/releases'\'' | mawk -F\" '\''/^ *"name": "/ && $4!~/rc/ {print $4}'\'' | sort -rV | head -1'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$output'\'

# Prometheus Node Exporter
software_id=99
aCHECK[$software_id]='curl -sSfL '\''https://api.github.com/repos/prometheus/node_exporter/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/node_exporter-.*\.linux-$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='armv6 armv7 arm64 amd64 riscv64'
aREGEX[$software_id]='https://github\.com/prometheus/node_exporter/releases/download/.*/node_exporter-.*\.linux-\$arch\.tar\.gz'

# YaCy
software_id=133
aCHECK[$software_id]='curl -sSfL '\''https://download.yacy.net/?C=N;O=D'\'' | grep -o '\''yacy_v[0-9._a-f]*\.tar\.gz'\'' | head -1'
aREGEX[$software_id]='file='\''[^'\'']*'\'
aREPLACE[$software_id]='file='\''$output'\'

# Go
software_id=188
aCHECK[$software_id]='curl -sSfL '\''https://go.dev/dl/?mode=json'\'' | grep -o "go[0-9.]*\.linux-$arch\.tar\.gz" | head -1'
aARCH[$software_id]='armv6l arm64 amd64 riscv64'
aARCH_CHECK[$software_id]='armv7l'
aREGEX[$software_id]='go[0-9.]*\.linux-\$arch\.tar\.gz'

# IPFS Node
software_id=186
aCHECK[$software_id]='curl -sSfL '\''https://dist.ipfs.io/go-ipfs/versions'\'' | sed '\''/-rc[0-9]*$/d'\'' | tail -1'
aREGEX[$software_id]='version='\''[^'\'']*'\'
aREPLACE[$software_id]='version='\''$output'\'

# microblog.pub: Update Python version?
software_id=16

# UrBackup Server
software_id=111
aCHECK[$software_id]='version=$(curl -sSfL '\''https://hndl.urbackup.org/Server/'\'' | grep -Po '\''(?<=href=")[0-9.]+(?=/")'\'' | sort -Vr | head -1); file=$(curl -sSfL "https://hndl.urbackup.org/Server/$version/" | grep -Pom1 "(?<=href=\")urbackup-server_${version}_$arch\.deb(?=\")"); echo "${file:+https://hndl.urbackup.org/Server/$version/$file}"'
aARCH[$software_id]='armhf arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://hndl.urbackup.org/Server/.*/urbackup-server_.*_$arch.deb'

# Airsonic-Advanced
software_id=33
aCHECK[$software_id]='curl -sSfL '\''https://api.github.com/repos/airsonic-advanced/airsonic-advanced/releases'\'' | mawk -F\" '\''/^ *"browser_download_url": ".*\/airsonic\.war"$/{print $4}'\'' | head -1'
aREGEX[$software_id]='https://github.com/airsonic-advanced/airsonic-advanced/releases/download/.*/airsonic.war'

# Navidrome
software_id=204
aCHECK[$software_id]='curl -sSfL '\''https://api.github.com/repos/navidrome/navidrome/releases/latest'\'' | mawk -F\" "/^ *\"browser_download_url\": \".*\/navidrome_[0-9.]*_linux_$arch\.tar\.gz\"$/{print \$4}"'
aARCH[$software_id]='armv6 armv7 arm64 amd64'
aARCH_CHECK[$software_id]='riscv64'
aREGEX[$software_id]='https://github.com/navidrome/navidrome/releases/download/.*/navidrome_.*_linux_$arch.tar.gz'

for i in "${!aCHECK[@]}"
do
	echo '------------------------------------------'
	echo "Checking software ID $i ..."
	# Loop through architectures if given
	if [[ ${aARCH[i]} ]]
	then
		for arch in ${aARCH[i]}
		do
			echo "Checking for architecture $arch ..."
			output=$(eval "${aCHECK[i]}")
			[[ $output ]] || Exit_Error "No release found for architecture $arch"
		done
		output=${output/$arch/\$arch}
	else
		output=$(eval "${aCHECK[i]}")
		[[ $output ]] || Exit_Error 'No release found'
	fi
	echo "Found release \"$output\""
	[[ ${aREPLACE[i]} ]] && eval "output=\"${aREPLACE[i]}\"" && echo "Replacing \"${aREGEX[i]}\" with \"$output\"" || :
	sed -i "/^\t\tif To_Install $i /,/^\t\tfi$/s|${aREGEX[i]}|$output|" dietpi/dietpi-software

	# Check for possibly newly supported architectures
	if [[ ${aARCH_CHECK[i]} ]]
	then
		for arch in ${aARCH_CHECK[i]}
		do
			echo "Checking for possibly newly supported architecture $arch ..."
			output=$(eval "${aCHECK[i]}") || :
			[[ $output ]] && Exit_Error "New architecture $arch is now supported" || :
		done
	fi
done

exit 0
}
