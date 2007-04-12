#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
#
# Save, modify, delete an alias for Postfix


require './postfix-lib.pl';
&ReadParse();

$access{'aliases'} || &error($text{'aliases_ecannot'});
&error_setup($text{'alias_save_err'});

# Get the alias (if editing or deleting)
@afiles = &get_aliases_files(&get_current_value("alias_maps"));
@aliases = &list_aliases(\@afiles);
if (!$in{'new'}) {
	$a = $aliases[$in{'num'}];
	}
&lock_alias_files(\@afiles);

if ($in{'delete'}) {
	# delete some alias
	&delete_alias($a, \@afiles);
	$loga = $a;
	}
else {
	# saving or creating .. check inputs
	$in{'name'} =~ /^[^:@ ]+$/ ||
		&error(&text('asave_eaddr', $in{'name'}));
	if ($in{'new'} || uc($a->{'name'}) ne uc($in{'name'})) {
		# is this name taken?
		for($i=0; $i<@aliases; $i++) {
			if (uc($in{'name'}) eq uc($aliases[$i]->{'name'})) {
				&error(&text('asave_ealready', $in{'name'}));
				}
			}
		}
	for($i=0; defined($t = $in{"type_$i"}); $i++) {
		$v = $in{"val_$i"};
		$v =~ s/^\s+//;
		$v =~ s/\s+$//;
		if ($t == 1 && $v !~ /^(\S+)$/) {
			&error(&text('asave_etype1', $v));
			}
		elsif ($t == 3 && $v !~ /^\/(\S+)$/) {
			&error(&text('asave_etype3', $v));
			}
		elsif ($t == 4) {
			$v =~ /^(\S+)/ || &error($text{'asave_etype4none'});
			-x $1 || &error(&text('asave_etype4', $1));
			}
		elsif ($t == 5 && $v !~ /^\/(\S+)$/) {
			&error(&text('asave_etype5', $v));
			}
		elsif ($t == 6 && $v !~ /^\/(\S+)$/) {
			&error(&text('asave_etype6', $v));
			}
		if ($t == 1 || $t == 3) { push(@values, $v); }
		elsif ($t == 2) { push(@values, ":include:$v"); }
		elsif ($t == 4) { push(@values, "|$v"); }
		elsif ($t == 5) {
			# Setup autoreply script
			push(@values, "|$module_config_directory/autoreply.pl ".
				      "$v $in{'name'}");
			&system_logged("cp autoreply.pl $module_config_directory");
			&system_logged("chmod 755 $module_config_directory/config");
			}
		elsif ($t == 6) {
			# Setup filter script
			push(@values, "|$module_config_directory/filter.pl ".
				      "$v $in{'name'}");
			&system_logged("cp filter.pl $module_config_directory");
			&system_logged("chmod 755 $module_config_directory/config");
			}
		}

	$newa{'name'} = $in{'name'};
	$newa{'values'} = \@values;
	$newa{'cmt'} = $in{'cmt'};
	$newa{'enabled'} = $in{'enabled'};
	if ($in{'new'}) { &create_alias(\%newa, \@afiles, 1); }
	else { &modify_alias($a, \%newa, 1); }
	$loga = \%newa;
	}
&unlock_alias_files(\@afiles);

# re-creates aliases database
&regenerate_aliases();
&reload_postfix();

&webmin_log($in{'new'} ? 'create' : $in{'delete'} ? 'delete' : 'modify',
	    'alias', $loga->{'name'}, $loga);
&redirect("aliases.cgi");




