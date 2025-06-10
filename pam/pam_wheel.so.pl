# display args for pam_wheel.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'wheel_group'},
	&ui_opt_textbox("group", $_[2]->{'group'}, 8, $text{'wheel_group_def'}).
	" ".&group_chooser_button("group"), 3);

print &ui_table_row($text{'wheel_trust'},
	&ui_yesno_radio("trust", defined($_[2]->{'trust'}) ? 1 : 0));

print &ui_table_row($text{'wheel_deny'},
	&ui_yesno_radio("deny", defined($_[2]->{'deny'}) ? 1 : 0));
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
