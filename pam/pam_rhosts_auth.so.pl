# display args for pam_rhosts_auth.so

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'rhosts_equiv'}</b></td>\n";
printf "<td><input type=radio name=equiv value=0 %s> $text{'yes'}\n",
	defined($_[2]->{'no_hosts_equiv'}) ? '' : 'checked';
printf "<input type=radio name=equiv value=1 %s> $text{'no'}</td>\n",
	defined($_[2]->{'no_hosts_equiv'}) ? 'checked' : '';

print "<td><b>$text{'rhosts_rhosts'}</b></td>\n";
printf "<td><input type=radio name=rhosts value=0 %s> $text{'yes'}\n",
	defined($_[2]->{'no_rhosts'}) ? '' : 'checked';
printf "<input type=radio name=rhosts value=1 %s> $text{'no'}</td> </tr>\n",
	defined($_[2]->{'no_rhosts'}) ? 'checked' : '';

print "<tr> <td><b>$text{'rhosts_promiscuous'}</b></td>\n";
printf "<td><input type=radio name=promiscuous value=1 %s> $text{'yes'}\n",
	defined($_[2]->{'promiscuous'}) ? 'checked' : '';
printf "<input type=radio name=promiscuous value=0 %s> $text{'no'}</td>\n",
	defined($_[2]->{'promiscuous'}) ? '' : 'checked';

print "<td><b>$text{'rhosts_suppress'}</b></td>\n";
printf "<td><input type=radio name=suppress value=0 %s> $text{'yes'}\n",
	defined($_[2]->{'suppress'}) ? '' : 'checked';
printf "<input type=radio name=suppress value=1 %s> $text{'no'}</td> </tr>\n",
	defined($_[2]->{'suppress'}) ? 'checked' : '';
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'equiv'}) { $_[2]->{'no_hosts_equiv'} = ''; }
else { delete($_[2]->{'no_hosts_equiv'}); }

if ($in{'rhosts'}) { $_[2]->{'no_rhosts'} = ''; }
else { delete($_[2]->{'no_rhosts'}); }

if ($in{'promiscuous'}) { $_[2]->{'promiscuous'} = ''; }
else { delete($_[2]->{'promiscuous'}); }

if ($in{'suppress'}) { $_[2]->{'suppress'} = ''; }
else { delete($_[2]->{'suppress'}); }
}
