
do 'burner-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_create'},
	&ui_yesno_radio("create", $o->{'create'}));

print &ui_table_row($text{'acl_edit'},
	&ui_yesno_radio("edit", $o->{'edit'}));

print &ui_table_row($text{'acl_global'},
	&ui_yesno_radio("global", $o->{'global'}));

print &ui_table_row($text{'acl_profiles'},
	&ui_radio("all", $o->{'profiles'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_all'} ],
		    [ 0, $text{'acl_sel'}."<br>" ] ])."\n".
	&ui_select("profiles",
		   [ split(/\s+/, $o->{'profiles'}) ],
		   [ map { [ $_->{'id'}, $text{'index_type'.$_->{'type'}} ] }
			 &list_profiles() ],
		   5, 1), 3);

print &ui_table_row($text{'acl_dirs'},
	&ui_textbox("dirs", $o->{'dirs'}, 60), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o) = @_;
$o->{'create'} = $in{'create'};
$o->{'edit'} = $in{'edit'};
$o->{'global'} = $in{'global'};
$o->{'profiles'} = $in{'all'} ? "*" : join(" ", split(/\0/, $in{'profiles'}));
$o->{'dirs'} = $in{'dirs'};
}

