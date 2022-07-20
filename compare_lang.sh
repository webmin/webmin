#!/bin/bash
#
# compare_lang.sh
# quick and dirty script to find missing lang strings in webmin lang files
#
# (c) https://github.com/gnadelwartz, 2020
#
# DISPLAY missing strings from one langfile:
#
# ./compare_lang.sh module/lang/xx 
#
# UPDATE one langfile of a module with missing strings:
#
# ./compare_lang.sh module/lang/xx >>module/lang/xx
#
# UPDATE one langfile in ALL modules with missing strings:
#
# for FILE in webmin/*/lang/xx; do
#	./compare_lang.sh $FILE >>$FILE
# done



# $1 = lang file to check for missing strings against en

ENGLISH="$(dirname "$1")/en"

if [ "$1" == "" -o ! -f "$1" ]
then
	echo "file does not exist or no file given ..."
	echo "usage: $0 file"
	exit 1
fi

while read message
do
	# skip empty lines
	[ "$message" == "" ] && continue
	# skip comments, __noref and log_* messages
	if [[ "$message" == "#"* ]] || [[ "$message" == "__norefs"* ]] || [[ "$message" == "log_"* ]]; then
		echo "skip $message" 1>&2
		continue
	fi
	# output missing lines
	key="${message%%=*}"; [ "$key" == "$message" ] && continue
	grep -e "^${key}=" "$1" >/dev/null || echo "${message}"
done < "${ENGLISH}"
