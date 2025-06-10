# display args for pam_unix.so

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'pwdb_shadow'},
	&ui_yesno_radio("shadow", defined($_[2]->{'shadow'}) ? 1 : 0));

print &ui_table_row($text{'pwdb_md5'},
	&ui_yesno_radio("md5", defined($_[2]->{'md5'}) ? 1 : 0));

print &ui_table_row($text{'pwdb_nullok'},
	&ui_yesno_radio("nullok", defined($_[2]->{'nullok'}) ? 1 : 0));

print &ui_table_row($text{'unix_nullok_secure'},
	&ui_yesno_radio("nullok_secure",
			defined($_[2]->{'nullok_secure'}) ? 1 : 0));

if ($_[1]->{'type'} eq 'password') {
	# Password-change specific options
	print &ui_table_row($text{'unix_min'},
		&ui_opt_textbox("min", $_[2]->{'min'}, 5, $text{'unix_nomin'}));

	print &ui_table_row($text{'unix_max'},
		&ui_opt_textbox("max", $_[2]->{'max'}, 5, $text{'unix_nomax'}));

	print &ui_table_row($text{'unix_obscure'},
		&ui_yesno_radio("obscure",defined($_[2]->{'obscure'}) ? 1 : 0));
	}
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'nullok'}) { $_[2]->{'nullok'} = ""; }
else { delete($_[2]->{'nullok'}); }

if ($in{'nullok_secure'}) { $_[2]->{'nullok_secure'} = ""; }
else { delete($_[2]->{'nullok_secure'}); }

if ($in{'shadow'}) { $_[2]->{'shadow'} = ""; }
else { delete($_[2]->{'shadow'}); }

if ($in{'md5'}) { $_[2]->{'md5'} = ""; }
else { delete($_[2]->{'md5'}); }

if ($_[1]->{'type'} eq 'password') {
	if ($in{'min_def'}) {
		delete($_[2]->{'min'});
		}
	else {
		$in{'min'} =~ /^\d+$/ || &error($text{'unix_emin'});
		$_[2]->{'min'} = $in{'min'};
		}

	if ($in{'max_def'}) {
		delete($_[2]->{'max'});
		}
	else {
		$in{'max'} =~ /^\d+$/ || &error($text{'unix_emax'});
		$_[2]->{'max'} = $in{'max'};
		}

	if ($in{'obscure'}) { $_[2]->{'obscure'} = ""; }
	else { delete($_[2]->{'obscure'}); }
	}
}
