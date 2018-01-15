#!/bin/bash

# move descriptions out of module,info
FILES=apache/module.info
[ "$1" != "" ] && FILES="$*"

for file in $FILES
do
	echo "processing $file ..."
	# get dir
	dir=`dirname $file`
	[ ! -d "$dir/lang" ] && echo "skipping $dir: no lang dir" && continue
	# move to temp file
	sed '/desc_.*=/d' $file >$file.tmp
	grep -a -e '^desc' -e '^longdesc' $file | sort >$file.desc
	mv $file.tmp $file

	# move desc to lang files
	for line in `ls $dir/lang`
	do
		lang="_$line"
		[ "$lang" = "_en" ] && lang=""
		sed -n  "s/^desc$lang=/desc=/p" $file.desc >$dir/lang/$line.tmp
		sed -n  "s/^longdesc$lang=/longdesc=/p" $file.desc >>$dir/lang/$line.tmp
		[ ! -s "$dir/lang/$line.tmp" ] && sed -n  "/^desc=/p" $file.desc >$dir/lang/$line.tmp
		grep -q "^longdesc" "$dir/lang/$line.tmp" || sed -n  "/^longdesc=/p" $file.desc >>$dir/lang/$line.tmp
		cat $dir/lang/$line >>$dir/lang/$line.tmp
		mv $dir/lang/$line.tmp $dir/lang/$line
	done
done
echo "cleanup ..."
rm -f */module.info.desc */*.tmp */*/*.tmp
