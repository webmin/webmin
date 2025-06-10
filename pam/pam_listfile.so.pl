# display args for pam_listfile.so

# display_args(&service, &module, &args)
sub display_module_args
{
print &ui_table_row($text{'listfile_item'},
	&ui_select("item", $_[2]->{'item'},
		[ map { [ $_, $text{'listfile_item_'.$_} ] }
		      ('user', 'tty', 'rhost', 'ruser', 'group', 'shell') ]));

print &ui_table_row($text{'listfile_sense'},
	&ui_radio("sense", $_[2]->{'sense'} || "deny",
		[ [ "allow", $text{'listfile_succeed'} ],
		  [ "deny", $text{'listfile_fail'} ] ]));

print &ui_table_row($text{'listfile_file'},
	&ui_textbox("file", $_[2]->{'file'}, 50)." ".
	&file_chooser_button("file"), 3);

print &ui_table_row($text{'listfile_onerr'},
	&ui_radio("onerr", $_[2]->{'onerr'} || "succeed",
		  [ [ "fail", $text{'listfile_fail'} ],
		    [ "success", $text{'listfile_succeed'} ] ]));

local $mode = $_[2]->{'apply'} =~ /^\@/ ? 2 :
	      $_[2]->{'apply'} ? 1 : 0;
print &ui_table_row($text{'listfile_apply'},
    &ui_radio("apply_mode", $mode,
	[ [ 0, $text{'listfile_all'} ],
	  [ 1, $text{'listfile_user'}." ".
	    &unix_user_input("apply_user", $mode == 1 ? $_[2]->{'apply'} : "")],
	  [ 2, $text{'listfile_group'}." ".
	    &unix_group_input("apply_group", $mode == 2 ?
			substr($_[2]->{'apply'}, 1) : "") ] ]), 3);
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
