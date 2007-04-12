#!/usr/local/bin/perl
# start.cgi
# Start the FTP server process with flags -l -a -S

require './wuftpd-lib.pl';
&system_logged("$config{'ftpd_path'} -l -a -S >/dev/null 2>&1 </dev/null");
&webmin_log("start");
&redirect("");

