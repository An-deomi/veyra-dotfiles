#!/bin/sh
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DIR="$CONFIG_HOME/quickshell/emoji"
pkill -f -- "-p $DIR\$" && exit 0
exec qs -p "$DIR"
