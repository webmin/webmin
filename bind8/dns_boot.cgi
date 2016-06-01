#!/usr/local/bin/perl
# dns_boot.cgi
# Create an empty named.conf file and start the name server
use strict;
use warnings;
our (%text, %config, %in);

require './bind8-lib.pl';
&error_setup($text{'boot_err'});
&ReadParse();

$config{'named_conf'} =~ /^(\S+)\/([^\/]+)$/;
my $conf_directory = $1;
my $pid_file = $config{'pid_file'} || "/var/run/named.pid";
&lock_file(&make_chroot($config{'named_conf'}));
&lock_file(&make_chroot("$conf_directory/db.cache"));
my $conf_temp = &transname("webmin.named.conf");
open(my $BOOT, ">", $conf_temp);
print $BOOT "options {\n";
print $BOOT "\tdirectory \"$conf_directory\";\n";
print $BOOT "\tpid-file \"$pid_file\";\n";
print $BOOT "\t};\n";
print $BOOT "\n";
my $chroot = &get_chroot();
if ($chroot && !-d $chroot) {
	mkdir($chroot, 0755);
	}
if (!-d &make_chroot($conf_directory)) {
	mkdir(&make_chroot($conf_directory), 0755);
	}
if ($config{'master_dir'} && !-d &make_chroot($config{'master_dir'})) {
	mkdir(&make_chroot($config{'master_dir'}), 0755);
	}
if ($config{'slave_dir'} && !-d &make_chroot($config{'slave_dir'})) {
	mkdir(&make_chroot($config{'slave_dir'}), 0777);
	}
if ($pid_file =~ /^(.*)\//) {
	my $pid_dir = $1;
	if (!-d &make_chroot($pid_dir)) {
		mkdir(&make_chroot($pid_dir), 0777);
		}
	}
if (!-r &make_chroot($pid_file)) {
	my $PID;
	&open_tempfile($PID, ">", &make_chroot($pid_file));
	&close_tempfile($PID);
	&set_ownership(&make_chroot($pid_file));
	}
if ($in{real} == 0) {
	# Create an empty root domain file... no need to do anything here
	}
elsif ($in{real} == 1) {
	# Try to download the root servers file from
	# ftp://rs.internic.net/domain/named.root
	my $err = &download_root_zone("$conf_directory/db.cache");
	&error($err) if ($err);
	print $BOOT "zone \".\" {\n";
	print $BOOT "\ttype hint;\n";
	print $BOOT "\tfile \"$conf_directory/db.cache\";\n";
	print $BOOT "\t};\n";
	print $BOOT "\n";
	}
elsif ($in{real} == 2) {
	# Use builtin db.cache
	&execute_command("cp ./db.cache ".&make_chroot("$conf_directory/db.cache"));
	print $BOOT "zone \".\" {\n";
	print $BOOT "\ttype hint;\n";
	print $BOOT "\tfile \"$conf_directory/db.cache\";\n";
	print $BOOT "\t};\n";
	print $BOOT "\n";
	}
close($BOOT);
&copy_source_dest($conf_temp, &make_chroot($config{'named_conf'}));
unlink($conf_temp);
&unlock_file(&make_chroot("$conf_directory/db.cache"));
&unlock_file(&make_chroot($config{'named_conf'}));
&set_ownership(&make_chroot("$conf_directory/db.cache"))
	if ($in{'real'} == 2 || $in{'real'} == 1);
&set_ownership(&make_chroot($config{'named_conf'}));
&webmin_log("boot");
&redirect("start.cgi");

