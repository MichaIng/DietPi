#!/bin/bash

# Workaround, if SSH client overrides locale with "POSIX" fallback: https://github.com/MichaIng/DietPi/issues/1540#issuecomment-367066178
if [[ $(locale) =~ 'POSIX' ]]; then

	CURRENT_LOCALE="$(grep -m1 '^[[:blank:]]*AUTO_SETUP_LOCALE=' /DietPi/dietpi.txt | sed 's/^[^=]*=//')"
	export LANG="${CURRENT_LOCALE:=en_GB.UTF-8}"
	export LC_ALL="$CURRENT_LOCALE"
	unset CURRENT_LOCALE

fi
