#!/usr/local/bin/perl
# postfinger.cgi
# check postfix configuration

require './postfix-lib.pl';

&ReadParse();

$System=$in{'system'}||1;
$Package=$in{'package'}||1;
$Locking=$in{'locking'}||0;
$Tables=$in{'tables'}||0;
$Main=$in{'main'}||1;
$Master=$in{'master'}||1;
$Permissions=$in{'permissions'}||0;
$Libraries=$in{'libraries'}||0;
$Warn=$in{'warn'}||1;
$Defaultsinmain=$in{'defaultsinmain'}||1;

$access{'postfinger'} || &error($text{'postfinger_ecannot'});
&header($text{'postfinger_title'}, "");
if ( !$in{'go'} ) {
	print "<br><form action=postfinger.cgi>\n";
	print "<input type=hidden name=go value=go>\n";
	print "<table border>\n";
	print "<tr $cb> <td><table>\n";
	print "<tr $cb> <td><font color=0000FF size=4><b>Display Options:</b></font></td></tr>\n";
	print "<tr $cb> <td><b>System</b></td> <td colspan=3>\n";
	printf "<input type=radio name=system value=1 %s> %s\n",
	$System eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=system value=no %s> %s\n",
	$System eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $System),"</td> </tr>\n";

	print "<tr $cb> <td><b>Package</b></td> <td colspan=3>\n";
	printf "<input type=radio name=package value=1 %s> %s\n",
	$Package eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=package value=no %s> %s\n",
	$Package eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Package),"</td> </tr>\n";

	print "<tr $cb> <td><b>Main</b></td> <td colspan=3>\n";
	printf "<input type=radio name=main value=1 %s> %s\n",
	$Main eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=main value=no %s> %s\n",
	$Main eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Main),"</td> </tr>\n";

	print "<tr $cb> <td><b>Defaults in Main</b></td> <td colspan=3>\n";
	printf "<input type=radio name=defaultsinmain value=1 %s> %s\n",
	$Defaultsinmain eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=defaultsinmain value=no %s> %s\n",
	$Defaultsinmain eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Defaultsinmain),"</td> </tr>\n";

	print "<tr $cb> <td><b>Master</b></td> <td colspan=3>\n";
	printf "<input type=radio name=master value=1 %s> %s\n",
	$Master eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=master value=no %s> %s\n",
	$Master eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Master),"</td> </tr>\n";

	print "<tr $cb> <td><b>Locking</b></td> <td colspan=3>\n";
	printf "<input type=radio name=locking value=1 %s> %s\n",
	$Locking eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=locking value=no %s> %s\n",
	$Locking eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Locking),"</td> </tr>\n";

	print "<tr $cb> <td><b>Tables</b></td> <td colspan=3>\n";
	printf "<input type=radio name=tables value=1 %s> %s\n",
	$Tables eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=tables value=no %s> %s\n",
	$Tables eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Tables),"</td> </tr>\n";

	print "<tr $cb> <td><b>Permissions</b></td> <td colspan=3>\n";
	printf "<input type=radio name=permissions value=1 %s> %s\n",
	$Permissions eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=permissions value=no %s> %s\n",
	$Permissions eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Permissions),"</td> </tr>\n";

	print "<tr $cb> <td><b>Libraries</b></td> <td colspan=3>\n";
	printf "<input type=radio name=libraries value=1 %s> %s\n",
	$Libraries eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=libraries value=no %s> %s\n",
	$Libraries eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Libraries),"</td> </tr>\n";

	print "<tr $cb> <td><b>Warn</b></td> <td colspan=3>\n";
	printf "<input type=radio name=warn value=1 %s> %s\n",
	$Warn eq 1 ? 'checked' : '', $text{'yes'};
	printf "<input type=radio name=warn value=no %s> %s\n",
	$Warn eq 1 ? '' : 'checked', $text{'no'},
	join(" ", $Warn),"</td> </tr>\n";
	print "<tr><td> </td></tr><tr><td><input type=submit value=\"$text{'postfinger_show'}\"></td></tr></form>\n";

	print "</table></td> </tr></table>";
	&footer("index.cgi", $text{'index_title'});
} else {
	&head;
	if (! -x $config{'postfix_config_command'} && ! -r $config{'postfix_config_file'} ) {
		print "Can not find postconf";
		exit;
	}
# Verify that current configuration is valid
	if ($config{'index_check'} && ($err = &check_postfix())) {
		print "<p>",&text('check_error'),"<p>\n";
		print "<pre>$err</pre>\n";
		&footer("/", $text{'index'});
		exit;
	}
	if ($System eq 1 ) {
#		print '<center><b>--System Parameters--</b></center>';
		if (&has_command($config{'postfix_config_command'})) {
			print "<h1 class='p'>Postfix Version: $postfix_version</h1>";
			print "</td></tr>";
			print "</table><br />";
			print "<table border='0' cellpadding='3' width='600' align='center'>";
			open(MAILQ, "/bin/hostname 2>/dev/null |");
			while (my $hostname = <MAILQ>) { print "<tr><td class='e'>Hostname </td><td class='v'>$hostname</td></tr>"; } 
			close(MAILQ);
			open(MAILQ, "/bin/uname -a 2>/dev/null |");
			while (my $uname = <MAILQ>) { print "<tr><td class='e'>System </td><td class='v'>$uname</td></tr>"; } 
			close(MAILQ);
		}
		print "</table><br />";
	}

	if ($Locking eq 1 ) {
		print '<h1 align="center">Mailbox locking methods</h1>';
		print '<table border="0" cellpadding="0" width="600" align="center">';
		open(MAILQ, "$config{'postfix_config_command'} -l 2>/dev/null |");
		while (my $locking_methods = <MAILQ>) {
			print "<tr><td class='v'><center><b>$locking_methods</b></center></td></tr>"; }
		close(MAILQ);
		print "</table><br />";
	}

	if ($Tables eq 1 ) {
		print '<h1 align="center">Supported Lookup Tables</h1>';
		print '<table border="0" cellpadding="0" width="600" align="center">';
#		print '<center><b>--Supported Lookup tables--</b></center><br>';
		open(MAILQ, "$config{'postfix_config_command'} -m 2>/dev/null |");
		while (my $lookup_tables = <MAILQ>) {
			print "<tr><td class='v'><center><b>$lookup_tables</b></center></td></tr>"; }
		close(MAILQ);
		print "</table><br />";
	}

	if (($Main eq 1 || $Defaultsinmain eq 1 ) && ("x`find . -prune  \( -perm 020 -o -perm 002 \) -print`" != "x")){
		print "<center><b>Do not run this in a public- or group-writable directory</b></center><br>";
		exit;
	} else {
	system ("rm postfinger.*.d postfinger.*.n");
#	unlink  "postfinger.*.d, postfinger.*.n";
	`$config{'postfix_config_command'} -d | tr -s [:blank:] | sort > postfinger.$$.d`;
	`$config{'postfix_config_command'} -n | tr -s [:blank:] | sort > postfinger.$$.n`;

	if ($Main eq 1 ) {
		print '<h1 align="center">main.cf</h1><br><h2 align="center">non-default parameters</h2>';
		print '<table border="0" cellpadding="2" width="600" align="center">';
#		print '<center><b>--main.cf non-default parameters--</b></center><br>';
		open(MAILQ, "/usr/bin/comm -13 postfinger.$$.d postfinger.$$.n 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
			($postf1,$postf2)=split(/=/,$postfinger,2);
			print "<tr><td class='e'><b>$postf1</b></td>"; 
			print "<td class='v'>$postf2</td></tr>"; }
		close(MAILQ);
		print "</table><br />";
	}

	if ($Defaultsinmain eq 1 ) {
		print '<h1 align="center">main.cf</h1><br><h2 align="center">parameters defined as per defaults</h2>';
		print '<table border="0" cellpadding="2" width="600" align="center">';
#		print '<center><b>--main.cf parameters defined as per defaults--</b></center><br>';
		open(MAILQ, "/usr/bin/comm -12 postfinger.$$.d postfinger.$$.n 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
			($postf1,$postf2)=split(/=/,$postfinger,2);
			print "<tr><td class='e'><b>$postf1</b></td>"; 
			print "<td class='v'>$postf2</td></tr>"; }
		close(MAILQ);
		print "</table><br />";
	}
	unlink  "postfinger.*.d, postfinger.*.n";
	}

	if ($Master eq 1 ) {
		print '<h1 align="center">master.cf</h1><br>';
		print '<table border="0" cellpadding="8" width="600" align="center">';
		print "<tr><td class='e'><b>service</b></td><td class='v'><b>type</b></td>",
			"<td class='v'><b>private</b></td><td class='v'><b>unpriv</b></td>",
			"<td class='v'><b>chroot</b></td><td class='v'><b>wakeup</b></td>",
			"<td class='v'><b>maxproc</b></td><td class='v'><b>command + args</b></td></tr>";
		open(MAILQ, "/bin/cat `$config{'postfix_config_command'} -h config_directory`/master.cf 2>/dev/null |");
		while (my $postfinger = <MAILQ>) { 
			($postf1,$postf2,$postf3,$postf4,$postf5,$postf6,$postf7,$postf8)=split(/\s+/,$postfinger,8);
			if ($postfinger =~ /\-o/) {
				print "<tr><td class='e'> </td><td class='v'> </td>",
					"<td class='v'> </td><td class='v'> </td>",
					"<td class='v'> </td><td class='v'> </td>",
					"<td class='v'> </td><td class='v'>$postf2</td></tr>"
				if ( !grep(/^#|^\[ 	\]*$/,$postfinger));
			} elsif ($postfinger =~ /user=/) {
				print "<tr><td class='e'> </td><td class='v'> </td>",
					"<td class='v'> </td><td class='v'> </td>",
					"<td class='v'> </td><td class='v'> </td>",
					"<td class='v'> </td><td class='v'>$postf1</td></tr>"
				if ( !grep(/^#|^\[ 	\]*$/,$postfinger));
			} else {
				print "<tr><td class='e'><b>$postf1</b></td><td class='v'><center>$postf2</center></td>",
					"<td class='v'><center>$postf3</center></td><td class='v'><center>$postf4</center></td>",
					"<td class='v'><center>$postf5</center></td><td class='v'><center>$postf6</center></td>",
					"<td class='v'><center>$postf7</center></td><td class='v'>$postf8</td></tr>"
				if ( !grep(/^#|^\[ 	\]*$/,$postfinger));
			} 
		} 
		close(MAILQ);
		print "</table><br>";
	}

	if ($Permissions eq 1 ) {
		print '<h1 align="center">Specific file and directory permissions</h1><br>';
		print '<table border="0" cellpadding="0" width="600" align="center">';
		print "<tr><td class='e'><b>Permission</b> Deep <b>Owner</b> <b>Group</b> Size   Date  <b>Directory/File</b> </td></tr>";
		open(MAILQ, "/bin/ls -ld `$config{'postfix_config_command'} -h queue_directory`/maildrop 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
			print "<tr><td class='v'>$postfinger</td></tr>"
			if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
		} 
		close(MAILQ);
		print "<tr><td> </td></tr>";
		open(MAILQ, "/bin/ls -ld `$config{'postfix_config_command'} -h queue_directory`/public 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
			print "<tr><td class='v'>$postfinger</td></tr>"
			if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
		} 
		close(MAILQ);
		print "<tr><td> </td></tr>";
		if (! open(MAILQ, "/bin/ls -l `$config{'postfix_config_command'} -h queue_directory`/public 2>/dev/null |")) {
		        print '<center><b>WARNING: No access to $queue_directory/public<br>Try running postfinger as user root or postfix</b></center><br>';
		} else {
			while (my $postfinger = <MAILQ>) {
				print "<tr><td class='v'>$postfinger</td></tr>"
				if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
			} 
			close(MAILQ);
			print "<tr><td> </td></tr>";
		}
		open(MAILQ, "/bin/ls -ld `$config{'postfix_config_command'} -h queue_directory`/private 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
			print "<tr><td class='v'>$postfinger</td></tr>"
			if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
		} 
		close(MAILQ);
		print "<tr><td> </td></tr>";
		if (! open(MAILQ, "/bin/ls -l `$config{'postfix_config_command'} -h queue_directory`/private 2>/dev/null |")) {
		        print '<center><b>WARNING: No access to $queue_directory/private<br>Try running postfinger as user root or postfix</b></center><br>';
		} else {
			while (my $postfinger = <MAILQ>) {
				print "<tr><td class='v'>$postfinger</td></tr>"
				if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
			} 
			close(MAILQ);
			print "<tr><td> </td></tr>";
		}
		open(MAILQ, "/bin/ls -l `$config{'postfix_config_command'} -h command_directory`/postdrop 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
			print "<tr><td class='v'>$postfinger</td></tr>"
			if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
		} 
		close(MAILQ);
		print "<tr><td> </td></tr>";
		open(MAILQ, "/bin/ls -l `$config{'postfix_config_command'} -h command_directory`/postqueue 2>/dev/null |");
		while (my $postfinger = <MAILQ>) {
				print "<tr><td class='v'>$postfinger</td></tr>"
				if ( !grep(/total|^#|^\[ 	\]*$/,$postfinger));
		} 
		close(MAILQ);
		print "</table><br>";
	}
	if ($Libraries eq 1 ) {
		print '<h1 align="center">Library dependencies</h1>';
		print '<table border="0" cellpadding="0" width="600" align="center">';
		if (! open(MAILQ, "/usr/bin/ldd `$config{'postfix_config_command'} -h daemon_directory`/smtpd 2>/dev/null |")) {
		        print '<center><b>WARNING: Can not find ldd.  Check you have it installed and in your path</b></center><br>';
		} else {
			while (my $postfinger = <MAILQ>) {
				($postf1,$postf2)=split(/=/,$postfinger,2);
				print "<tr><td class='e'><b>$postf1</b></td>"; 
				print "<td class='v'>=$postf2</td></tr>";
			} 
			close(MAILQ);
			print "</table><br>";
		}
	}
print "</td> </tr></table></td> </tr></table>";
&footer("index.cgi", $text{'index_title'});
}

sub head {
print "<style type='text/css'><!--";
#print "body {background-color: #ffffff; color: #000000;}";
#print "body, td, th, h1, h2 {font-family: sans-serif;}";
print "pre {margin: 0px; font-family: monospace;}";
print "a:link {color: #000099; text-decoration: none;}";
print "a:hover {text-decoration: underline;}";
#print "table {border-collapse: collapse;}";
print ".center {text-align: center;}";
#print ".center table { margin-left: auto; margin-right: auto; text-align: left;}";
#print ".center th { text-align: center; !important }";
#print "td, th { border: 1px solid #000000; font-size: 75%; vertical-align: baseline;}";
print "h1 {font-size: 150%;}";
print "h2 {font-size: 125%;}";
print ".p {text-align: left;}";
print ".e {background-color: #ccccff; font-weight: bold;}";
print ".h {background-color: #9999cc; font-weight: bold;}";
print ".v {background-color: #cccccc;}";
print "i {color: #666666;}";
#print "img {float: right; border: 0px;}";
print "hr {width: 600px; align: center; background-color: #cccccc; border: 0px; height: 1px;}";
print "//--></style>";
#print "<title>Postfinger</title></head>";
#print "<body><div class='center'>";
print "<table border='0' cellpadding='3' width='600' align='center'>";
print "<tr class='h'><td>";
return;
}
