#!/bin/bash


set -o errexit -o nounset

fail()
{
	echo "$1"
	exit 1
}

usage()
{
	echo "$0 path_to_pictures"
}

remove_empty_dir()
{
	local dirname=$1

	if [ -z "$(ls -A "$dirname")" ]; then
		echo "rmdir '$dirname'"
		rmdir "$dirname"
	fi
}

ROOT_RAW="/data/Photos-Images/Darktable"
ROOT_JPG="/data/Photos-Images/Famille"

RAW_EXT="RW2"
JPG_EXT="JPG"
MOV_EXT="MP4"

[ "$#" != "1" ] && usage && exit 1


DIR_PATH=$1

[ ! -d "$DIR_PATH" ] && fail "'$DIR_PATH' is not a directory or does not exist"

DIR_NAME=$(basename "$DIR_PATH")
YEAR=${DIR_NAME:0:4}
PATH_RAW="$ROOT_RAW/$YEAR/$DIR_NAME"
PATH_JPG="$ROOT_JPG/$YEAR/$DIR_NAME"

echo "mkdir '$PATH_RAW'"
[ ! -d "$PATH_RAW" ] && mkdir -p "$PATH_RAW"
echo "mkdir '$PATH_JPG'"
[ ! -d "$PATH_JPG" ] && mkdir -p "$PATH_JPG"

echo "mv *$RAW_EXT"
find "$DIR_PATH" -maxdepth 1 -type f -iname "*$RAW_EXT" -exec mv '{}' "$PATH_RAW" \;
echo "mv *$JPG_EXT"
find "$DIR_PATH" -maxdepth 1 -type f -iname "*$JPG_EXT" -exec mv '{}' "$PATH_JPG" \;
echo "mv *$MOV_EXT"
find "$DIR_PATH" -maxdepth 1 -type f -iname "*$MOV_EXT" -exec mv '{}' "$PATH_JPG" \;

remove_empty_dir "$DIR_PATH"
remove_empty_dir "$PATH_RAW"
remove_empty_dir "$PATH_JPG"

