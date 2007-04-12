# display args for pam_cracklib.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'cracklib_retry'}</b></td>\n";
printf "<td><input type=radio name=retry_def value=1 %s> %s\n",
	$_[2]->{'retry'} ? '' : 'checked', $text{'default'};
printf "<input type=radio name=retry_def value=0 %s>\n",
	$_[2]->{'retry'} ? 'checked' : '';
print "<input name=retry size=5 value='$_[2]->{'retry'}'></td>\n";

print "<td><b>$text{'cracklib_type'}</b></td>\n";
printf "<td><input type=radio name=type_def value=1 %s> %s\n",
	$_[2]->{'type'} ? '' : 'checked', $text{'default'};
printf "<input type=radio name=type_def value=0 %s>\n",
	$_[2]->{'type'} ? 'checked' : '';
print "<input name=type size=20 value='$_[2]->{'type'}'></td> </tr>\n";
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'retry_def'}) { delete($_[2]->{'retry'}); }
else {
	$in{'retry'} =~ /^\d+$/ || &error($text{'cracklib_eretry'});
	$_[2]->{'retry'} = $in{'retry'};
	}

if ($in{'type_def'}) { delete($_[2]->{'type'}); }
else {
	$in{'type'} =~ /^\S+$/ || &error($text{'cracklib_etype'});
	$_[2]->{'type'} = $in{'type'};
	}
}
