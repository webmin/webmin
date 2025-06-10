#!/usr/local/bin/perl
# Update all node groups

$no_acl_check++;
require './bacula-backup-lib.pl';
exit if (!&has_node_groups());
$conf = &get_director_config();
$parent = &get_director_config_parent();
@nodegroups = &list_node_groups();

&lock_file($parent->{'file'});
foreach $nodegroup (@nodegroups) {
	&sync_group_clients($nodegroup);
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});

