#!/usr/local/bin/perl
# Delete multiple mappings

require './postfix-lib.pl';    ## no critic
use strict;
use warnings;
our ($err, $map, $maps, @d, %access, %in, %text);
&ReadParse();
&error_setup($text{'delete_err'});
&can_edit_map($in{'map_name'}) || &error($text{'chooser_ecannot'});

@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Check all map paths before deleting any entries.
foreach my $file (&get_maps_files(&get_real_value($in{'map_name'}))) {
	&is_under_directory($access{'dir'}, $file) ||
		&error(&text('mapping_ecannot', $access{'dir'}));
	}
$maps = &get_maps($in{'map_name'});
foreach my $d (@d) {
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
