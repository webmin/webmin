
require 'net-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the net module
sub acl_security_form
{
print &ui_table_row($text{'acl_ifcs'},
	&ui_radio_table("ifcs", $_[0]->{'ifcs'},
		[ [ 2, $text{'yes'} ],
		  [ 1, $text{'acl_view'} ],
		  [ 0, $text{'no'} ],
		  [ 3, $text{'acl_ifcs_only'},
		    &ui_textbox("interfaces3", $_[0]->{'interfaces'}, 30)." ".
		    &interfaces_chooser_button("interfaces3", 1) ],
		  [ 4, $text{'acl_ifcs_ex'},
		    &ui_textbox("interfaces4", $_[0]->{'interfaces'}, 30)." ".
		    &interfaces_chooser_button("interfaces4", 1) ] ]), 3);

print &ui_table_row($text{'acl_bootonly'},
	&ui_radio("bootonly", $_[0]->{'bootonly'},
		 [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'acl_netmask'},
	&ui_radio("netmask", $_[0]->{'netmask'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_broadcast'},
	&ui_radio("broadcast", $_[0]->{'broadcast'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_mtu'},
	&ui_radio("mtu", $_[0]->{'mtu'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_up'},
	&ui_radio("up", $_[0]->{'up'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_virt'},
	&ui_radio("virt", $_[0]->{'virt'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_delete'},
	&ui_radio("delete", $_[0]->{'delete'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_hide'},
	&ui_radio("hide", $_[0]->{'hide'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_routes'},
	&ui_radio("routes", $_[0]->{'routes'},
		  [ [ 2, $text{'yes'} ],
		    [ 1, $text{'acl_view'} ],
		    [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_dns'},
	&ui_radio("dns", $_[0]->{'dns'},
		  [ [ 2, $text{'yes'} ],
		    [ 1, $text{'acl_view'} ],
		    [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_hosts'},
	&ui_radio("hosts", $_[0]->{'hosts'},
                  [ [ 2, $text{'yes'} ],
                    [ 1, $text{'acl_view'} ],
                    [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_apply'},
	&ui_radio("apply", $_[0]->{'apply'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

print &ui_table_row($text{'acl_sysinfo'},
	&ui_radio("sysinfo", $_[0]->{'sysinfo'},
		 [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));
}

# acl_security_save(&options)
# Parse the form for security options for the file module
sub acl_security_save
{
$_[0]->{'ifcs'} = $in{'ifcs'};
$_[0]->{'routes'} = $in{'routes'};
$_[0]->{'dns'} = $in{'dns'};
$_[0]->{'hosts'} = $in{'hosts'};
$_[0]->{'interfaces'} = $in{'ifcs'} == 3 ? $in{'interfaces3'} :
			$in{'ifcs'} == 4 ? $in{'interfaces4'} : undef;
$_[0]->{'apply'} = $in{'apply'};
$_[0]->{'bootonly'} = $in{'bootonly'};
$_[0]->{'netmask'} = $in{'netmask'};
$_[0]->{'broadcast'} = $in{'broadcast'};
$_[0]->{'mtu'} = $in{'mtu'};
$_[0]->{'up'} = $in{'up'};
$_[0]->{'virt'} = $in{'virt'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'hide'} = $in{'hide'};
$_[0]->{'sysinfo'} = $in{'sysinfo'};
}

