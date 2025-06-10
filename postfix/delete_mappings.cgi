#!/usr/local/bin/perl
# Delete multiple mappings

require './postfix-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});

@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

$maps = &get_maps($in{'map_name'});
foreach $d (@d) {
	($map) = grep { $_->{'name'} eq $d } @$maps;
	if ($map) {
		&lock_file($map->{'file'});
	        &delete_mapping($in{'map_name'}, $map);
		}
	}
&unlock_all_files();

&regenerate_map_table($in{'map_name'});
$err = &reload_postfix();
&error($err) if ($err);

&webmin_log("delete", $in{'map_name'}.'s', scalar(@d));
&redirect_to_map_list($in{'map_name'});
