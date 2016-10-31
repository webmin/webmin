
require 'passwd-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the passwd module
sub acl_security_form
{
my ($o) = @_;
print &ui_table_row($text{'acl_users'},
    &ui_radio_table("mode", $o->{'mode'},
	[ [ 0, $text{'acl_mode0'} ],
	  [ 3, $text{'acl_mode3'} ],
	  [ 1, $text{'acl_mode1'},
	    &ui_textbox("users1", $o->{'mode'} == 1 ? $o->{'users'} : "", 40).
	    " ".&user_chooser_button("users1", 1) ],
	  [ 2, $text{'acl_mode2'},
	    &ui_textbox("users2", $o->{'mode'} == 2 ? $o->{'users'} : "", 40).
	    " ".&user_chooser_button("users2", 1) ],
	  [ 4, $text{'acl_mode4'},
	    &ui_textbox("low", $o->{'low'}, 8)." - ".
	    &ui_textbox("high", $o->{'high'}, 8) ],
	  [ 5, $text{'acl_mode5'},
	    &ui_textbox("groups", $o->{'mode'} == 5 ? $o->{'groups'} : "", 40).
	    " ".&group_chooser_button("groups", 1)."<br>\n".
	    &ui_checkbox("sec", 1, $text{'acl_sec'}, $o->{'sec'})."<br>\n".
	    $text{'acl_notusers'}." ".
	    &ui_textbox("notusers", $o->{'notusers'}, 20)." ".
	    &user_chooser_button("notusers", 1) ],
	  [ 6, $text{'acl_mode6'},
	    &ui_textbox("match", $o->{'mode'} == 6 ? $o->{'users'} : "", 20) ],
	]), 3);

print &ui_table_row($text{'acl_self'},
	&ui_yesno_radio("self", $o->{'self'}), 3);

print &ui_table_row($text{'acl_repeat'},
	&ui_yesno_radio("repeat", $o->{'repeat'}), 3);

print &ui_table_row($text{'acl_expire'},
	&ui_yesno_radio("expire", $o->{'expire'}), 3);

print &ui_table_row($text{'acl_others'},
	&ui_radio("others", $o->{'others'},
		  [ [ 1, $text{'yes'} ],
		    [ 2, $text{'acl_opt'} ],
		    [ 0, $text{'no'} ] ]), 3);

print &ui_table_row($text{'acl_old'},
	&ui_radio("old", $o->{'old'},
		  [ [ 1, $text{'yes'} ],
		    [ 2, $text{'acl_old_this'} ],
		    [ 0, $text{'no'} ] ]), 3);
}

# acl_security_save(&options)
# Parse the form for security options for the bind8 module
sub acl_security_save
{
my ($o) = @_;
$o->{'mode'} = $in{'mode'};
$o->{'users'} = $in{'mode'} == 1 ? $in{'users1'} :
		$in{'mode'} == 2 ? $in{'users2'} :
		$in{'mode'} == 6 ? $in{'match'} : undef;
$o->{'groups'} = $in{'mode'} == 5 ? $in{'groups'} : undef;
$o->{'notusers'} = $in{'mode'} == 5 ? $in{'notusers'} : undef;
$o->{'low'} = $in{'low'};
$o->{'high'} = $in{'high'};
$o->{'repeat'} = $in{'repeat'};
$o->{'self'} = $in{'self'};
$o->{'old'} = $in{'old'};
$o->{'others'} = $in{'others'};
$o->{'expire'} = $in{'expire'};
$o->{'sec'} = $in{'sec'};
}

