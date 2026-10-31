#!/bin/bash
{
	# Import DietPi-Globals ---------------------------------------------------------------
	. /boot/dietpi/func/dietpi-globals
	readonly G_PROGRAM_NAME='dietpi-wifi-monitor'
	G_CHECK_ROOT_USER "$@"
	G_INIT
	# Import DietPi-Globals ---------------------------------------------------------------

	readonly ADAPTER=$(G_GET_NET -t wlan iface)
	[[ $ADAPTER ]] || { G_DIETPI-NOTIFY 1 'No WiFi adapter has been found. Exiting ...'; exit 1; }
	if [[ ! $TICKRATE =~ ^([3-9]|[1-9][0-9]+)$ ]]
	then
		TICKRATE=$(sed -n '/^[[:blank:]]*CONFIG_WIFI_MONITOR_INTERVAL=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		[[ $TICKRATE =~ ^([3-9]|[1-9][0-9]+)$ ]] || TICKRATE=10
	fi
	if [[ ! $PINGS =~ ^([1-9]|10)$ ]]
	then
		PINGS=$(sed -n '/^[[:blank:]]*CONFIG_WIFI_MONITOR_PINGS=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
		[[ $PINGS =~ ^([1-9]|10)$ ]] || PINGS=3
	fi
	# Use half of the pings (rounded up), since we send `n*2-1` pings, using `ping -c n -l n`.
	# This sends `n` pings right at the start, and finishes immediately if they get all answered.
	# The next `n-1` pings are send with a second delay each, to still return successfully if there was an outage only during the first fraction of a second.
	# Timeouts etc however are counted from the first `n` packets on, so that the overall time until interface restart is not longer compared to a simple `-c 1`.
	PINGS=$(( $PINGS / 2 + 1 ))
	GATEWAY=

	#-------------------------------------------------------------------------------------
	# Main
	#-------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 "Checking connection for $ADAPTER with $PINGS pings to default gateway every $TICKRATE seconds"

	while G_SLEEP "$TICKRATE"
	do
		if [[ ! -e /sys/class/net/$ADAPTER ]]
		then
			G_DIETPI-NOTIFY 1 "WiFi adapter $ADAPTER has been unplugged. Exiting ..."
			exit 1

		elif ! GATEWAY=$(G_GET_NET -i "$ADAPTER" gateway) || ! ping -nqc "$PINGS" -l "$PINGS" -I "$ADAPTER" "$GATEWAY" &> /dev/null
		then
			G_DIETPI-NOTIFY 2 "Detected $ADAPTER connection loss. Reconnecting ..."
			ifdown "$ADAPTER"
			G_SLEEP 0.5
			ifup "$ADAPTER"
			G_DIETPI-NOTIFY 0 'Completed'
		fi
	done

	exit 0
}
