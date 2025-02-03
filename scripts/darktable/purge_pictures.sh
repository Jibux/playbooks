#!/bin/bash


usage()
{
	echo "Usage $0 <file type to purge> (raw or jpg)"
}

#for file in $(ls *RW2); do
#	root_file="${file##*/}"
#	jpg_file="${root_file%%.*}.JPG"
#	if [ -f "$jpg_file" ]; then
#		echo "$jpg_file present"
#	else
#		echo "Will suppress $file"
#		rm -f $file $file.xmp
#	fi
#done

#for file in $(ls *xmp); do
#	root_file="${file##*/}"
#	image_file="${root_file%.*}"
#	if [ -f "$image_file" ]; then
#		echo "$image_file present"
#	else
#		echo "Will suppress $file"
#		#rm -f $file
#	fi
#done


check_picture()
{
	shopt -s nocasematch

	local file="$1"
	local file_type="${file##*.}"
	local file_type_to_search="JPG"

	[ "$file_type" == "JPG" ] && file_type_to_search="RW2"
	local file_to_search="${file%.*}.$file_type_to_search"
	local file_to_search2="${file%.*}.${file_type_to_search,,}"

	if [[ -f "$file_to_search" || -f "$file_to_search2" ]]; then
		echo "$file_to_search present"
	else
		echo "Will suppress $file"
		rm -f "$file" "$file.xmp"
	fi

}

export -f check_picture


[ "$#" -ne 1 ] && usage && exit 1

file_type_to_purge=$1

if [ "$file_type_to_purge" == "raw" ]; then
	search_for="RW2"
elif [ "$file_type_to_purge" == "jpg" ]; then
	search_for="JPG"
else
	usage
	exit 1
fi

echo "Will suppress $file_type_to_purge are you sure? (y/N)"
read -r -n 1 response
[ "$response" != "y" ] && echo "Abort" && exit 0
echo -e "\\n"

find . -type f -iname '*'$search_for -exec bash -c 'check_picture "$0"' {} \;

