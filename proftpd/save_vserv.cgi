#!/usr/local/bin/perl
# save_vserv.cgi
# Save virtual server options such as the port and address

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_config();
$vconf = $conf->[$in{'virt'}];

if ($in{'delete'}) {
	# Delete a virtual server
	&lock_file($vconf->{'file'});
	&before_changing();
	$lref = &read_file_lines($vconf->{'file'});
	splice(@$lref, $vconf->{'line'},
	       $vconf->{'eline'} - $vconf->{'line'} + 1);
	&flush_file_lines();
	&after_changing();
	&unlock_file($vconf->{'file'});
	&webmin_log("virt", "delete", $vconf->{'value'});
	&redirect("");
	}
else {
	# Update virtual server and directives
	&error_setup($text{'vserv_err'});

	# Check inputs
	&to_ipaddress($in{'addr'}) || &to_ip6address($in{'addr'}) ||
		&error($text{'vserv_eaddr'});
	$in{'Port_def'} || $in{'Port'} =~ /^\d+$/ ||
		&error($text{'vserv_eport'});
	$in{'ServerName_def'} || $in{'ServerName'} =~ /\S/ ||
		&error($text{'vserv_ename'});

	# Update <VirtualHost> directive
	&lock_file($vconf->{'file'});
	&before_changing();
	$lref = &read_file_lines($vconf->{'file'});
	$lref->[$vconf->{'line'}] = "<VirtualHost $in{'addr'}>";

	# Update DocumentRoot and ServerName
	&save_directive("ServerName", $in{'ServerName_def'} ? [ ] :
				      [ "\"$in{'ServerName'}\"" ], 
			$vconf->{'members'}, $conf);
	&save_directive("Port", $in{'Port_def'} ? [ ] : [ $in{'Port'} ],
			$vconf->{'members'}, $conf);

	# write out file
	&flush_file_lines();
	&after_changing();
	&unlock_file($vconf->{'file'});
	&webmin_log("virt", "save", $vconf->{'value'}, \%in);
	&redirect("virt_index.cgi?virt=$in{'virt'}");
	}

