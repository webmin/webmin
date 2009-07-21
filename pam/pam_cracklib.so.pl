# display args for pam_cracklib.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'cracklib_retry'},
	&ui_opt_textbox("retry", $_[2]->{'retry'}, 5, $text{'default'}));

print &ui_table_row($text{'cracklib_type'},
	&ui_opt_textbox("type", $_[2]->{'type'}, 20, $text{'default'}));
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
