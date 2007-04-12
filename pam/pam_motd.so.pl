# display args for pam_motd.so

$module_has_no_args = 1;	# file= arg doesn't seem to work!

# display_args(&service, &module, &args)
sub display_module_args
{
print "<tr> <td><b>$text{'motd_file'}</b></td>\n";
printf "<td colspan=3><input type=radio name=file_def value=1 %s> %s\n",
	$_[2]->{'file'} ? '' : 'checked', $text{'motd_file_def'};
printf "<input type=radio name=file_def value=0 %s>\n",
	$_[2]->{'file'} ? 'checked' : '';
print "<input name=file size=30 value='$_[2]->{'file'}'> ",
      &file_chooser_button("file"),"</td> </tr>\n";
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'file_def'}) {
	delete($_[2]->{'file'});
	}
else {
	$in{'file'} =~ /^\S+$/ || &error($text{'motd_efile'});
	$_[2]->{'file'} = $in{'file'};
	}
}
