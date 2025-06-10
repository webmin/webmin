#!/usr/local/bin/perl
# Delete multiple filesets

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@filesets = &find("FileSet", $conf);

&error_setup($text{'filesets_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$fileset = &find_by("Name", $d, \@filesets);
	if ($fileset) {
		$child = &find_dependency("FileSet", $d, [ "Job", "JobDefs" ], $conf);
		$child && &error(&text('fileset_echild', $child));
		&save_directive($conf, $parent, $fileset, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "filesets", scalar(@d));
&redirect("list_filesets.cgi");

