
require 'mount-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the mount module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_fs'},
	&ui_opt_textbox("fs", $o->{'fs'}, 40,
			$text{'acl_all'}, $text{'acl_list'}), 3);

print &ui_table_row($text{'acl_types'},
	&ui_opt_textbox("types", $o->{'types'}, 30,
			$text{'acl_all'}, $text{'acl_fslist'}), 3);

print &ui_table_row($text{'acl_create'},
	&ui_radio("create", $o->{'create'},
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_only'},
	&ui_radio("only", $o->{'only'},
	          [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_user'},
	&ui_radio("user", $o->{'user'},
	          [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_hide'},
	&ui_radio("hide", $o->{'hide'},
	          [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_browse'},
	&ui_radio("browse", $o->{'browse'},
	          [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_sysinfo'},
	&ui_radio("sysinfo", $o->{'sysinfo'},
	          [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

}

# acl_security_save(&options)
# Parse the form for security options for the mount module
sub acl_security_save
{
my ($o) = @_;
$o->{'fs'} = $in{'fs_def'} ? undef : $in{'fs'};
$o->{'types'} = $in{'types_def'} ? undef : $in{'types'};
$o->{'only'} = $in{'only'};
$o->{'create'} = $in{'create'};
$o->{'user'} = $in{'user'};
$o->{'hide'} = $in{'hide'};
$o->{'browse'} = $in{'browse'};
$o->{'sysinfo'} = $in{'sysinfo'};
}

