#!/usr/local/bin/perl
# restart.cgi
# Kill all ftpd processes, and restart the FTP server with flags -l -a -S

require './wuftpd-lib.pl';
&ReadParse();
&kill_logged('TERM', $in{'pid'});
&system_logged("$config{'ftpd_path'} -l -a -S >/dev/null 2>&1 </dev/null");
&webmin_log("restart");
&redirect("");

