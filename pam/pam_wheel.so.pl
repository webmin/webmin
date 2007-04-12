# display args for pam_wheel.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'wheel_group'}</b></td>\n";
printf "<td colspan=3><input type=radio name=group_def value=1 %s> %s\n",
	$_[2]->{'group'} ? '' : 'checked', $text{'wheel_group_def'};
printf "<input type=radio name=group_def value=0 %s>\n",
	$_[2]->{'group'} ? 'checked' : '';
print "<input name=group size=8 value='$_[2]->{'group'}'> ",
      &group_chooser_button("group"),"</td> </tr>\n";

print "<tr> <td><b>$text{'wheel_trust'}</b></td>\n";
printf "<td><input type=radio name=trust value=1 %s> %s\n",
	defined($_[2]->{'trust'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=trust value=0 %s> %s</td>\n",
	defined($_[2]->{'trust'}) ? '' : 'checked', $text{'no'};

print "<td><b>$text{'wheel_deny'}</b></td>\n";
printf "<td><input type=radio name=deny value=1 %s> %s\n",
	defined($_[2]->{'deny'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=deny value=0 %s> %s</td> </tr>\n",
	defined($_[2]->{'deny'}) ? '' : 'checked', $text{'no'};
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'trust'}) { $_[2]->{'trust'} = ''; }
else { delete($_[2]->{'trust'}); }

if ($in{'deny'}) { $_[2]->{'deny'} = ''; }
else { delete($_[2]->{'deny'}); }

if ($in{'group_def'}) { delete($_[2]->{'group'}); }
else {
	defined(getgrnam($in{'group'})) || &error($text{'wheel_egroup'});
	$_[2]->{'group'} = $in{'group'};
	}
}
