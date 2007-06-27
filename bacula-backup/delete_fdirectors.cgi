#!/usr/local/bin/perl
# Delete multiple fdirector devices

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_file_config();
$parent = &get_file_config_parent();
@fdirectors = &find("Director", $conf);

&error_setup($text{'fdirectors_derr'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'filesets_ednone'});

&lock_file($parent->{'file'});
foreach $d (@d) {
	$fdirector = &find_by("Name", $d, \@fdirectors);
	if ($fdirector) {
		&save_directive($conf, $parent, $fdirector, undef, 0);
		}
	}
&flush_file_lines($parent->{'file'});
&unlock_file($parent->{'file'});
&webmin_log("delete", "fdirectors", scalar(@d));
&redirect("list_fdirectors.cgi");

