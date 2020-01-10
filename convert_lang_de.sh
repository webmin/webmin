#!/bin/bash
#
# dirty hack to convert de lang files to UTF
#
# (c) https://github.com/gnadelwartz, 2020
#
# usage: convert-lang-de.sh
#
# adjust MYLANG to your language
# set DOIT to yes to convert your language
#
MYLANG="de"
#DOIT="yes"

# ajust FROM if your lanugage is not iso-8859-1
FROM="ISO-8859-1"
TO="UTF-8"

# must be run in webmin or usermin dir
# simple safety check

if [ ! -f "acl_security.pl" ]; then
	echo "$0 MUST run in webmin or usermin directory!"
	exit 1
fi

####
# process all de files, change lang code for other lang
#
for file in *lang/"${MYLANG}" */*lang/"${MYLANG}" */help/*."${MYLANG}".html */config.info."${MYLANG}" */module.info."${MYLANG}"
do
	OUT="${file}.${TO}"
	# keep file extesion for html
	if [[ "${file}" == *".html" ]]; then
		OUT="${file%.html}.${TO}.html"
	fi
	# skip authentic, its already UTF-8
	if [ "${file%%/*}" == "authentic-theme" ]; then
		echo "skiping Authtentic Theme ..."
		continue 
	fi
	# skip symlinks
	[ -L "${file}" ] && echo "skip existing symlink ... ${file}" && continue # file is symlink
	[ -L "$(dirname "${file}")" ] && continue # dir is symlink
	[ -L "${file%%/*}" ] && continue # first part is symlink

	# skip and warn everthing not a regular file
	if [ ! -f "${file}" ]
	then
		echo "${file} is not a file, skipping"
		sleep 1
		continue
	fi
 
	# ',' is seperator in config.info, convert to '.' instead
	COMMA=','
	if [[ "$(basename "${file}")" == *"config.info"* ]]; then
		COMMA='.'

	fi
	# for german files do manual transcoding from &#xxx; encoding
	if [ "$MYLANG" == "de" ]; then
	    iconv -c --from-code=${FROM} --to-code=${TO} <"${file}" | \
	    sed -e 's/&#0/\&#/g' -e 's/&#214;/Ö/g' -e 's/&#196;/Ä/g' -e 's/&#220;/Ü/g' -e 's/&#228;/ä/g' -e 's/&#246;/ö/g' -e 's/&#252;/ü/g' -e 's/&#58/:/g' \
		-e 's/&#223;/ß/g' -e 's/&#167;/§/g' -e 's/&#45;*/-/g' -e 's/&#8722;/-/g' -e 's/&#8722;/-/g' -e 's/&#47;/\//g' -e 's/&#46/./g' -e 's/&#42;/*/' \
		-e 's/&#40/(/g' -e 's/&#41;/)/g' -e 's/&#44;*/'${COMMA}'/g' -e 's/&#62;/>/g' -e 's/&#60;/</g' -e 's/&#64;/@/g' -e 's/E-Mail/Mail/g' -e 's/&quot;*/"/g'\
		-e 's/&#63;/?/g' -e 's/&#64;/@/g' -e 's/&#64;/@/g' -e 's/&#187;/>>/g' -e 's/&#171;/>>/g' -e 's/&szlig;/ß/g' -e 's/&szlig/ß/g' \
		-e 's/&auml;/ä/g'  -e 's/&ouml;/ö/g' -e 's/&uu.l;/ü/g' -e 's/&Auml;/Ä/g' -e 's/&Ouml;/Ö/g' -e 's/&Uuml;/Ü/g' -e 's/&uu.l/ü/g' \
		-e 's/&ou.l/o/g' -e 's/&quot;/"/g'  -e 's/&amp;/\&/g' -e 's/&nbsp;/ /g' -e 's/&gt;/>/g' -e 's/&lt;/</g' -e 's/&#[0-9][0-9][0-9][0-9];//g' \
			>"${OUT}"

		# find &xxx; not converted encoded characters ...
		grep '&[^ ]*;' "${OUT}" 1>&2  && echo "${file}" 1>&2

	else
		# all other languages use iconv
		iconv -c --from-code=${FROM} --to-code=${TO} <"${file}" >"${OUT}"
	fi

	# keep backup if you test ?
	# cp ${file} ${file}.bak

	if [ "$DOIT" == "yes" ]; then
	# replace file with symlink
		rm "${file}"
		ln -s "$(basename "${OUT}")" "${file}"
		#file -i "${file}"
		# check if UTF-8
		file -i "${OUT}"
	else
		echo "dry run ... ${OUT}"
	fi
done
