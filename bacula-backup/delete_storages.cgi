#!/usr/local/bin/perl
# Delete multiple storage devices

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@storages = &find("Storage", $conf);

&error_setup($text{'storages_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$storage = &find_by("Name", $d, \@storages);
	if ($storage) {
		$child = &find_dependency("Storage", $d, [ "Job", "JobDefs" ], $conf);
		$child && &error(&text('storage_echild', $child));
		&save_directive($conf, $parent, $storage, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "storages", scalar(@d));
&redirect("list_storages.cgi");

