# display args for pam_mail.so.pl

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'mail_nopen'},
	&ui_radio("noopen", defined($_[2]->{'nopen'}) ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'mail_close'},
	&ui_radio("noopen", defined($_[2]->{'close'}) ? 1 : 0,
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'mail_empty'},
	&ui_radio("noopen", defined($_[2]->{'empty'}) ? 1 : 0,
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'mail_noenv'},
	&ui_radio("noopen", defined($_[2]->{'noenv'}) ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'mail_dir'},
	&ui_opt_textbox("dir", $_[2]->{'dir'}, 50, $text{'default'})." ".
	&file_chooser_button("dir"), 3);
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

