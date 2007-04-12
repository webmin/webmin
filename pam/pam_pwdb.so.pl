# display args for pam_pwdb.so

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'pwdb_shadow'}</b></td>\n";
printf "<td><input type=radio name=shadow value=1 %s> %s\n",
	defined($_[2]->{'shadow'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=shadow value=0 %s> %s</td>\n",
	defined($_[2]->{'shadow'}) ? '' : 'checked', $text{'no'};

print "<td><b>$text{'pwdb_nullok'}</b></td>\n";
printf "<td><input type=radio name=nullok value=1 %s> %s\n",
	defined($_[2]->{'nullok'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=nullok value=0 %s> %s</td> </tr>\n",
	defined($_[2]->{'nullok'}) ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'pwdb_md5'}</b></td>\n";
printf "<td><input type=radio name=md5 value=1 %s> %s\n",
	defined($_[2]->{'md5'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=md5 value=0 %s> %s</td>\n",
	defined($_[2]->{'md5'}) ? '' : 'checked', $text{'no'};

print "<td><b>$text{'pwdb_nodelay'}</b></td>\n";
printf "<td><input type=radio name=nodelay value=0 %s> %s\n",
	defined($_[2]->{'nodelay'}) ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=nodelay value=1 %s> %s</td> </tr>\n",
	defined($_[2]->{'nodelay'}) ? 'checked' : '', $text{'no'};
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'shadow'}) { $_[2]->{'shadow'} = ""; }
else { delete($_[2]->{'shadow'}); }

if ($in{'nullok'}) { $_[2]->{'nullok'} = ""; }
else { delete($_[2]->{'nullok'}); }

if ($in{'md5'}) { $_[2]->{'md5'} = ""; }
else { delete($_[2]->{'md5'}); }

if ($in{'nodelay'}) { $_[2]->{'nodelay'} = ""; }
else { delete($_[2]->{'nodelay'}); }
}
