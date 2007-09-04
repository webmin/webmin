#!/bin/sh

if [ "$1" = "" -o "$2" = "" ]; then
	echo "usage: createvirtualminmodule.sh <version> <file>"
	exit 1
fi
echo $1 | grep gpl >/dev/null
if [ "$?" != "0" ]; then
	echo Version is missing .gpl suffix
	exit 2
fi
cd /usr/local/webadmin
/usr/local/webadmin/create-module.pl --dir virtual-server $2 gpl-virtual-server/$1
/usr/local/webadmin/showchangelog.pl --html latest gpl-virtual-server >/home/jcameron/webmin.com/vchanges-$1.html
echo "<a href=vchanges-$1.html>Change log for latest $1 development version of Virtualmin.</a>" >/home/jcameron/webmin.com/vchangelog-latest.html
echo "<a href=download/virtualmin/virtual-server-$1.wbm.gz>The $1 development version of Virtualmin.</a>" >/home/jcameron/webmin.com/vdevel-latest.html
