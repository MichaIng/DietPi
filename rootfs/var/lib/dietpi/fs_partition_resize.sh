#!/bin/bash

systemctl disable dietpi-fs_partition_resize

sync

TARGET_PARTITION=0
TARGET_DEV=$(findmnt / -o source -n)

# - MMCBLK[0-9]p[0-9] scrape
if [[ "$TARGET_DEV" = *"mmcblk"* ]]; then

	TARGET_DEV=$(findmnt / -o source -n | sed 's/p[0-9]$//')
	TARGET_PARTITION=$(findmnt / -o source -n | sed 's/^.*p//')

# - Everything else scrape (eg: /dev/sdX[0-9])
else

	TARGET_DEV=$(findmnt / -o source -n | sed 's/[0-9]$//')
	TARGET_PARTITION=$(findmnt / -o source -n | sed 's|/dev/sd.||')

fi

#Rock64 GPT resize | modified version of ayufan-rock64 resize script. I take no credit for this.
if [[ -f /etc/.dietpi_hw_model_identifier ]] && (( $(cat /etc/.dietpi_hw_model_identifier) == 43 )); then

    gdisk $TARGET_DEV << _EOF_1
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
_EOF_1

#Everything else
else

    cat << _EOF_1 | fdisk $TARGET_DEV
p
d
$TARGET_PARTITION
n
p
$TARGET_PARTITION
$(parted $TARGET_DEV -ms unit s p | grep ':ext4::;' | sed 's/:/ /g' | sed 's/s//g' | awk '{ print $2 }')

p
w

_EOF_1

fi

partprobe $TARGET_DEV

resize2fs ${TARGET_DEV}p$TARGET_PARTITION
