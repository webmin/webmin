#!/bin/sh
# setup.sh
# This script should be run after the webmin archive is unpacked, in order
# to setup the various config files

# Find install directory
LANG=
export LANG
LANGUAGE=
export LANGUAGE

if [ "$bootscript" = "" ]; then
	bootscript="webmin"
fi

cd `dirname $0`
if [ -x /bin/pwd ]; then
	wadir=`/bin/pwd`
else
	wadir=`pwd`;
fi
srcdir=$wadir
ver=`cat "$wadir/version"`

if [ $? != "0" ]; then
	echo "ERROR: Cannot find the Webmin install directory";
	echo "";
	exit 1;
fi

# Find temp directory
if [ "$tempdir" = "" ]; then
	tempdir=/tmp/.webmin
fi

echo "****************************************************************************"
echo "           Welcome to the Webmin setup script, version $ver"
echo "****************************************************************************"
echo "Webmin is a web-based interface that allows Unix-like operating"
echo "systems and common Unix services to be easily administered."
echo ""

# Only root can run this
id | grep -i "uid=0(" >/dev/null
if [ $? != "0" ]; then
	uname -a | grep -i CYGWIN >/dev/null
	if [ $? != "0" ]; then
		echo "ERROR: The Webmin install script must be run as root";
		echo "";
		exit 1;
	fi
fi

# Use the supplied destination directory, if any
if [ "$1" != "" ]; then
	wadir=$1
	echo "Installing Webmin from $srcdir to $wadir"
	if [ ! -d "$wadir" ]; then
		mkdir "$wadir"
		if [ "$?" != "0" ]; then
			echo "ERROR: Failed to create $wadir"
			echo ""
			exit 1
		fi
	else
		# Make sure dest dir is not in use
		ls "$wadir" | grep -v rpmsave >/dev/null 2>&1
		if [ "$?" = "0" -a ! -r "$wadir/setup.sh" ]; then
			echo "ERROR: Installation directory $wadir contains other files"
			echo ""
			exit 1
		fi
	fi
else
	echo "Installing Webmin in $wadir"
fi
cd "$wadir"

# Work out perl library path
PERLLIB=$wadir
WEBMIN_LIBDIR=$wadir
if [ "$perllib" != "" ]; then
	PERLLIB="$PERLLIB:$perllib"
fi
export PERLLIB
export WEBMIN_LIBDIR

# Validate source directory
allmods=`cd "$srcdir"; echo */module.info | sed -e 's/\/module.info//g'`
if [ "$allmods" = "" ]; then
	echo "ERROR: Failed to get module list"
	echo ""
	exit 1
fi
echo ""

# Load package-defined variable overrides
if [ -r "$srcdir/setup-pre.sh" ]; then
	. "$srcdir/setup-pre.sh"
fi

# Work out the hostname
host=`hostname 2>/dev/null`
if [ "$host" = "" ]; then
	host=`uname -n 2>/dev/null`
fi

# Ask for webmin config directory
echo "****************************************************************************"
echo "Webmin uses separate directories for configuration files and log files."
echo "Unless you want to run multiple versions of Webmin at the same time"
echo "you can just accept the defaults."
echo ""
envetcdir="$config_dir"
if [ "$envetcdir" = "" ]; then
	envetcdir=/etc/webmin
	envetcdirnotfound=1
fi
printf "Config file directory [$envetcdir]: "
if [ "$config_dir" = "" ]; then
	read config_dir
fi
if [ "$config_dir" = "" ]; then
	config_dir=/etc/webmin
fi
abspath=`echo $config_dir | grep "^/"`
if [ "$abspath" = "" ]; then
	echo "Config directory must be an absolute path"
	echo ""
	exit 2
fi
if [ ! -d $config_dir ]; then
	mkdir -p $config_dir;
	if [ $? != 0 ]; then
		echo "ERROR: Failed to create directory $config_dir"
		echo ""
		exit 2
	fi
fi
if [ -r "$config_dir/config" -a -r "$config_dir/var-path" -a -r "$config_dir/perl-path" ]; then
	if [ "$envetcdirnotfound" = "" ]; then
		echo "$envetcdir"
		echo ".. predefined"
	else
		echo ".. found"
	fi
	upgrading=1
else
	if [ "$envetcdirnotfound" = "" ]; then
		echo "$envetcdir"
	fi
fi

