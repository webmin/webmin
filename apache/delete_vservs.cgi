#!/usr/local/bin/perl
# Delete a bunch of virtual servers

require './apache-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
$access{'vaddr'} || &error($text{'delete_ecannot'});
$conf = &get_config();
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Get them all
foreach $d (@d) {
	($vmembers, $vconf) = &get_virtual_config($d);
	&can_edit_virt($vconf) || &error(&text('delete_ecannot2',
					       &virtual_name($vconf)));
	push(@virts, $vconf);
	}

# Delete their structures
&before_changing();
foreach $vconf (@virts) {
	&lock_file($vconf->{'file'});
	&save_directive_struct($vconf, undef, $conf, $conf);
	&delete_file_if_empty($vconf->{'file'});
	}
&flush_file_lines();
&unlock_all_files();
&after_changing();
&webmin_log("virts", "delete", scalar(@virts));
&redirect("");

