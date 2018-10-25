#!/bin/bash
{

	#Import DietPi-Globals ---------------------------------------------------------------
	. /DietPi/dietpi/func/dietpi-globals
	G_CHECK_ROOT_USER
	G_CHECK_ROOTFS_RW
	G_PROGRAM_NAME='DietPi-WiFi-Monitor'
	G_INIT
	#Import DietPi-Globals ---------------------------------------------------------------

	URL_PING=''
	ADAPTER="wlan$(sed -n 2p /DietPi/dietpi/.network)"
	TICKRATE=10

	#-------------------------------------------------------------------------------------
	#Main
	#-------------------------------------------------------------------------------------
	while true
	do

		# - Get current gateway for ping
		URL_PING="$(ip route show 0.0.0.0/0 dev $ADAPTER | awk '{print $3}')"

		echo -e "Checking connnection for: $ADAPTER via ping to $URL_PING"
		ping -I $ADAPTER -c 1 $URL_PING
		if (( $? != 0 )); then

			echo -e  "Detected connection loss: $ADAPTER. Reconnecting"
			ifdown "$ADAPTER"
			sleep 1
			ifup "$ADAPTER"
			echo 'Completed'

		else

			echo -e "Connection valid for: $ADAPTER"

		fi

		sleep $TICKRATE

	done

	exit 0

}
