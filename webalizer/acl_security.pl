
use strict;
use warnings;
our (%text, %in);
do 'webalizer-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the webalizer module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_view'},
	&ui_yesno_radio("view", $o->{'view'}));

print &ui_table_row($text{'acl_global'},
	&ui_yesno_radio("global", $o->{'global'}));

print &ui_table_row($text{'acl_add'},
	&ui_yesno_radio("add", $o->{'add'}));

print &ui_table_row($text{'acl_user'},
	&ui_radio("user_def", $o->{'user'} eq "" ? 1 :
			      $o->{'user'} eq "*" ? 2 : 0,
		  [ [ 1, $text{'acl_this'} ],
		    [ 2, $text{'acl_any'} ],
		    [ 0, &ui_user_textbox("user", $o->{'user'} eq "*" ? "" :
						$o->{'user'}, 20) ] ]));

print &ui_table_row($text{'acl_dir'},
	&ui_textbox("dir", $o->{'dir'}, 60), 3);
}

# acl_security_save(&options, &in)
# Parse the form for security options for the shell module
sub acl_security_save
{
my ($o, $in) = @_;
$o->{'view'} = $in->{'view'};
$o->{'global'} = $in->{'global'};
$o->{'add'} = $in->{'add'};
$o->{'dir'} = $in->{'dir'};
$o->{'user'} = $in->{'user_def'} == 2 ? "*" :
	       $in->{'user_def'} == 1 ? "" : $in->{'user'};
}

