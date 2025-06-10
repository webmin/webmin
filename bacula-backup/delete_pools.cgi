#!/usr/local/bin/perl
# Delete multiple pool devices

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@pools = &find("Pool", $conf);

&error_setup($text{'pools_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$pool = &find_by("Name", $d, \@pools);
	if ($pool) {
		$child = &find_dependency("Pool", $d, [ "Job", "JobDefs" ], $conf);
		$child && &error(&text('pool_echild', $child));
		&save_directive($conf, $parent, $pool, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "pools", scalar(@d));
&redirect("list_pools.cgi");

