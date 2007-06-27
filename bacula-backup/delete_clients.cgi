#!/usr/local/bin/perl
# Delete multiple clients

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@clients = &find("Client", $conf);

&error_setup($text{'clients_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$client = &find_by("Name", $d, \@clients);
	if ($client) {
		$child = &find_dependency("Client", $d, [ "Job", "JobDefs" ], $conf);
		$child && &error(&text('client_echild', $child));
		&save_directive($conf, $parent, $client, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "clients", scalar(@d));
&redirect("list_clients.cgi");

