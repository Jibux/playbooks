#!/bin/bash


set -o errexit -o nounset -o errtrace -o pipefail

# Find non PXXX and non YYYmmDD_HHMMss formated:
# find . -regextype sed -type f -not -iregex ".*/.*[1-2][09][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9].*\.\(jpg\|mp4\)" -not -iregex ".*/P[0-9]\{7\}\.\(jpg\|mp4\)"
# Find non formated
# find . -regextype sed -type f -not -iregex ".*/[1-2][09][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9].*\.\(jpg\|mp4\)"

usage()
{
	echo "Usage $0 --ext=<file extension to process> [--fix] SEARCH_PATH"
	echo
	echo "Extension: xmp, rw2, jpg, jpeg, png, tif, mov, mp4, etc."
	echo "'--fix' is optional it will try to fix exif -DateTimeOriginal and -CreateDate tags"
}

verbose()
{
	[ "$VERBOSE" == "yes" ]
}

debug()
{
	verbose && echo "$1"
	return 0
}

find_date()
{
	local found_date

	found_date=$(exiftool -DateTimeOriginal "$1" | awk '{print $(NF-1),$NF}')
	if [ -n "$found_date" ]; then
		echo "$found_date"
	else
		found_date=$(exiftool -CreateDate "$1" | awk '{print $(NF-1),$NF}')
		if [ -n "$found_date" ]; then
			echo "$found_date"
		fi
	fi
}

# Find xmp related rw2 file and copy its tags (if needed) to the xmp file
fix_xmp_tag()
{
	local xmp_file=$1
	local xmp_date
	local rw2_file
	local rw2_date

	xmp_date="$(find_date "$xmp_file")"
	if [ -n "$xmp_date" ] ; then
		echo "'$xmp_file' already has a date ($xmp_date)"
	else
		rw2_file=${xmp_file%.*}
		rw2_date="$(find_date "$rw2_file")"
		debug "Will write date $rw2_date to '$xmp_file' exif tags"
		exiftool "${EXIFTOOL_OPTS[@]}" -P -DateTimeOriginal="$rw2_date" -CreateDate="$rw2_date" -overwrite_original_in_place "$xmp_file"
	fi
}

# If date in file tags does not match the file name, will ask to fix the tags to match the file name
fix_file_tag()
{
	local file_path=$1
	local found_date
	local formated_date
	local regex
	local resp

	found_date=$(find_date "$file_path")
	#2019:12:10 15:00:06
	formated_date=${found_date//:/}
	formated_date=${formated_date// /_}
	#20191210_15
	formated_date=${formated_date:0:11}
	regex=".*$formated_date"'[0-9]{4}.*\.'"$EXT$"
	if [[ -n "$found_date" && "$file_path" =~ $regex$ ]]; then
		debug "File name '$file_path' matches with found date ($found_date)"
	else
		echo "File name '$file_path' does not match with found date ($found_date)"
		read -r -n 1 -p 'Fix tags in this file? (y/N) ' resp
		echo
		if [[ "$resp" =~ [yY] ]]; then
			echo "Fixing '$file_path'"
			exiftool "${EXIFTOOL_OPTS[@]}" -P -r -d "$PATTERN" -ext "$EXT" "-CreateDate<filename" "-DateTimeOriginal<filename" -overwrite_original_in_place "$file_path"
		fi
	fi

	return 0
}

fix()
{
	local line

	echo "Fixing '$EXT' files"

	if [ "$EXT" == "xmp" ]; then
		while read -r -u 3 line; do
			fix_xmp_tag "$line"
		done 3< <(find "$SEARCH_PATH" -type f -iname '*xmp')
	else
		while read -r -u 3 line; do
			fix_file_tag "$line"
		done 3< <(find "$SEARCH_PATH" -type f -iname "*[1-2][09][0-9][0-9][01][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]*.$EXT")
	fi
}


TAG="DateTimeOriginal"
FIX="no"
EXT=""
VERBOSE="no"
EXIFTOOL_OPTS=()

for i in "$@"; do
	case $i in
		--ext=*)
			EXT="${i#*=}"
			EXT="${EXT,,}"
			shift
			;;
		--fix)
			FIX="yes"
			shift
			;;
		--verbose)
			VERBOSE="yes"
			shift
			;;
		-*)
			usage
			exit 1
			;;
	esac
done

[ -z "$EXT" ] && usage && exit 1
[ "$#" -ne 1 ] && usage && exit 1

SEARCH_PATH="$1"

PATTERN="%Y%m%d_%H%M%S%%-c.$EXT"

verbose && EXIFTOOL_OPTS=("-v")

shopt -s nocasematch

if [ "$EXT" == "xmp" ]; then
	PATTERN="%Y%m%d_%H%M%S%%-c.rw2.$EXT"
elif [[ "$EXT" =~ mp4|mov|mpg|mpeg ]]; then
	TAG="CreateDate"
fi

if [ "$FIX" == "yes" ]; then
	fix
else
	exiftool "${EXIFTOOL_OPTS[@]}" -P "-filename<$TAG" -ext "$EXT" -d "$PATTERN" -r -overwrite_original_in_place "$SEARCH_PATH"
fi