# Check if upgrading from an old version
if [ "$upgrading" = 1 ]; then
	echo ""

	# Get current var path
	var_dir=`cat $config_dir/var-path`

	# Get current bootscript
	if [ -r "$config_dir/bootscript-name" ]; then
		newbootscript=`cat $config_dir/bootscript-name`
		if [ "$newbootscript" != "" ]; then
			bootscript="$newbootscript"
		fi
	fi

	# Force creation if non-existant
	mkdir -p $var_dir >/dev/null 2>&1

	# Get current perl path
	perl=`cat $config_dir/perl-path`

	# Create temp files directory
	$perl "$srcdir/maketemp.pl"
	if [ "$?" != "0" ]; then
		echo "ERROR: Failed to create or check temp files directory $tempdir"
		echo ""
		exit 2
	fi

	# Get old os name and version
	os_type=`grep "^os_type=" $config_dir/config | sed -e 's/os_type=//g'`
	os_version=`grep "^os_version=" $config_dir/config | sed -e 's/os_version=//g'`
	real_os_type=`grep "^real_os_type=" $config_dir/config | sed -e 's/real_os_type=//g'`
	real_os_version=`grep "^real_os_version=" $config_dir/config | sed -e 's/real_os_version=//g'`

	# Get old root, host, port, ssl and boot flag
	oldwadir=`grep "^root=" $config_dir/miniserv.conf | sed -e 's/root=//g'`
	port=`grep "^port=" $config_dir/miniserv.conf | sed -e 's/port=//g'`
	ssl=`grep "^ssl=" $config_dir/miniserv.conf | sed -e 's/ssl=//g'`
	atboot=`grep "^atboot=" $config_dir/miniserv.conf | sed -e 's/atboot=//g'`
	inetd=`grep "^inetd=" $config_dir/miniserv.conf | sed -e 's/inetd=//g'`

	# Copy files to target directory
	if [ "$wadir" != "$srcdir" ]; then
		echo "Copying files to $wadir .."
		(cd "$srcdir" ; tar cf - . | (cd "$wadir" ; tar xf -))
		echo ".. done"
		echo ""
	fi

	# Update ACLs
	$perl "$wadir/newmods.pl" $config_dir $allmods

	# Update miniserv.conf with new root directory and mime types file
	grep -v "^root=" $config_dir/miniserv.conf | grep -v "^mimetypes=" | grep -v "^server=" >$tempdir/$$.miniserv.conf
	if [ $? != "0" ]; then exit 1; fi
	mv $tempdir/$$.miniserv.conf $config_dir/miniserv.conf
	echo "root=$wadir" >> $config_dir/miniserv.conf
	echo "mimetypes=$wadir/mime.types" >> $config_dir/miniserv.conf
	echo "server=MiniServ/$ver" >> $config_dir/miniserv.conf
	grep logout= $config_dir/miniserv.conf >/dev/null
	if [ $? != "0" ]; then
		echo "logout=$config_dir/logout-flag" >> $config_dir/miniserv.conf
	fi
	
	# Check for third-party modules in old version
	if [ "$wadir" != "$oldwadir" ]; then
		echo "Checking for third-party modules .."
		if [ "$webmin_upgrade" != "" ]; then
			autothird=1
		fi
		$perl "$wadir/thirdparty.pl" "$wadir" "$oldwadir" $autothird
		echo ".. done"
		echo ""
	fi

	# Remove old cache of module infos
	rm -f $config_dir/module.infos.cache
