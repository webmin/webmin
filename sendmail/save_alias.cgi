#!/usr/local/bin/perl
# save_alias.cgi
# Save or delete a new or existing alias

require './sendmail-lib.pl';
require './aliases-lib.pl';
&ReadParse();
&error_setup($text{'asave_err'});
$access{'amode'} > 0 || &error($text{'asave_ecannot2'});
$conf = &get_sendmailcf();
$afile = &aliases_file($conf);
&lock_alias_files($afile);
@aliases = &list_aliases($afile);
foreach $ex (@aliases) { $exists{lc($ex->{'name'})}++; }
if (!$in{'new'}) {
	$a = $aliases[$in{'num'}];
	&can_edit_alias($a) || &error($text{'asave_ecannot'});
	}
elsif ($access{'amax'}) {
	local @cliases = grep { local $rv = 1;
		  foreach $v (@{$_->{'values'}}) {
			$rv = 0 if (!$access{"aedit_".&alias_type($v)});
			}
		  $rv;
		} @aliases;
	if ($access{'amode'} == 2) {
		@cliases = grep { $_->{'name'} =~ /$access{'aliases'}/ }
				@aliases;
		}
	elsif ($access{'amode'} == 3) {
		@cliases = grep { $_->{'name'} eq $remote_user } @aliases;
		}
	&error(&text('asave_emax', $access{'amax'}))
		if (@caliases >= $access{'amax'});
	}

if ($in{'delete'}) {
	# delete some alias
	$loga = $a;
	&delete_alias($a);
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
	if ($access{'amode'} == 2) {
		$in{'name'} =~ /$access{'aliases'}/ ||
			&error(&text('asave_ematch', $access{'aliases'}));
		}
	elsif ($access{'amode'} == 3) {
		$in{'name'} eq $remote_user || &error($text{'asave_esame'});
		}
	for($i=0; defined($t = $in{"type_$i"}); $i++) {
		!$t || $access{"aedit_$t"} ||
			&error($text{'asave_etype'});
		$v = $in{"val_$i"};
		$v =~ s/^\s+//;
		$v =~ s/\s+$//;
		if ($t == 1 && $v !~ /^([^\|\:\"\' \t\/\\\%]\S*)$/) {
			&error(&text('asave_etype1', $v));
			}
		elsif ($t == 2 && !&check_aliasfile($v, 1)) {
			&error(&text('asave_etype2', $v));
			}
		elsif ($t == 3 && $v !~ /^\/(\S+)$/) {
			&error(&text('asave_etype3', $v));
			}
		elsif ($t == 4) {
			$v =~ /^'([^']+)'/ || $v =~ /^"([^"]+)"/ ||
			   $v =~ /^(\S+)/ || &error($text{'asave_etype4none'});
			(-x $1) && &check_aliasfile("$1", 0) ||
				&error(&text('asave_etype4', "$1"));
			}
		elsif ($t == 5 && !&check_aliasfile($v, 1)) {
			&error(&text('asave_etype5', $v));
			}
		elsif ($t == 6 && !&check_aliasfile($v, 1)) {
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
			&system_logged("chmod 755 $module_config_directory/config $module_config_directory/autoreply.pl");
			if (-d $config{'smrsh_dir'}) {
				&system_logged("ln -s $module_config_directory/autoreply.pl $config{'smrsh_dir'}/autoreply.pl");
				}
			}
		elsif ($t == 6) {
			# Setup filter script
			push(@values, "|$module_config_directory/filter.pl ".
				      "$v $in{'name'}");
			&system_logged("cp filter.pl $module_config_directory");
			&system_logged("chmod 755 $module_config_directory/config $module_config_directory/filter.pl");
			if (-d $config{'smrsh_dir'}) {
				&system_logged("ln -s $module_config_directory/filter.pl $config{'smrsh_dir'}/filter.pl");
				}
			}
		}

	$newa{'name'} = $in{'name'};
	$newa{'values'} = \@values;
	$newa{'enabled'} = $in{'enabled'};
	$newa{'cmt'} = $in{'cmt'};
	if ($in{'new'}) {
		$newa{'file'} = $in{'afile'};
		}

	# Actually create or update
	if ($in{'new'}) {
		&create_alias(\%newa, $afile);
		}
	else {
		&modify_alias($a, \%newa);
		}
	$loga = \%newa;
	}
&unlock_alias_files($afile);
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    "alias", $loga->{'name'}, $loga);
&redirect("list_aliases.cgi");

# check_aliasfile(program, missing-ok)
sub check_aliasfile
{
return 0 if ($_[0] !~ /^\/(\S+)$/);
return 0 if (!-r $_[0] && !$_[1]);
return &is_under_directory($access{'apath'}, $_[0]);
}

