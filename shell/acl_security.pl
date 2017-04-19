
do 'shell-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the shell module
sub acl_security_form
{
print &ui_table_row($text{'acl_user'},
	&ui_opt_textbox("user", $_[0]->{'user'}, 20, $text{'acl_user_def'})." ".
	&user_chooser_button("user"));

print &ui_table_row($text{'acl_chroot'},
	&ui_filebox("chroot", $_[0]->{'chroot'}, 30, 0, 0, undef, 1));
}

# acl_security_save(&options)
# Parse the form for security options for the shell module
sub acl_security_save
{
$_[0]->{'user'} = $in{'user_def'} ? undef : $in{'user'};
$_[0]->{'chroot'} = $in{'chroot'};
}