else
	# Config directory exists .. make sure it is not in use
	ls $config_dir | grep -v rpmsave >/dev/null 2>&1
	if [ "$?" = "0" -a "$config_dir" != "/etc/webmin" ]; then
		echo "ERROR: Config directory $config_dir is not empty"
		echo ""
		exit 2
	fi

	# Ask for log directory
	envvardir="$var_dir"
	if [ "$envvardir" = "" ]; then
		envvardir=/var/webmin
		envvardirnotfound=1
	fi
	printf "Log file directory [$envvardir]: "
	if [ "$var_dir" = "" ]; then
		read var_dir
	fi
	if [ "$var_dir" = "" ]; then
		var_dir=/var/webmin
	fi
	abspath=`echo $var_dir | grep "^/"`
	if [ "$abspath" = "" ]; then
		echo "Log file directory must be an absolute path"
		echo ""
		exit 3
	fi
	if [ "$var_dir" = "/" ]; then
		echo "Log directory cannot be /"
		echo ""
		exit 3
	fi
	if [ ! -d $var_dir ]; then
		mkdir -p $var_dir
		if [ $? != 0 ]; then
			echo "ERROR: Failed to create directory $var_dir"
			echo ""
			exit 3
		fi
	fi
	if [ "$upgrading" != 1 -a "$envetcdirnotfound" = "" ]; then
		echo "$envvardir"
	fi
	echo ""

	# Ask where perl is installed
	echo "****************************************************************************"
	echo "Webmin is written entirely in Perl. Please enter the full path to the"
	echo "Perl 5 interpreter on your system."
	echo ""
	if [ -x /usr/bin/perl ]; then
		perldef=/usr/bin/perl
	elif [ -x /usr/local/bin/perl ]; then
		perldef=/usr/local/bin/perl
	else
		perldef=""
	fi
	if [ "$perl" = "" ]; then
		if [ "$perldef" = "" ]; then
			printf "Full path to perl: "
			read perl
			if [ "$perl" = "" ]; then
				echo "ERROR: No path entered!"
				echo ""
				exit 4
			fi
		else
			printf "Full path to perl (default $perldef): "
			read perl
			if [ "$perl" = "" ]; then
				perl=$perldef
			fi
		fi
	fi
	echo ""

	# Test perl 
	echo "Testing Perl .."
	if [ ! -x $perl ]; then
		echo "ERROR: Failed to find perl at $perl"
		echo ""
		exit 5
	fi
	$perl -e 'print "foobar\n"' 2>/dev/null | grep foobar >/dev/null
	if [ $? != "0" ]; then
		echo "ERROR: Failed to run test perl script. Maybe $perl is"
		echo "not the perl interpreter, or is not installed properly"
		echo ""
		exit 6
	fi
	$perl -e 'exit ($] < 5.008 ? 1 : 0)'
	if [ $? = "1" ]; then
		echo "ERROR: Detected old perl version. Webmin requires"
		echo "perl 5.8 or better to run"
		echo ""
		exit 7
	fi
	$perl -e 'use Socket; print "foobar\n"' 2>/dev/null | grep foobar >/dev/null
	if [ $? != "0" ]; then
		echo "ERROR: Perl Socket module not installed. Maybe Perl has"
		echo "not been properly installed on your system"
		echo ""
		exit 8
	fi
	$perl -e '$c = crypt("xx", "yy"); exit($c ? 0 : 1)'
	if [ $? != "0" ]; then
		$perl -e 'use Crypt::UnixCrypt' >/dev/null 2>&1
	fi
	if [ $? != "0" ]; then
		echo "ERROR: Perl crypt function does not work, and the"
		echo "Crypt::UnixCrypt module is not installed."
		echo ""
		exit 8
	fi
	echo ".. done"
	echo ""

	# Create temp files directory
	$perl "$srcdir/maketemp.pl"
	if [ "$?" != "0" ]; then
		echo "ERROR: Failed to create or check temp files directory $tempdir"
		echo ""
		exit 2
	fi

	# Ask for operating system type
	echo "****************************************************************************"
	if [ "$os_type" = "" ]; then
		if [ "$autoos" = "" ]; then
			autoos=2
		fi
		$perl "$srcdir/oschooser.pl" "$srcdir/os_list.txt" "$tempdir/$$.os" $autoos
		if [ $? != 0 ]; then
			exit $?
		fi
		. $tempdir/$$.os
		rm -f $tempdir/$$.os
	fi
	echo "Operating system name:    $real_os_type"
	echo "Operating system version: $real_os_version"
	echo ""

	# Ask for web server port, name and password
	echo "****************************************************************************"
	echo "Webmin uses its own password protected web server to provide access"
	echo "to the administration programs. The setup script needs to know :"
	echo " - What port to run the web server on. There must not be another"
	echo "   web server already using this port."
	echo " - The login name required to access the web server."
	echo " - The password required to access the web server."
	echo " - If the web server should use SSL (if your system supports it)."
	echo " - Whether to start webmin at boot time."
	echo ""
	printf "Web server port (default 10000): "
	if [ "$port" = "" ]; then
		read port
		if [ "$port" = "" ]; then
			port=10000
		fi
	fi
	if [ $port -lt 1 ]; then
		echo "ERROR: $port is not a valid port number"
		echo ""
		exit 11
	fi
	if [ $port -gt 65535 ]; then
		echo "ERROR: $port is not a valid port number. Port numbers cannot be"
		echo "       greater than 65535"
		echo ""
		exit 12
	fi
	if [ "$noportcheck" = "" ]; then
		$perl -e 'use Socket; socket(FOO, PF_INET, SOCK_STREAM, getprotobyname("tcp")); setsockopt(FOO, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)); bind(FOO, pack_sockaddr_in($ARGV[0], INADDR_ANY)) || exit(1); exit(0);' $port
		if [ $? != "0" ]; then
			echo "ERROR: TCP port $port is already in use by another program"
			echo ""
			exit 13
		fi
	fi
	printf "Login name (default admin): "
	if [ "$login" = "" ]; then
		read login
		if [ "$login" = "" ]; then
			login="admin"
		fi
	fi
	echo "$login" | grep : >/dev/null
	if [ "$?" = "0" ]; then
		echo "ERROR: Username contains a : character"
		echo ""
		exit 14
	fi
	echo $login | grep " " >/dev/null
	if [ "$?" = "0" ]; then
		echo "ERROR: Username contains a space"
		echo ""
		exit 14
	fi
	if [ "$login" = "webmin" ]; then
		echo "ERROR: Username 'webmin' is reserved for internal use"
		echo ""
		exit 14
	fi
	printf "Login password: "
	if [ "$password" = "" -a "$crypt" = "" ]; then
		stty -echo
		read password
		stty echo
		printf "\n"
		printf "Password again: "
		stty -echo
		read password2
		stty echo
		printf "\n"
		if [ "$password" != "$password2" ]; then
			echo "ERROR: Passwords don't match"
			echo ""
			exit 14
		fi
		echo $password | grep : >/dev/null
		if [ "$?" = "0" ]; then
			echo "ERROR: Password contains a : character"
			echo ""
			exit 14
		fi
	fi

	# Ask the user if SSL should be used
	if [ "$ssl" = "" ]; then
		ssl=0
		$perl -e 'use Net::SSLeay' >/dev/null 2>/dev/null
		if [ $? = "0" ]; then
			printf "Use SSL (y/n): "
			read sslyn
			if [ "$sslyn" = "y" -o "$sslyn" = "Y" ]; then
				ssl=1
			fi
		else
			echo "The Perl SSLeay library is not installed. SSL not available."
			rm -f core
		fi
	fi

	# Don't use SSL if missing Net::SSLeay
	if [ "$ssl" = "1" ]; then
		$perl -e 'use Net::SSLeay' >/dev/null 2>/dev/null
		if [ $? != "0" ]; then
			ssl=0
		fi
	fi

	# Ask whether to run at boot time
	if [ "$atboot" = "" ]; then
		if echo "$os_type" | grep  -q "\-linux$"; then
		    grep_os_type="linux"
		else
		    grep_os_type="$os_type"
		fi
		initsupp=`grep "^os_support=" "$srcdir/init/module.info" | sed -e 's/os_support=//g' | grep $grep_os_type`
		atboot=0
		if [ "$initsupp" != "" ]; then
			printf "Start Webmin at boot time (y/n): "
			read atbootyn
			if [ "$atbootyn" = "y" -o "$atbootyn" = "Y" ]; then
				atboot=1
				makeboot=1
			fi
		else
			echo "Webmin does not support being started at boot time on your system."
		fi
	fi

	# Copy files to target directory
	echo ""
	echo "****************************************************************************"
	if [ "$wadir" != "$srcdir" ]; then
		echo "Copying files to $wadir .."
		(cd "$srcdir" ; tar cf - . | (cd "$wadir" ; tar xf -))
		echo ".. done"
		echo ""
	fi

	# Create webserver config file
	echo $perl > $config_dir/perl-path
	echo $var_dir > $config_dir/var-path
	echo $bootscript > $config_dir/bootscript-name
	echo "Creating web server config files .."
	cfile=$config_dir/miniserv.conf
	echo "port=$port" >> $cfile
	echo "root=$wadir" >> $cfile
	echo "mimetypes=$wadir/mime.types" >> $cfile
	echo "addtype_cgi=internal/cgi" >> $cfile
	echo "realm=Webmin Server" >> $cfile
	echo "logfile=$var_dir/miniserv.log" >> $cfile
	echo "errorlog=$var_dir/miniserv.error" >> $cfile
	echo "pidfile=$var_dir/miniserv.pid" >> $cfile
	echo "logtime=168" >> $cfile
	echo "ssl=$ssl" >> $cfile
	echo "no_ssl2=1" >> $cfile
	echo "no_ssl3=1" >> $cfile
	openssl version 2>&1 | grep "OpenSSL 1" >/dev/null
	if [ "$?" = "0" ]; then
		echo "no_tls1=1" >> $cfile
		echo "no_tls1_1=1" >> $cfile
	fi
	echo "ssl_honorcipherorder=1" >> $cfile
	echo "no_sslcompression=1" >> $cfile
	echo "env_WEBMIN_CONFIG=$config_dir" >> $cfile
	echo "env_WEBMIN_VAR=$var_dir" >> $cfile
	echo "atboot=$atboot" >> $cfile
	echo "logout=$config_dir/logout-flag" >> $cfile
	if [ "$listen" != "" ]; then
		echo "listen=$listen" >> $cfile
	else
		echo "listen=10000" >> $cfile
	fi
	echo "denyfile=\\.pl\$" >> $cfile
	echo "log=1" >> $cfile
	echo "blockhost_failures=5" >> $cfile
	echo "blockhost_time=60" >> $cfile
	echo "syslog=1" >> $cfile
	echo "ipv6=1" >> $cfile
	if [ "$allow" != "" ]; then
		echo "allow=$allow" >> $cfile
	fi
	if [ "$session" != "" ]; then
		echo "session=$session" >> $cfile
	else
		echo "session=1" >> $cfile
	fi
	if [ "$pam" != "" ]; then
		echo "pam=$pam" >> $cfile
	fi
	echo premodules=WebminCore >> $cfile
	echo "server=MiniServ/$ver" >> $cfile

	# Append package-specific info to config file
	if [ -r "$wadir/miniserv-conf" ]; then
		cat "$wadir/miniserv-conf" >>$cfile
	fi

	# Test available hashing formats
	yescryptpass=`$perl -e 'print crypt("test", "\\$y\\$j9T\\$waHytoaqP/CEnKFroGn0S/\\$fxd5mVc2mBPUc3vv.cpqDckpwrWTyIm2iD4JfnVBi26") eq "\\$y\\$j9T\\$waHytoaqP/CEnKFroGn0S/\\$fxd5mVc2mBPUc3vv.cpqDckpwrWTyIm2iD4JfnVBi26" ? "1\n" : "0\n"'`
	sha512pass=`$perl -e 'print crypt("test", "\\$6\\$Tk5o/GEE\\$zjvXhYf/dr5M7/jan3pgunkNrAsKmQO9r5O8sr/Cr1hFOLkWmsH4iE9hhqdmHwXd5Pzm4ubBWTEjtMeC.h5qv1") eq "\\$6\\$Tk5o/GEE\\$zjvXhYf/dr5M7/jan3pgunkNrAsKmQO9r5O8sr/Cr1hFOLkWmsH4iE9hhqdmHwXd5Pzm4ubBWTEjtMeC.h5qv1" ? "1\n" : "0\n"'`
	md5pass=`$perl -e 'print crypt("test", "\\$1\\$A9wB3O18\\$zaZgqrEmb9VNltWTL454R/") eq "\\$1\\$A9wB3O18\\$zaZgqrEmb9VNltWTL454R/" ? "1\n" : "0\n"'`

	salt8=`tr -dc A-Za-z0-9 </dev/urandom | head -c 8 ; echo ''`
	salt2=`tr -dc A-Za-z0-9 </dev/urandom | head -c 2 ; echo ''`

	ufile=$config_dir/miniserv.users
	if [ "$crypt" != "" ]; then
		echo "$login:$crypt:0" > $ufile
	else
		if [ "$yescryptpass" = "1" ]; then
			$perl -e 'print "$ARGV[0]:",crypt($ARGV[1], "\$y\$j9T\$$ARGV[2]"),":0\n"' "$login" "$password" "$salt8" > $ufile
		elif [ "$sha512pass" = "1" ]; then
			$perl -e 'print "$ARGV[0]:",crypt($ARGV[1], "\$6\$$ARGV[2]"),":0\n"' "$login" "$password" "$salt8" > $ufile
		elif [ "$md5pass" = "1" ]; then
			$perl -e 'print "$ARGV[0]:",crypt($ARGV[1], "\$1\$$ARGV[2]"),":0\n"' "$login" "$password" "$salt8" > $ufile
		else
			$perl -e 'print "$ARGV[0]:",crypt($ARGV[1], $ARGV[2]),":0\n"' "$login" "$password" "$salt2" > $ufile
		fi
	fi
	chmod 600 $ufile
	echo "userfile=$ufile" >> $cfile

	kfile=$config_dir/miniserv.pem
	openssl version >/dev/null 2>&1
	if [ "$?" = "0" ]; then
		# OpenSSL support `-addext` flag?
		addtextsup="-addext subjectAltName=DNS:$host,DNS:localhost -addext extendedKeyUsage=serverAuth"
		openssl version 2>&1 | grep "OpenSSL 1.0" >/dev/null
		if [ "$?" = "0" ]; then
			addtextsup=""
		fi
		# We can generate a new SSL key for this host
		openssl req -newkey rsa:2048 -x509 -nodes -out $tempdir/cert -keyout $tempdir/key -days 1825 -sha256 -subj "/CN=$host/C=US/L=Santa Clara" $addtextsup >/dev/null 2>&1 <<EOF
