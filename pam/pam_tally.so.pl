# display args for pam_tally.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'tally_deny'}</b></td>\n";
printf "<td nowrap><input type=radio name=deny_def value=1 %s> %s\n",
	$_[2]->{'deny'} ? '' : 'checked', $text{'default'};
printf "<input type=radio name=deny_def value=0 %s>\n",
	$_[2]->{'deny'} ? 'checked' : '';
print "<input name=deny size=5 value='$_[2]->{'deny'}'></td>\n";

print "<td><b>$text{'tally_reset'}</b></td>\n";
printf "<td><input type=radio name=reset value=0 %s> %s\n",
	defined($_[2]->{'reset'}) || defined($_[2]->{'no_reset'}) ?
	'' : 'checked', $text{'default'};
printf "<input type=radio name=reset value=1 %s> %s\n",
	defined($_[2]->{'reset'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=reset value=2 %s> %s</td> </tr>\n",
	defined($_[2]->{'no_reset'}) ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'tally_magic'}</b></td>\n";
printf "<td><input type=radio name=magic value=1 %s> %s\n",
	defined($_[2]->{'no_magic_root'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=magic value=0 %s> %s</td>\n",
	defined($_[2]->{'no_magic_root'}) ? '' : 'checked', $text{'no'};

print "<td><b>$text{'tally_root'}</b></td>\n";
printf "<td><input type=radio name=root value=1 %s> %s\n",
      defined($_[2]->{'even_deny_root_account'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=root value=0 %s> %s</td> </tr>\n",
      defined($_[2]->{'even_deny_root_account'}) ? '' : 'checked', $text{'no'};
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'deny_def'}) { delete($_[2]->{'deny'}); }
else {
	$in{'deny'} =~ /^\d+$/ || &error($text{'tally_edeny'});
	$_[2]->{'deny'} = $in{'deny'};
	}

delete($_[2]->{'reset'});
delete($_[2]->{'no_reset'});
if ($in{'reset'} == 1) { $_[2]->{'reset'} = ''; }
elsif ($in{'reset'} == 2) { $_[2]->{'no_reset'} = ''; }

if ($in{'magic'}) { $_[2]->{'no_magic_root'} = ''; }
else { delete($_[2]->{'no_magic_root'}); }

if ($in{'root'}) { $_[2]->{'even_deny_root_account'} = ''; }
else { delete($_[2]->{'even_deny_root_account'}); }
}
