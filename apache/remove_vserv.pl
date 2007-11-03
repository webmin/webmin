#!/usr/local/bin/perl
# remove_vserv.pl
# Delete an apache virtual server by server name

@ARGV == 1 || die "usage: remove_vserv.pl <servername>";

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} = "/etc/webmin";
$ENV{'WEBMIN_VAR'} = "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
require './apache-lib.pl';
$module_name eq 'apache' || die "Command must be run with full path";
$conf = &get_config();
@virts = &find_directive_struct("VirtualHost", $conf);
foreach $v (@virts) {
	local $sn = &find_directive("ServerName", $v->{'members'});
	if ($sn eq $ARGV[0]) {
		# Found the one to delete ..
		&save_directive_struct($v, undef, $conf, $conf);
		&flush_file_lines();
		print "Delete virtual server from $v->{'file'} at line ",
		      ($v->{'line'}+1),"\n";
		exit;
		}
	}
print "Failed to find virtual server\n";