.
.
.
Webmin web server on $host
.
*
root@$host
EOF
		if [ "$?" = "0" ]; then
			cat $tempdir/cert $tempdir/key >$kfile
		fi
		rm -f $tempdir/cert $tempdir/key
	fi
	if [ ! -r $kfile ]; then
		# Fall back to the built-in key
		cp "$wadir/miniserv.pem" $kfile
	fi
	chmod 600 $kfile
	echo "keyfile=$config_dir/miniserv.pem" >> $cfile

	chmod 600 $cfile
	echo ".. done"
	echo ""

	echo "Creating access control file .."
	afile=$config_dir/webmin.acl
	rm -f $afile
	if [ "$defaultmods" = "" ]; then
		echo "$login: $allmods" >> $afile
	else
		echo "$login: $defaultmods" >> $afile
	fi
	chmod 600 $afile
	echo ".. done"
	echo ""

	if [ "$login" != "root" -a "$login" != "admin" ]; then
		# Allow use of RPC by this user
		echo rpc=1 >>$config_dir/$login.acl
	fi
fi

if [ "$noperlpath" = "" ]; then
	echo "Inserting path to perl into scripts .."
	(find "$wadir" -name '*.cgi' -print ; find "$wadir" -name '*.pl' -print) | $perl "$wadir/perlpath.pl" $perl -
	echo ".. done"
	echo ""
