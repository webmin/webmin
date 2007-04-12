#!/usr/local/bin/perl
# Remove some servers from the managed list

require './bind8-lib.pl';
$access{'slaves'} || &error($text{'slaves_ecannot'});
&ReadParse();
&foreign_require("servers", "servers-lib.pl");
@servers = &list_slave_servers();

@d = split(/\0/, $in{'d'});
foreach $id (@d) {
	($server) = grep { $_->{'id'} == $id } @servers;
	&delete_slave_server($server);
	}
if (@d == 1) {
	&webmin_log("delete", "host", $server->{'host'});
	}
else {
	&webmin_log("delete", "group", scalar(@d));
	}
&redirect("list_slaves.cgi");

