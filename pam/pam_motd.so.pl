# display args for pam_motd.so

$module_has_no_args = 1;	# file= arg doesn't seem to work!

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'motd_file'},
	&ui_opt_textbox("file", $_[2]->{'file'}, 40, $text{'motd_file_def'}).
	" ".&file_chooser_button("file"), 3);
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
