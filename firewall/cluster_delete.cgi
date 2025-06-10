#!/usr/local/bin/perl

# Remove some servers from the managed list

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
$access{'cluster'} || &error($text{'ecluster'});
&foreign_require("servers", "servers-lib.pl");
@servers = &list_cluster_servers();

@d = split(/\0/, $in{'d'});
foreach $id (@d) {
	($server) = grep { $_->{'id'} == $id } @servers;
	&delete_cluster_server($server);
	}
if (@d == 1) {
	&webmin_log("delete", "host", $server->{'host'});
	}
else {
	&webmin_log("delete", "group", scalar(@d));
	}

&redirect("cluster.cgi?version=${ipvx_arg}");

