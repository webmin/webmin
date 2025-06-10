#!/usr/local/bin/perl
# Delete multiple node groups

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@clients = &find("Client", $conf);

@nodegroups = &list_node_groups();

&error_setup($text{'groups_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$client = &find_by("Name", "ocgroup_".$d, \@clients);
	if ($client) {
		$child = &find_dependency("Client", $d, [ "Job", "JobDefs" ], $conf);
		$child && &error(&text('client_echild', $child));
		&save_directive($conf, $parent, $client, undef, 0);

		($nodegroup) = grep { $_->{'name'} eq $d } @nodegroups;
		if ($nodegroup) {
			&sync_group_clients($nodegroup);
			}
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "groups", scalar(@d));
&redirect("list_groups.cgi");

