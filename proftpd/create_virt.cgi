#!/usr/local/bin/perl
# create_virt.cgi
# Create a new virtual server

require './proftpd-lib.pl';
&ReadParse();
$conf = &get_config();
&error_setup($text{'vserv_err'});

# Validate inputs
$in{'addr_def'} || &to_ipaddress($in{'addr'}) ||
    &to_ip6address($in{'addr'}) ||
	&error($text{'vserv_eaddr'});
$in{'Port_def'} || $in{'Port'} =~ /^\d+$/ ||
	&error($text{'vserv_eport'});
$in{'ServerName_def'} || $in{'ServerName'} =~ /\S/ ||
	&error($text{'vserv_ename'});

# Add the virtual host
$l = $conf->[@$conf - 1];
$addfile = $config{'add_file'} || $l->{'file'};
&lock_file($addfile);
&before_changing();
$lref = &read_file_lines($addfile);
@lines = ( "<VirtualHost $in{'addr'}>" );
push(@lines, "Port $in{'Port'}") if (!$in{'Port_def'});
push(@lines, "ServerName \"$in{'ServerName'}\"") if (!$in{'ServerName_def'});
push(@lines, "</VirtualHost>");
push(@$lref, @lines);
&flush_file_lines($addfile);
&after_changing();
&unlock_file($addfile);
&webmin_log("virt", "create", $in{'addr'}, \%in);

&redirect("virt_index.cgi?virt=".scalar(@$conf));

