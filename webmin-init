#!/bin/sh
# chkconfig: 235 99 10
# description: Start or stop the Webmin server
#
### BEGIN INIT INFO
# Provides: webmin
# Required-Start: $network $syslog
# Required-Stop: $network
# Default-Start: 2 3 5
# Default-Stop: 0 1 6
# Description: Start or stop the Webmin server
### END INIT INFO

start=/etc/webmin/start
stop=/etc/webmin/stop
lockfile=/var/lock/subsys/webmin
confFile=/etc/webmin/miniserv.conf
pidFile=/var/webmin/miniserv.pid
name='Webmin'

case "$1" in
'start')
	$start >/dev/null 2>&1 </dev/null
	RETVAL=$?
	if [ "$RETVAL" = "0" ]; then
		touch $lockfile >/dev/null 2>&1
	fi
	;;
'stop')
	$stop
	RETVAL=$?
	if [ "$RETVAL" = "0" ]; then
		rm -f $lockfile
	fi
	pidfile=`grep "^pidfile=" $confFile | sed -e 's/pidfile=//g'`
	if [ "$pidfile" = "" ]; then
		pidfile=$pidFile
	fi
	rm -f $pidfile
	;;
'status')
	pidfile=`grep "^pidfile=" $confFile | sed -e 's/pidfile=//g'`
	if [ "$pidfile" = "" ]; then
		pidfile=$pidFile
	fi
	if [ -s $pidfile ]; then
		pid=`cat $pidfile`
		kill -0 $pid >/dev/null 2>&1
		if [ "$?" = "0" ]; then
			echo "$name (pid $pid) is running"
			RETVAL=0
		else
			echo "$name is stopped"
			RETVAL=1
		fi
	else
		echo "$name is stopped"
		RETVAL=1
	fi
	;;
'restart')
	$stop ; $start
	RETVAL=$?
	;;
*)
	echo "Usage: $0 { start | stop | restart }"
	RETVAL=1
	;;
esac
exit $RETVAL

