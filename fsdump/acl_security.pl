
do 'fsdump-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
print &ui_table_row($text{'acl_edit'},
		      &ui_yesno_radio('edit', $_[0]->{'edit'}));

print &ui_table_row($text{'acl_restore'},
		      &ui_yesno_radio('restore', $_[0]->{'restore'}));

print &ui_table_row($text{'acl_cmds'},
		      &ui_yesno_radio('cmds', $_[0]->{'cmds'}));

print &ui_table_row($text{'acl_extra'},
		      &ui_yesno_radio('extra', $_[0]->{'extra'}));

print &ui_table_row($text{'acl_dirs'},
		      &ui_radio("dirs_def", $_[0]->{'dirs'} eq "*" ? 1 : 0,
			        [ [ 1, $text{'acl_all'} ],
				  [ 0, $text{'acl_list'} ] ])."<br>\n".
		      &ui_textarea("dirs", $_[0]->{'dirs'} eq "*" ? "" :
				      join("\n", split(/\t/, $_[0]->{'dirs'})),
				   5, 50), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
$_[0]->{'edit'} = $in{'edit'};
$_[0]->{'restore'} = $in{'restore'};
$_[0]->{'cmds'} = $in{'cmds'};
$_[0]->{'extra'} = $in{'extra'};
$in{'dirs'} =~ s/\r//g;
$_[0]->{'dirs'} = $in{'dirs_def'} ? "*" :
			join("\t", split(/\n/, $in{'dirs'}));
}

