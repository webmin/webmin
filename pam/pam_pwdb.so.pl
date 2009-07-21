# display args for pam_pwdb.so

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'pwdb_shadow'},
	&ui_yesno_radio("shadow", defined($_[2]->{'shadow'}) ? 1 : 0));

print &ui_table_row($text{'pwdb_nullok'},
	&ui_yesno_radio("nullok", defined($_[2]->{'nullok'}) ? 1 : 0));

print &ui_table_row($text{'pwdb_md5'},
	&ui_yesno_radio("md5", defined($_[2]->{'md5'}) ? 1 : 0));

print &ui_table_row($text{'pwdb_nodelay'},
	&ui_radio("md5", defined($_[2]->{'nodelay'}) ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));
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
