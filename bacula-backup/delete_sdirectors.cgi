#!/usr/local/bin/perl
# Delete multiple storage daemon directors

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_storage_config();
$parent = &get_storage_config_parent();
@sdirectors = &find("Director", $conf);

&error_setup($text{'sdirectors_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$sdirector = &find_by("Name", $d, \@sdirectors);
	if ($sdirector) {
		&save_directive($conf, $parent, $sdirector, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "sdirectors", scalar(@d));
&redirect("list_sdirectors.cgi");