fi

killmodenonesh=0
if [ ! -f "$config_dir/.pre-install" ]; then
	killmodenonesh=1
fi

# Test if we have systemd system
systemctlcmd=$(command -v systemctl 2>/dev/null || :)
if [ -x "$systemctlcmd" ]; then
    initsys=$(cat /proc/1/comm 2>/dev/null)
    if [ "$initsys" != "systemd" ]; then
        systemctlcmd=""
    fi
fi

# Re-generating main scripts
echo "Creating start and stop scripts .."
# Start main
echo "#!/bin/sh" >$config_dir/.start-init
echo "echo Starting Webmin server in $wadir" >>$config_dir/.start-init
echo "trap '' 1" >>$config_dir/.start-init
echo "LANG=" >>$config_dir/.start-init
echo "export LANG" >>$config_dir/.start-init
echo "unset PERLIO" >>$config_dir/.start-init
echo "export PERLIO" >>$config_dir/.start-init
echo "PERLLIB=$PERLLIB" >>$config_dir/.start-init
echo "export PERLLIB" >>$config_dir/.start-init
uname -a | grep -i 'HP/*UX' >/dev/null
if [ $? = "0" ]; then
	echo "exec '$wadir/miniserv.pl' \$* $config_dir/miniserv.conf &" >>$config_dir/.start-init
else
	echo "exec '$wadir/miniserv.pl' \$* $config_dir/miniserv.conf" >>$config_dir/.start-init
fi
# Stop main
echo "#!/bin/sh" >$config_dir/.stop-init
echo "if [ \"\$1\" = \"--kill\" ]; then" >>$config_dir/.stop-init
echo "  echo Force stopping Webmin server in $wadir" >>$config_dir/.stop-init
echo "else" >>$config_dir/.stop-init
echo "  echo Stopping Webmin server in $wadir" >>$config_dir/.stop-init
echo "fi" >>$config_dir/.stop-init
echo "targets=\"stats.pl shellserver.pl\"" >>$config_dir/.stop-init
echo "collect_pids() {" >>$config_dir/.stop-init
echo "  for s in \$targets; do" >>$config_dir/.stop-init
echo "    ps axww | grep \"$wadir/\" | grep \"/\$s\" | grep -v grep" >>$config_dir/.stop-init
echo "  done | awk '{print \$1}' | sort -u" >>$config_dir/.stop-init
echo "}" >>$config_dir/.stop-init
echo "pids=\$(collect_pids)" >>$config_dir/.stop-init
echo "[ -n \"\$pids\" ] && kill \$pids 2>/dev/null || true" >>$config_dir/.stop-init
echo "if [ \"\$1\" = \"--kill\" ]; then" >>$config_dir/.stop-init
echo "  sleep 1" >>$config_dir/.stop-init
echo "  pids=\$(collect_pids)" >>$config_dir/.stop-init
echo "  [ -n \"\$pids\" ] && kill -KILL \$pids 2>/dev/null || true" >>$config_dir/.stop-init
echo "fi" >>$config_dir/.stop-init
echo "pidfile=\`grep \"^pidfile=\" $config_dir/miniserv.conf | sed -e 's/pidfile=//g'\`" >>$config_dir/.stop-init
echo "pid=\`cat \$pidfile 2>/dev/null\`" >>$config_dir/.stop-init
echo "if [ \"\$pid\" != \"\" ]; then" >>$config_dir/.stop-init
echo "  kill \$pid || exit 1" >>$config_dir/.stop-init
echo "  touch $var_dir/stop-flag" >>$config_dir/.stop-init
echo "  if [ \"\$1\" = \"--kill\" ]; then" >>$config_dir/.stop-init
echo "    sleep 1" >>$config_dir/.stop-init
echo "    (ps axf | grep \"$wadir\/miniserv\.pl\" | awk '{print \"kill -9 -- -\" \$1}' | bash ; kill -9 -- -\$pid ; kill -9 \$pid) 2>/dev/null" >>$config_dir/.stop-init
echo "  fi" >>$config_dir/.stop-init
echo "  exit 0" >>$config_dir/.stop-init
echo "else" >>$config_dir/.stop-init
echo "  if [ \"\$1\" = \"--kill\" ]; then" >>$config_dir/.stop-init
echo "    (ps axf | grep \"$wadir\/miniserv\.pl\" | awk '{print \"kill -9 -- -\" \$1}' | bash ; kill -9 -- -\$pid ; kill -9 \$pid) 2>/dev/null" >>$config_dir/.stop-init
echo "  fi" >>$config_dir/.stop-init
echo "fi" >>$config_dir/.stop-init
# Restart main
echo "#!/bin/sh" >$config_dir/.restart-init
echo "$config_dir/.stop-init" >>$config_dir/.restart-init
echo "$config_dir/.start-init" >>$config_dir/.restart-init
# Force reload main
echo "#!/bin/sh" >$config_dir/.restart-by-force-kill-init
echo "$config_dir/.stop-init --kill" >>$config_dir/.restart-by-force-kill-init
echo "$config_dir/.start-init" >>$config_dir/.restart-by-force-kill-init
# Reload main
echo "#!/bin/sh" >$config_dir/.reload-init
echo "echo Reloading Webmin server in $wadir" >>$config_dir/.reload-init
echo "pidfile=\`grep \"^pidfile=\" $config_dir/miniserv.conf | sed -e 's/pidfile=//g'\`" >>$config_dir/.reload-init
echo "kill -USR1 \`cat \$pidfile\`" >>$config_dir/.reload-init
# Switch to systemd from init (intermediate)
if [ "$killmodenonesh" = "1" ] && [ -x "$systemctlcmd" ]; then
	current_version=`cat "$config_dir/version" 2>/dev/null`
	ancient_version=`echo $current_version 1.994 | awk '{if ($1 < $2) print 1; else print 0}'`
	if [ "$ancient_version" = "1" ]; then
		echo "#!/bin/sh" >$config_dir/.reload-init-systemd
		echo "$config_dir/.stop-init" >>$config_dir/.reload-init-systemd
		echo "$config_dir/start" >>$config_dir/.reload-init-systemd
		chmod 755 $config_dir/.reload-init-systemd
	fi
