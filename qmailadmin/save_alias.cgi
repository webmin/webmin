#!/usr/local/bin/perl
# save_alias.cgi
# Save or delete a new or existing alias

require './qmail-lib.pl';
&ReadParse();
&error_setup($text{'asave_err'});

@aliases = &list_aliases();
foreach $ex (@aliases) {
	$exists{lc($ex)}++;
	}
$a = &get_alias($in{'old'});

if ($in{'delete'}) {
	# delete some alias
	$loga = $a;
	&delete_alias($a);
	}
else {
	# saving or creating .. check inputs
	$in{'name'} =~ /^[^:@ ]+$/ ||
		&error(&text('asave_eaddr', $in{'name'}));
	local $n = $in{'name'};
	$n =~ s/\./:/g;
	if ($in{'virt'}) {
		$in{'virt'} =~ s/\./:/g;
		$n = $in{'virt'}.'-'.$n;
		}

	if ($in{'new'} || lc($a->{'name'}) ne lc($n)) {
		# is this name taken?
		$exists{$n} &&
			&error(&text('asave_ealready', $in{'name'}));
		}
	for($i=0; defined($t = $in{"type_$i"}); $i++) {
		$v = $in{"val_$i"};
		if ($t == 1 && $v !~ /^(\S+)$/) {
			&error(&text('asave_etype1', $v));
			}
		elsif ($t == 2 && $v !~ /^\/(\S+)[^\/\s]$/) {
			&error(&text('asave_etype2', $v));
			}
		elsif ($t == 3 && $v !~ /^\/(\S+)[^\/\s]$/) {
			&error(&text('asave_etype3', $v));
			}
		elsif ($t == 4) {
			$v =~ /^(\S+)/ || &error($text{'asave_etype4none'});
			-x $1 || &error(&text('asave_etype4', "$1"));
			}
		elsif ($t == 5 && $v !~ /^\/\S+$/) {
			&error(&text('asave_etype5', $v));
			}
		elsif ($t == 6 && $v !~ /^\/\S+$/) {
			&error(&text('asave_etype6', $v));
			}
		if ($t == 1) { push(@values, "&$v"); }
		elsif ($t == 2) { push(@values, "$v/"); }
		elsif ($t == 3) { push(@values, "$v"); }
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

	$newa{'name'} = $n;
	$newa{'values'} = \@values;
	if ($in{'new'}) { &create_alias(\%newa); }
	else { &modify_alias($a, \%newa); }
	$loga = \%newa;
	}
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "alias", $loga->{'name'}, $loga);
&redirect("list_aliases.cgi");

