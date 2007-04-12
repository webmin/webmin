#!/usr/local/bin/perl
# dns_boot.cgi
# Create an empty named.boot file and start the name server

require './dns-lib.pl';
$whatfailed = "Download failed";
&ReadParse();
$config{'named_boot_file'} =~ /^(\/[^\/]+)/;
$named_boot_directory = $1;

&lock_file($config{'named_boot_file'});
&lock_file("$named_boot_directory/db.cache");
$boot_temp = &transname("webmin.named.boot");
open(BOOT, "> $boot_temp");
print BOOT "directory $named_boot_directory\n";
if ($in{real} == 0) {
	# Create an empty root domain file... no need to do anything here
	}
elsif ($in{real} == 1) {
	# Try to download the root servers file from
	# ftp://rs.internic.net/domain/named.root
	&ftp_download("rs.internic.net", "/domain/named.root", 
		      "$named_boot_directory/db.cache");
	print BOOT "cache\t\t.\tdb.cache\n";
	}
elsif ($in{real} == 2) {
	# Use builtin db.cache
	system("cp ./db.cache $named_boot_directory/db.cache 2>/dev/null");
	print BOOT "cache\t\t.\tdb.cache\n";
	}
close(BOOT);
system("cp $boot_temp $config{'named_boot_file'} 2>/dev/null");
unlink($boot_temp);
&unlock_file($config{'named_boot_file'});
&unlock_file("$named_boot_directory/db.cache");
&system_logged("$config{'named_pathname'} >/dev/null 2>/dev/null </dev/null");
&webmin_log("boot");
redirect("");


