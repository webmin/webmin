
require './burner-lib.pl';

sub config_form
{
print &ui_table_row($text{'config_cdrecord'},
		    &ui_textbox("cdrecord", $_[0]->{'cdrecord'}, 30)." ".
		    &file_chooser_button("cdrecord"));

print &ui_table_row($text{'config_mkisofs'},
		    &ui_textbox("mkisofs", $_[0]->{'mkisofs'}, 30)." ".
		    &file_chooser_button("mkisofs"));

print &ui_table_row($text{'config_mpg123'},
		    &ui_textbox("mpg123", $_[0]->{'mpg123'}, 30)." ".
		    &file_chooser_button("mpg123"));

print &ui_table_row($text{'config_sox'},
		    &ui_textbox("sox", $_[0]->{'sox'}, 30)." ".
		    &file_chooser_button("sox"));

print &ui_table_row($text{'config_cdrdao'},
		    &ui_textbox("cdrdao", $_[0]->{'cdrdao'}, 30)." ".
		    &file_chooser_button("cdrdao"));

print &ui_table_row($text{'config_temp'},
		    &ui_opt_textbox("temp", $_[0]->{'temp'}, 30,
				    $text{'config_temp_def'}));
}

sub config_save
{
&has_command($in{'cdrecord'}) || &error($text{'config_ecdrecord'});
$_[0]->{'cdrecord'} = $in{'cdrecord'};

#&has_command($in{'mkisofs'}) || &error($text{'config_emkisofs'});
$_[0]->{'mkisofs'} = $in{'mkisofs'};

#&has_command($in{'mpg123'}) || &error($text{'config_empg123'});
$_[0]->{'mpg123'} = $in{'mpg123'};

#&has_command($in{'sox'}) || &error($text{'config_esox'});
$_[0]->{'sox'} = $in{'sox'};

#&has_command($in{'cdrdao'}) || &error($text{'config_ecdrdao'});
$_[0]->{'cdrdao'} = $in{'cdrdao'};

if ($in{'temp_def'}) {
	$_[0]->{'temp'} = undef;
	}
else {
	-d $in{'temp'} || &error($text{'config_etemp'});
	$_[0]->{'temp'} = $in{'temp'};
	}
}

