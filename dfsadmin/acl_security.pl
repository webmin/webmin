
require 'dfs-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the format module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_view'},
	&ui_radio("view", $o->{'view'},
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));
}

# acl_security_save(&options)
# Parse the form for security options for the format module
sub acl_security_save
{
$_[0]->{'view'} = $in{'view'};
}

