#!/bin/bash
{
	# Import DietPi-Globals ---------------------------------------------------------------
	. /boot/dietpi/func/dietpi-globals
	readonly G_PROGRAM_NAME='DietPi-WiFi_Monitor'
	G_CHECK_ROOT_USER "$@"
	G_INIT
	# Import DietPi-Globals ---------------------------------------------------------------

	readonly ADAPTER=$(G_GET_NET -t wlan iface)
	[[ $ADAPTER ]] || { G_DIETPI-NOTIFY 1 'No WiFi adapter has been found. Exiting...'; exit 1; }
	TICKRATE=$(sed -n '/^[[:blank:]]*CONFIG_WIFI_MONITOR_INTERVAL=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
	[[ $TICKRATE =~ ^([3-9]|[1-9][0-9]+)$ ]] || TICKRATE=10
	PING_COUNT=$(sed -n '/^[[:blank:]]*CONFIG_WIFI_MONITOR_PINGS=/{s/^[^=]*=//p;q}' /boot/dietpi.txt)
	[[ $PING_COUNT =~ ^([1-9]|10)$ ]] || PING_COUNT=3
	# Preload half of the pings (rounded up), the others follow in 1 second intervals. Ping exits as soon as all replies are received, and succeeds if any reply arrives.
	PRELOAD=$(( $PING_COUNT / 2 + 1 ))
	GATEWAY=

	#-------------------------------------------------------------------------------------
	# Main
	#-------------------------------------------------------------------------------------
	G_DIETPI-NOTIFY 2 "Checking connection for $ADAPTER via ping to default gateway every $TICKRATE seconds"

	while G_SLEEP "$TICKRATE"
	do
		if [[ ! -e /sys/class/net/$ADAPTER ]]
		then
			G_DIETPI-NOTIFY 1 "WiFi adapter $ADAPTER has been unplugged. Exiting..."
			exit 1

		elif ! GATEWAY=$(G_GET_NET -i "$ADAPTER" gateway) || ! ping -nqc "$PING_COUNT" -l "$PRELOAD" -I "$ADAPTER" "$GATEWAY" &> /dev/null
		then
			G_DIETPI-NOTIFY 2 "Detected $ADAPTER connection loss. Reconnecting..."
			ifdown "$ADAPTER"
			G_SLEEP 1
			ifup "$ADAPTER"
			G_DIETPI-NOTIFY 0 'Completed'
		fi
	done

	exit 0
}
