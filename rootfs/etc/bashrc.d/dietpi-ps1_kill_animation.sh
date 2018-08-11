#!/bin/bash

# "G_DIETPI-NOFITY -2 message" starts a process animation.
# If scripts fail to kill the animation, e.g. cancelled by user, terminal bash prompt has to do it as last resort:
PROMPT_COMMAND="[[ -w /tmp/dietpi-process.pid ]] && rm /tmp/dietpi-process.pid && tput cub 9 && tput ed; $PROMPT_COMMAND"
