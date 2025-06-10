#!/usr/local/bin/perl
# Delete group backup jobs

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@jobs = &find("JobDefs", $conf);

@nodegroups = &list_node_groups();

&error_setup($text{'gjobs_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$job = &find_by("Name", "ocjob_".$d, \@jobs);
	if ($job) {
		$client = &find_value("Client", $job->{'members'});
		&save_directive($conf, $parent, $job, undef, 0);

		($nodegroup) = grep { $_->{'name'} eq $client } @nodegroups;
		if ($nodegroup) {
			&sync_group_clients($nodegroup);
			}
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "gjobs", scalar(@d));
&redirect("list_gjobs.cgi");

