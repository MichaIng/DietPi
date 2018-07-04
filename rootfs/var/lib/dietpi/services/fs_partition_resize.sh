#!/bin/bash

systemctl disable dietpi-fs_partition_resize

sync

TARGET_PARTITION=0
TARGET_DEV=$(findmnt / -o source -n)

# - MMCBLK[0-9]p[0-9] scrape
if [[ $TARGET_DEV =~ mmcblk ]]; then

	TARGET_PARTITION=${TARGET_DEV##*p}
	TARGET_DEV=${TARGET_DEV%p[0-9]}

# - Everything else scrape (eg: /dev/sdX[0-9])
else

	TARGET_PARTITION=${TARGET_DEV##*/sd}
	TARGET_DEV=${TARGET_DEV%[0-9]}

fi

#Rock64 GPT resize | modified version of ayufan-rock64 resize script. I take no credit for this.
if [[ -f /etc/.dietpi_hw_model_identifier ]] && (( $(</etc/.dietpi_hw_model_identifier) == 43 )); then

	gdisk $TARGET_DEV << _EOF_
x
e
m
d
$TARGET_PARTITION
n
$TARGET_PARTITION


8300
c
$TARGET_PARTITION
root
w
Y
_EOF_

#Everything else
else

	cat << _EOF_ | fdisk $TARGET_DEV
p
d
$TARGET_PARTITION
n
p
$TARGET_PARTITION
$(parted $TARGET_DEV -ms unit s p | grep ':ext4::;' | sed 's/:/ /g' | sed 's/s//g' | awk '{ print $2 }')

p
w

_EOF_

fi

partprobe $TARGET_DEV

resize2fs ${TARGET_DEV}p$TARGET_PARTITION
