#!/bin/bash

# Workaround for SSH client passing an unsupported $TERM string: https://github.com/MichaIng/DietPi/issues/2034
if [[ $SSH_TTY ]] && ! toe -a | grep -q "^$TERM[[:blank:]]"; then

	TERM_old="$TERM"
	ncurses_term=''

	if [[ $TERM =~ 256 ]]; then

		export TERM='xterm-256color'

	else

		export TERM='xterm'

	fi

	G_WHIP_MENU_ARRAY=('0' 'Ignore for now, I will change the SSH clients terminal.')

	if ! dpkg-query -s ncurses-term &> /dev/null; then

		ncurses_term=' or install the "ncurses-term" APT packages, which enables a wider terminal support'
		G_WHIP_MENU_ARRAY+=('1' 'Install "ncurses-term" now to enable a wider terminal support.')
		G_WHIP_DEFAULT_ITEM=1

	fi

	G_PROGRAM_NAME='Unsupported SSH client terminal' G_WHIP_MENU "[WARNING] Your SSH client passed an unsupported terminal: TERM=$TERM_old\n
As a workaround we fooled the server by setting: TERM=$TERM. This is not the cleanest solution, since commands might expect colours or formats, that are not supported by the actual terminal.\n
Please change your SSH clients terminal, respectively the passed \$TERM string$ncurses_term." && (( $G_WHIP_RETURNED_VALUE )) && G_AGI ncurses-term

	unset TERM_old
	unset ncurses_term

fi