fi
# Pre install
echo "#!/bin/sh" >$config_dir/.pre-install
echo "$config_dir/.stop-init" >>$config_dir/.pre-install
# Post install
echo "#!/bin/sh" >$config_dir/.post-install
echo "$config_dir/.start-init" >>$config_dir/.post-install

chmod 755 $config_dir/.stop-init $config_dir/.start-init $config_dir/.restart-init $config_dir/.restart-by-force-kill-init $config_dir/.reload-init $config_dir/.pre-install $config_dir/.post-install
echo ".. done"
echo ""

# Re-generating supplementary

# Clear existing
rm -f $config_dir/stop $config_dir/start $config_dir/restart $config_dir/restart-by-force-kill $config_dir/reload

# Start init.d
ln -s $config_dir/.start-init $config_dir/start >/dev/null 2>&1
# Stop init.d
ln -s $config_dir/.stop-init $config_dir/stop >/dev/null 2>&1
# Restart init.d
ln -s $config_dir/.restart-init $config_dir/restart >/dev/null 2>&1
# Force reload init.d
ln -s $config_dir/.restart-by-force-kill-init $config_dir/restart-by-force-kill >/dev/null 2>&1
# Reload init.d
ln -s $config_dir/.reload-init $config_dir/reload >/dev/null 2>&1

# For systemd create different start/stop scripts
if [ -x "$systemctlcmd" ]; then
	rm -f $config_dir/stop $config_dir/start $config_dir/restart $config_dir/restart-by-force-kill $config_dir/reload
	# Start systemd
	echo "#!/bin/sh" >$config_dir/start
	echo "$systemctlcmd start $bootscript" >>$config_dir/start
	# Stop systemd
	echo "#!/bin/sh" >$config_dir/stop
	echo "$systemctlcmd stop $bootscript" >>$config_dir/stop
	# Restart systemd
	echo "#!/bin/sh" >$config_dir/restart
	echo "$systemctlcmd restart $bootscript" >>$config_dir/restart
	# Force reload systemd
	echo "#!/bin/sh" >$config_dir/restart-by-force-kill
	echo "$systemctlcmd stop $bootscript" >>$config_dir/restart-by-force-kill
	echo "$config_dir/.stop-init --kill >/dev/null 2>&1" >>$config_dir/restart-by-force-kill
	echo "$systemctlcmd start $bootscript" >>$config_dir/restart-by-force-kill
	# Reload systemd
	echo "#!/bin/sh" >$config_dir/reload
	echo "$systemctlcmd reload $bootscript" >>$config_dir/reload
	# Pre-install on systemd
	echo "#!/bin/sh" >$config_dir/.pre-install
	# echo "$systemctlcmd kill --signal=SIGSTOP --kill-who=main $bootscript" >>$config_dir/.pre-install
	# Post-install on systemd
	echo "#!/bin/sh" >$config_dir/.post-install
	# echo "$systemctlcmd kill --signal=SIGCONT --kill-who=main $bootscript" >>$config_dir/.post-install
	echo "$systemctlcmd kill --signal=SIGHUP --kill-who=main $bootscript" >>$config_dir/.post-install
	
	chmod 755 $config_dir/stop $config_dir/start $config_dir/restart $config_dir/restart-by-force-kill $config_dir/reload $config_dir/.pre-install $config_dir/.post-install
fi

if [ "$upgrading" = 1 -a "$inetd" != "1" -a "$nostop" = "" ]; then
	# Stop old version, with updated stop script
	$config_dir/.pre-install >/dev/null 2>&1
fi

if [ "$upgrading" = 1 ]; then
	echo "Updating config files .."
else
	echo "Copying config files .."
