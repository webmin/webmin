# display args for pam_tally.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'tally_deny'},
	&ui_opt_textbox("deny", $_[2]->{'deny'}, 5, $text{'default'}));

print &ui_table_row($text{'tally_reset'},
	&ui_radio("reset", defined($_[2]->{'reset'}) ? 1 :
			   defined($_[2]->{'no_reset'}) ? 2 : 0,
		  [ [ 0, $text{'default'} ],
		    [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'tally_magic'},
	&ui_yesno_radio("magic", defined($_[2]->{'no_magic_root'}) ? 1 : 0));

print &ui_table_row($text{'tally_root'},
	&ui_yesno_radio("root",
		defined($_[2]->{'even_deny_root_account'}) ? 1 : 0));
}

# parse_module_args(&service, &module, &args)
sub parse_module_args
{
if ($in{'deny_def'}) { delete($_[2]->{'deny'}); }
else {
	$in{'deny'} =~ /^\d+$/ || &error($text{'tally_edeny'});
	$_[2]->{'deny'} = $in{'deny'};
	}

delete($_[2]->{'reset'});
delete($_[2]->{'no_reset'});
if ($in{'reset'} == 1) { $_[2]->{'reset'} = ''; }
elsif ($in{'reset'} == 2) { $_[2]->{'no_reset'} = ''; }

if ($in{'magic'}) { $_[2]->{'no_magic_root'} = ''; }
else { delete($_[2]->{'no_magic_root'}); }

if ($in{'root'}) { $_[2]->{'even_deny_root_account'} = ''; }
else { delete($_[2]->{'even_deny_root_account'}); }
}
