#!/bin/bash


set -euo errexit


exit_fail()
{
	echo "${1:-Something wrong happened}" >&2
	exit 1
}

usage()
{
	echo "Usage: $0 directory [group_mode]"
	echo "group_mode: ro or rw"
}


[ "$#" -lt "1" ] && usage && exit 1


DIR="$1"
GROUP_MODE="${2:-ro}"
GROUP_WRITE_MODE=""

[ -d "$DIR" ] || exit_fail "'$DIR' is not a directory"

[ "$GROUP_MODE" == "rw" ] && GROUP_WRITE_MODE="w"


sudo chgrp -R parents "$DIR"
sudo chmod -R o=,u=rwX,"g=rX$GROUP_WRITE_MODE" "$DIR"
sudo find "$DIR" -type d -exec chmod g+s {} \; -exec setfacl -m d:g::rx$GROUP_WRITE_MODE {} \;