fi
newmods=`$perl "$wadir/copyconfig.pl" "$os_type/$real_os_type" "$os_version/$real_os_version" "$wadir" $config_dir "" $allmods`
if [ "$upgrading" != 1 ]; then
	# Store the OS and version
	echo "os_type=$os_type" >> $config_dir/config
	echo "os_version=$os_version" >> $config_dir/config
	echo "real_os_type=$real_os_type" >> $config_dir/config
	echo "real_os_version=$real_os_version" >> $config_dir/config
	echo "lang=en" >> $config_dir/config

	# Turn on logging by default
	echo "log=1" >> $config_dir/config

	# Use licence module specified by environment variable
	if [ "$licence_module" != "" ]; then
		echo licence_module=$licence_module >>$config_dir/config
	fi

	# Enable log rotation by default
	echo "logclear=1" >> $config_dir/miniserv.conf
	echo "logclear=1" >> $config_dir/config
	
	# Enable HSTS by default
	echo "ssl_hsts=1" >> $config_dir/miniserv.conf

	# Enable force redirect to SSL by default
	echo "ssl_enforce=1" >> $config_dir/miniserv.conf

	# Disallow unknown referers by default
	echo "referers_none=1" >>$config_dir/config
else
	# Enable HSTS by default if not set
	grep ssl_hsts= $config_dir/miniserv.conf >/dev/null
	if [ "$?" != "0" ]; then
		echo "ssl_hsts=1" >> $config_dir/miniserv.conf
	fi

	# Enable force redirect to SSL if not set
	grep ssl_enforce= $config_dir/miniserv.conf >/dev/null
	if [ "$?" != "0" ]; then
		echo "ssl_enforce=1" >> $config_dir/miniserv.conf
	fi

	# Disallow unknown referers if not set
	grep referers_none= $config_dir/config >/dev/null
	if [ "$?" != "0" ]; then
		echo "referers_none=1" >>$config_dir/config
	fi
fi
echo $ver > $config_dir/version
echo ".. done"
echo ""

# Set passwd_ fields in miniserv.conf from global config
for field in passwd_file passwd_uindex passwd_pindex passwd_cindex passwd_mindex; do
	grep $field= $config_dir/miniserv.conf >/dev/null
	if [ "$?" != "0" ]; then
		grep $field= $config_dir/config >> $config_dir/miniserv.conf
	fi
done
grep passwd_mode= $config_dir/miniserv.conf >/dev/null
if [ "$?" != "0" ]; then
	echo passwd_mode=0 >> $config_dir/miniserv.conf
fi

# Use system defaults for password hashing
echo md5pass=0 >> $config_dir/config

# Set a special theme if none was set before
if [ "$theme" = "" ]; then
	theme=`cat "$wadir/defaulttheme" 2>/dev/null`
	# If no default theme found fall back to Framed Theme
	if [ ! -d "$wadir/$theme" ]; then
		theme="gray-theme"
	fi
fi
oldthemeline=`grep "^theme=" $config_dir/config`
oldtheme=`echo $oldthemeline | sed -e 's/theme=//g'`
if [ "$theme" != "" ] && [ "$oldthemeline" = "" ] && [ -d "$wadir/$theme" ]; then
	themelist=$theme
fi

# Set a special overlay if none was set before
if [ "$overlay" = "" ]; then
	overlay=`cat "$wadir/defaultoverlay" 2>/dev/null`
fi
if [ "$overlay" != "" ] && [ "$theme" != "" ] && [ -d "$wadir/$overlay" ]; then
	themelist="$themelist $overlay"
fi

# Apply the theme and maybe overlay
if [ "$themelist" != "" ]; then
	echo "theme=$themelist" >> $config_dir/config
	echo "preroot=$themelist" >> $config_dir/miniserv.conf
fi

# If the old blue-theme is still in use, change it
oldtheme=`grep "^theme=" $config_dir/config | sed -e 's/theme=//g'`
if [ "$oldtheme" = "blue-theme" ]; then
   echo "theme=gray-theme" >> $config_dir/config
   echo "preroot=gray-theme" >> $config_dir/miniserv.conf
fi

# Set the product field in the global config
grep product= $config_dir/config >/dev/null
if [ "$?" != "0" ]; then
	echo product=webmin >> $config_dir/config
fi

# Add boot script if needed
if [ "$makeboot" = "1" ]; then
	echo "Configuring Webmin to start at boot time .."
	(cd "$wadir/init" ; WEBMIN_CONFIG=$config_dir WEBMIN_VAR=$var_dir "$wadir/init/atboot.pl" $bootscript)
	echo ".. done"
	echo ""
fi

# Update boot script if needed
(cd "$wadir/init" ; WEBMIN_CONFIG=$config_dir WEBMIN_VAR=$var_dir "$wadir/init/updateboot.pl" "$bootscript")

# If password delays are not specifically disabled, enable them
grep passdelay= $config_dir/miniserv.conf >/dev/null
if [ "$?" != "0" ]; then
	echo passdelay=1 >> $config_dir/miniserv.conf
fi

if [ "$nouninstall" = "" ]; then
	echo "Creating uninstall script $config_dir/uninstall.sh .."
	cat >$config_dir/uninstall.sh <<EOF
#!/bin/sh
printf "Are you sure you want to uninstall Webmin? (y/n) : "
read answer
printf "\n"
if [ "\$answer" = "y" ]; then
	$config_dir/stop
	echo "Running uninstall scripts .."
	if [ -r "$wadir/run-uninstalls.pl" ]; then
		(cd "$wadir" ; WEBMIN_CONFIG=$config_dir WEBMIN_VAR=$var_dir LANG= "$wadir/run-uninstalls.pl") >/dev/null 2>&1 </dev/null
	fi
	echo "Deleting $wadir .."
	rm -rf "$wadir"
	echo "Deleting $config_dir .."
	rm -rf "$config_dir"
	echo "Deleting $var_dir .."
	rm -rf "$var_dir"
	echo "Done!"
