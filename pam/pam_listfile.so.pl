# display args for pam_listfile.so

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'listfile_item'}</b></td>\n";
print "<td><select name=item>\n";
foreach $i ('user', 'tty', 'rhost', 'ruser', 'group', 'shell') {
	printf "<option value='%s' %s>%s\n",
		$i, $_[2]->{'item'} eq $i ? 'selected' : '',
		$text{'listfile_item_'.$i};
	}
print "</select></td>\n";

print "<td><b>$text{'listfile_sense'}</b></td>\n";
printf "<td><input type=radio name=sense value=allow %s> %s\n",
	$_[2]->{'sense'} eq 'allow' ? 'checked' : '', $text{'listfile_succeed'};
printf "<input type=radio name=sense value=deny %s> %s</td> </tr>\n",
	$_[2]->{'sense'} eq 'allow' ? '' : 'checked', $text{'listfile_fail'};

print "<tr> <td><b>$text{'listfile_file'}</b></td>\n";
print "<td colspan=3><input name=file size=50 value='$_[2]->{'file'}'> ",
      &file_chooser_button("file"),"</td> </tr>\n";

print "<tr> <td><b>$text{'listfile_onerr'}</b></td>\n";
printf "<td><input type=radio name=onerr value=fail %s> %s\n",
	$_[2]->{'onerr'} eq 'fail' ? 'checked' : '', $text{'listfile_fail'};
printf "<input type=radio name=onerr value=succeed %s> %s</td>\n",
	$_[2]->{'onerr'} eq 'fail' ? '' : 'checked', $text{'listfile_succeed'};

local $mode = $_[2]->{'apply'} =~ /^\@/ ? 2 :
	      $_[2]->{'apply'} ? 1 : 0;
print "<td><b>$text{'listfile_apply'}</b></td>\n";
printf "<td><input type=radio name=apply_mode value=0 %s> %s\n",
	$mode == 0 ? 'checked' : '', $text{'listfile_all'};
printf "<input type=radio name=apply_mode value=1 %s> %s %s\n",
	$mode == 1 ? 'checked' : '', $text{'listfile_user'},
	&unix_user_input("apply_user", $mode == 1 ? $_[2]->{'apply'} : "");
printf "<input type=radio name=apply_mode value=2 %s> %s %s</td> </tr>\n",
	$mode == 2 ? 'checked' : '', $text{'listfile_group'},
	&unix_group_input("apply_group", $mode == 2 ?
		substr($_[2]->{'apply'}, 1) : "");
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
$_[2]->{'item'} = $in{'item'};
$_[2]->{'sense'} = $in{'sense'};
$_[2]->{'file'} = $in{'file'};
$_[2]->{'onerr'} = $in{'onerr'};
if ($in{'apply_mode'} == 0) {
	delete($_[2]->{'apply'});
	}
elsif ($in{'apply_mode'} == 1) {
	$_[2]->{'apply'} = $in{'apply_user'};
	}
else {
	$_[2]->{'apply'} = '@'.$in{'apply_group'};
	}
}
