
require 'syslog-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the syslog module
sub acl_security_form
{
# Can edit syslog settings
print &ui_table_row($text{'acl_noedit'},
		    &ui_yesno_radio("noedit", int($_[0]->{'noedit'})));

# Can enter arbitrary filename
print &ui_table_row($text{'acl_any'},
		    &ui_yesno_radio("any", int($_[0]->{'any'})));

# Can view syslog logs and logs from other modules
print &ui_table_row($text{'acl_syslog'},
		    &ui_yesno_radio("syslog", int($_[0]->{'syslog'})));
print &ui_table_row($text{'acl_others'},
		    &ui_yesno_radio("others", int($_[0]->{'others'})));

# Allowed directories
print &ui_table_row($text{'acl_logs'},
	    &ui_radio("logs_def", $_[0]->{'logs'} ? 0 : 1,
		      [ [ 1, $text{'acl_all'} ], [ 0, $text{'acl_sel'} ] ]).
	    "<br>\n".
	    &ui_textarea("logs", join("\n", split(/\t+/, $_[0]->{'logs'})),
			 5, 50), 3);

# Extra per-user log files
print &ui_table_row($text{'acl_extra'},
	    &ui_textarea("extras", join("\n", split(/\t+/, $_[0]->{'extras'})),
			 5, 50), 3);

}

# acl_security_save(&options)
# Parse the form for security options for the syslog module
sub acl_security_save
{
$_[0]->{'noedit'} = $in{'noedit'};
$_[0]->{'any'} = $in{'any'};
$_[0]->{'syslog'} = $in{'syslog'};
$_[0]->{'others'} = $in{'others'};
$in{'logs'} =~ s/\r//g;
$_[0]->{'logs'} = $in{'logs_def'} ? undef :
			join("\t", split(/\n/, $in{'logs'}));
$_[0]->{'extras'} = join("\t", split(/\n/, $in{'extras'}));
}