fi
EOF
	chmod +x $config_dir/uninstall.sh
	echo ".. done"
	echo ""
fi

echo "Changing ownership and permissions .."
# Make all config dirs non-world-readable
for m in $newmods; do
	chown -R root $config_dir/$m
	chgrp -R bin $config_dir/$m
	chmod -R og-rw $config_dir/$m
done
# Make miniserv config files non-world-readable
for f in miniserv.conf miniserv.pem miniserv.users; do
	chown -R root $config_dir/$f
	chgrp -R bin $config_dir/$f
	chmod -R og-rw $config_dir/$f
done
chmod +r $config_dir/version
if [ "$nochown" = "" ]; then
	# Make program directory non-world-writable, but executable
	chown -R root "$wadir"
	chgrp -R bin "$wadir"
	chmod -R og-w "$wadir"
	chmod -R a+rx "$wadir"
fi
if [ $var_dir != "/var" -a "$upgrading" != 1 ]; then
	# Make log directory non-world-readable or writable
	chown -R root $var_dir
	chgrp -R bin $var_dir
	chmod -R og-rwx $var_dir
fi
# Fix up bad permissions from some older installs
for m in ldap-client ldap-server ldap-useradmin mailboxes mysql postgresql servers virtual-server; do
	if [ -d "$config_dir/$m" ]; then
		chown root $config_dir/$m
		chgrp bin $config_dir/$m
		chmod og-rw $config_dir/$m
		chmod og-rw $config_dir/$m/config 2>/dev/null
	fi
done
echo ".. done"
echo ""

# Save target directory if one was specified
if [ "$wadir" != "$srcdir" ]; then
	echo $wadir >$config_dir/install-dir
else
	rm -f $config_dir/install-dir
fi

if [ "$nopostinstall" = "" ]; then
	echo "Running postinstall scripts .."
	(cd "$wadir" ; WEBMIN_CONFIG=$config_dir WEBMIN_VAR=$var_dir WEBMIN_UPGRADING="$upgrading" "$wadir/run-postinstalls.pl")
	echo ".. done"
	echo ""
fi

# Enable background collection
if [ "$upgrading" != 1 -a -r $config_dir/system-status/enable-collection.pl ]; then
	echo "Enabling background status collection .."
	$config_dir/system-status/enable-collection.pl 5
	echo ".. done"
	echo ""
fi

# Run package-defined post-install script
if [ -r "$srcdir/setup-post.sh" ]; then
	. "$srcdir/setup-post.sh"
fi

if [ "$nostart" = "" ]; then
	if [ "$inetd" != "1" ]; then
		action="start"
		if [ "$upgrading" = "1" ]; then
			action="restart"
		fi
		echo "Attempting to $action Webmin web server .."
		# If upgrading, restart
		if [ "$upgrading" = "1" ]; then
			if [ "$killmodenonesh" != "1" ]; then
				$config_dir/.post-install >/dev/null 2>&1 </dev/null
			else
				$config_dir/.reload-init >/dev/null 2>&1 </dev/null
			fi
		# If installing first time, start it
		else
			$config_dir/start >/dev/null 2>&1 </dev/null
		fi

		if [ $? != "0" ]; then
			echo "ERROR: Failed to $action web server!"
			echo ""
			exit 14
		fi
		echo ".. done"
		echo ""
	fi
	postactionmsg="installed"
	postactionmsg2="started"
	if [ "$upgrading" = "1" ]; then
		postactionmsg="upgraded"
		postactionmsg2="restarted"
	fi
	echo "****************************************************************************"
	echo "Webmin has been $postactionmsg and $postactionmsg2 successfully."
	echo ""
	if [ "$nodepsmsg" = "" -a "$upgrading" != 1 ]; then
		echo "Since Webmin was installed outside the package manager, ensure the"
		echo "following recommended Perl modules and packages are present:"
		echo " Perl modules:"
		echo "  - DateTime, DateTime::Locale, DateTime::TimeZone, Data::Dumper,"
		echo "  - Digest::MD5, Digest::SHA, Encode::Detect, File::Basename,"
		echo "  - File::Path, Net::SSLeay, Time::HiRes, Time::Local, Time::Piece,"
		echo "  - Socket6, Sys::Syslog, JSON::XS, lib, open"
		echo " Packages:"
		echo "  - openssl - Cryptography library with TLS implementation"
		echo "  - shared-mime-info - Shared MIME information database"
		echo "  - tar gzip unzip - File compression and packaging utilities"
		echo ""
	fi
	echo "Use your web browser to go to the following URL and login"
	echo "with the name and password you entered previously:"
	echo ""
	if [ "$ssl" = "1" ]; then
		echo "  https://$host:$port"
	else
		echo "  http://$host:$port"
	fi
	echo ""
	if [ "$ssl" = "1" ]; then
		echo "Because Webmin uses SSL for encryption only, the certificate"
		echo "it uses is not signed by one of the recognized CAs such as"
		echo "Verisign. When you first connect to the Webmin server, your"
		echo "browser will ask you if you want to accept the certificate"
		echo "presented, as it does not recognize the CA. Say yes."
		echo ""
	fi
fi

if [ "$oldwadir" != "$wadir" -a "$upgrading" = 1 -a "$deletedold" != 1 ]; then
	echo "The directory from the previous version of Webmin"
	echo "   $oldwadir"
	echo "Can now be safely deleted to free up disk space, assuming"
	echo "that all third-party modules have been copied to the new"
	echo "version."
	echo ""
fi


