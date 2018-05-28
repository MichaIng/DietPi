#!/bin/bash

#Workaround for setting locale to session when POSIX is detected (eg: dropbear): https://github.com/Fourdee/DietPi/issues/1540#issuecomment-367066178
if locale | grep -qi 'POSIX'; then

	CURRENT_LOCALE="$(grep -m1 '^[[:blank:]]*AUTO_SETUP_LOCALE=' /DietPi/dietpi.txt | sed 's/^.*=//')"
	export LANG="$CURRENT_LOCALE"
	export LC_ALL="$CURRENT_LOCALE"

fi
