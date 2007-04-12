# display args for pam_mail.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'mail_nopen'}</b></td>\n";
printf "<td><input type=radio name=nopen value=0 %s> %s\n",
	defined($_[2]->{'nopen'}) ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=nopen value=1 %s> %s</td>\n",
	defined($_[2]->{'nopen'}) ? 'checked' : '', $text{'no'};

print "<td><b>$text{'mail_close'}</b></td>\n";
printf "<td><input type=radio name=close value=1 %s> %s\n",
	defined($_[2]->{'close'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=close value=0 %s> %s</td> </tr>\n",
	defined($_[2]->{'close'}) ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'mail_empty'}</b></td>\n";
printf "<td><input type=radio name=empty value=1 %s> %s\n",
	defined($_[2]->{'empty'}) ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=empty value=0 %s> %s</td>\n",
	defined($_[2]->{'empty'}) ? '' : 'checked', $text{'no'};

print "<td><b>$text{'mail_noenv'}</b></td>\n";
printf "<td><input type=radio name=noenv value=0 %s> %s\n",
	defined($_[2]->{'noenv'}) ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=noenv value=1 %s> %s</td> </tr>\n",
	defined($_[2]->{'noenv'}) ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'mail_dir'}</b></td>\n";
printf "<td colspan=3><input type=radio name=dir_def value=1 %s> %s\n",
	$_[2]->{'dir'} ? '' : 'checked', $text{'default'};
printf "<input type=radio name=dir_def value=0 %s> %s\n",
	$_[2]->{'dir'} ? 'checked' : '';
print "<input name=dir size=30 value='$_[2]->{'dir'}'> ",
      &file_chooser_button("dir"),"</td> </tr>\n";
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'nopen'}) { $_[2]->{'nopen'} = ''; }
else { delete($_[2]->{'nopen'}); }

if ($in{'close'}) { $_[2]->{'close'} = ''; }
else { delete($_[2]->{'close'}); }

if ($in{'empty'}) { $_[2]->{'empty'} = ''; }
else { delete($_[2]->{'empty'}); }

if ($in{'noenv'}) { $_[2]->{'noenv'} = ''; }
else { delete($_[2]->{'noenv'}); }

if ($in{'dir_def'}) { delete($_[2]->{'dir'}); }
else {
	-d $in{'dir'} || &error($text{'mail_edir'});
	$_[2]->{'dir'} = $in{'dir'};
	}
}

