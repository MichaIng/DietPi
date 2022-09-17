{
. /boot/dietpi/func/dietpi-globals || exit 1

G_EXEC mkdir -p raspberrypi-sys-mods/{DEBIAN,lib/udev/rules.d,usr/{lib,share/doc}/raspberrypi-sys-mods}

cat << '_EOF_' > raspberrypi-sys-mods/usr/share/doc/raspberrypi-sys-mods/copyright
Format: http://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: raspberrypi-sys-mods
Source: https://github.com/RPi-Distro/raspberrypi-sys-mods

Files: *
Copyright: 2015 Raspberry Pi Foundation
License: BSD-3-Clause

License: BSD-3-Clause
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. Neither the name of the University nor the names of its contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.
 .
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
 A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE HOLDERS OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
 PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
_EOF_

cat << '_EOF_' > raspberrypi-sys-mods/usr/lib/raspberrypi-sys-mods/i2cprobe
#!/bin/dash
ALIASES="/lib/modules/$(uname -r)/modules.alias"
n=0
while :; do
    eval "comp=\"\$OF_COMPATIBLE_$n\""
    comp=$(echo "$comp" | sed 's/.*,//')
    if [ -z "$comp" ]; then
        break
    fi
    if grep -q "alias $SUBSYSTEM:$comp " $ALIASES; then
        modprobe "$SUBSYSTEM:$comp" && exit 0
    fi
    let n="$n + 1"
done
modprobe "$MODALIAS" || modprobe "of:N${OF_NAME}T<NULL>C$OF_COMPATIBLE_0"
_EOF_
G_EXEC chmod +x raspberrypi-sys-mods/usr/lib/raspberrypi-sys-mods/i2cprobe

cat << '_EOF_' > raspberrypi-sys-mods/lib/udev/rules.d/15-i2c-modprobe.rules
SUBSYSTEM=="i2c|spi", ENV{MODALIAS}=="?*", ENV{OF_NAME}=="?*", ENV{OF_COMPATIBLE_0}=="?*", RUN+="/usr/lib/raspberrypi-sys-mods/i2cprobe"
_EOF_

cat << '_EOF_' > raspberrypi-sys-mods/lib/udev/rules.d/99-com.rules
SUBSYSTEM=="input", GROUP="input", MODE="0660"
SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"
SUBSYSTEM=="bcm2835-gpiomem", GROUP="gpio", MODE="0660"
SUBSYSTEM=="rpivid-*", GROUP="video", MODE="0660"

KERNEL=="vcsm-cma", GROUP="video", MODE="0660"
SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"

SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="/bin/sh -c 'chgrp -R gpio /sys/class/gpio && chmod -R g=u /sys/class/gpio'"
SUBSYSTEM=="gpio", ACTION=="add", PROGRAM="/bin/sh -c 'chgrp -R gpio /sys%p && chmod -R g=u /sys%p'"

# PWM export results in a "change" action on the pwmchip device (not "add" of a new device), so match actions other than "remove".
SUBSYSTEM=="pwm", ACTION!="remove", PROGRAM="/bin/sh -c 'chgrp -R gpio /sys%p && chmod -R g=u /sys%p'"

KERNEL=="ttyAMA0", PROGRAM="/bin/sh -c '\
	ALIASES=/proc/device-tree/aliases; \
	if cmp -s $$ALIASES/uart0 $$ALIASES/serial0; then \
		echo 0;\
	elif cmp -s $$ALIASES/uart0 $$ALIASES/serial1; then \
		echo 1; \
	else \
		exit 1; \
	fi\
'", SYMLINK+="serial%c"

KERNEL=="ttyAMA1", PROGRAM="/bin/sh -c '\
	ALIASES=/proc/device-tree/aliases; \
	if [ -e /dev/ttyAMA0 ]; then \
		exit 1; \
	elif cmp -s $$ALIASES/uart0 $$ALIASES/serial0; then \
		echo 0;\
	elif cmp -s $$ALIASES/uart0 $$ALIASES/serial1; then \
		echo 1; \
	else \
		exit 1; \
	fi\
'", SYMLINK+="serial%c"

KERNEL=="ttyS0", PROGRAM="/bin/sh -c '\
	ALIASES=/proc/device-tree/aliases; \
	if cmp -s $$ALIASES/uart1 $$ALIASES/serial0; then \
		echo 0; \
	elif cmp -s $$ALIASES/uart1 $$ALIASES/serial1; then \
		echo 1; \
	else \
		exit 1; \
	fi \
'", SYMLINK+="serial%c"

ACTION=="add", SUBSYSTEM=="vtconsole", KERNEL=="vtcon1", RUN+="/bin/sh -c '\
	if echo RPi-Sense FB | cmp -s /sys/class/graphics/fb0/name; then \
		echo 0 > /sys$devpath/bind; \
	fi; \
'"
_EOF_

cat << '_EOF_' > raspberrypi-sys-mods/DEBIAN/preinst
#!/bin/dash
groupadd -rf spi
groupadd -rf i2c
groupadd -rf gpio
_EOF_
G_EXEC chmod +x raspberrypi-sys-mods/DEBIAN/preinst

find raspberrypi-sys-mods ! \( -path raspberrypi-sys-mods/DEBIAN -prune \) -type f -exec md5sum {} + | sed 's|raspberrypi-sys-mods/||' > raspberrypi-sys-mods/DEBIAN/md5sums

cat << _EOF_ > raspberrypi-sys-mods/DEBIAN/control
Package: raspberrypi-sys-mods
Version: 2:20220915-dietpi1
Architecture: all
Maintainer: MichaIng <micha@dietpi.com>
Date: $(date -u '+%a, %d %b %Y %T %z')
Standards-Version: 4.6.1.0
Installed-Size: $(du -sk raspberrypi-sys-mods | mawk '{print $1}')
Section: admin
Priority: optional
Homepage: https://github.com/RPi-Distro/raspberrypi-sys-mods
Vcs-Git: https://github.com/RPi-Distro/raspberrypi-sys-mods.git
Vcs-Browser: https://github.com/RPi-Distro/raspberrypi-sys-mods
Description: System tweaks for the Raspberry Pi, DietPi edition
_EOF_
G_CONFIG_INJECT 'Installed-Size: ' "Installed-Size: $(du -sk raspberrypi-sys-mods | mawk '{print $1}')" raspberrypi-sys-mods/DEBIAN/control

# Build DEB package
G_EXEC rm -Rf raspberrypi-sys-mods.deb
G_EXEC_OUTPUT=1 G_EXEC dpkg-deb -b raspberrypi-sys-mods
G_EXEC rm -Rf raspberrypi-sys-mods
}