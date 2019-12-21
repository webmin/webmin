
require 'mailboxes-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the sendmail module
sub acl_security_form
{
my ($o) = @_;

# Users whose mail can be read
print &ui_table_row($text{'acl_read'},
    &ui_radio_table("mmode", $o->{'mmode'},
	[ [ 0, $text{'acl_none'} ],
	  [ 4, $text{'acl_same'} ],
	  [ 1, $text{'acl_all'} ],
	  [ 2, $text{'acl_users'},
	    &ui_users_textbox("musers",
		$o->{'mmode'} == 2 ? $o->{'musers'} : "") ],
	  [ 3, $text{'acl_userse'},
	    &ui_users_textbox("muserse",
		$o->{'mmode'} == 3 ? $o->{'musers'} : "") ],
	  [ 5, $text{'acl_usersg'},
	    &ui_groups_textbox("musersg",
		$o->{'mmode'} == 5 ? join(" ", map { scalar(getgrgid($_)) }
                                       split(/\s+/, $o->{'musers'})) : "").
	    " ".&ui_checkbox("msec", 1, $text{'acl_sec'}, $o->{'msec'}) ],
	  [ 7, $text{'acl_usersu'},
	    &ui_textbox("musersu1", $o->{'mmode'} == 7 ? $o->{'musers'} : "", 6)." - ".&ui_textbox("musersu2", $o->{'mmode'} == 7 ? $o->{'musers2'} : "", 6) ],
	  [ 6, &ui_textbox("musersm", $o->{'mmode'} == 6 ? $o->{'musers'} : "", 15) ],
	]), 3);

# Directory for arbitrary files
print &ui_table_row($text{'acl_dir'},
	&ui_opt_textbox("dir", $o->{'dir'}, 60, $text{'acl_dirauto'}."<br>"),
	3);

# Allowed From: addresses
print &ui_table_row($text{'acl_from'},
    &ui_radio_table("fmode", $o->{'fmode'},
	[ [ 0, $text{'acl_any'} ],
	  [ 1, $text{'acl_fdoms'},
	    &ui_textbox("fdoms", $o->{'fmode'} == 1 ? $o->{'from'} : '', 40) ],
	  [ 2, $text{'acl_faddrs'},
	    &ui_textbox("faddrs", $o->{'fmode'} == 2 ? $o->{'from'} : '', 40) ],
	  [ 3, $text{'acl_fdom'},
	    &ui_textbox("fdom", $o->{'fmode'} == 3 ? $o->{'from'} : '', 20) ],
	]), 3);

print &ui_table_row($text{'acl_fromname'},
	&ui_textbox("fromname", $o->{'fromname'}, 60), 3);

print &ui_table_row($text{'acl_attach'},
	&ui_opt_textbox("attach", $o->{'attach'}<0 ? "" : $o->{'attach'},
			5, "")." kB");

print &ui_table_row($text{'acl_canattach'},
	&ui_yesno_radio("canattach", $o->{'canattach'}));

print &ui_table_row($text{'acl_candetach'},
	&ui_yesno_radio("candetach", $o->{'candetach'}));
}

# acl_security_save(&options)
# Parse the form for security options for the sendmail module
sub acl_security_save
{
my ($o) = @_;
$o->{'mmode'} = $in{'mmode'};
$o->{'musers'} = $in{'mmode'} == 2 ? $in{'musers'} :
		    $in{'mmode'} == 3 ? $in{'muserse'} :
		    $in{'mmode'} == 5 ? join(" ", map { scalar(getgrnam($_)) }
					     split(/\s+/, $in{'musersg'})) :
		    $in{'mmode'} == 6 ? $in{'musersm'} :
		    $in{'mmode'} == 7 ? $in{'musersu1'} : "";
$o->{'musers2'} = $in{'mmode'} == 7 ? $in{'musersu2'} : "";
$o->{'msec'} = $in{'msec'};
$o->{'fmode'} = $in{'fmode'};
$o->{'from'} = $in{'fmode'} == 0 ? undef :
		  $in{'fmode'} == 1 ? $in{'fdoms'} :
		  $in{'fmode'} == 2 ? $in{'faddrs'} : $in{'fdom'};
$o->{'fromname'} = $in{'fromname'};
$o->{'attach'} = $in{'attach_def'} ? -1 : $in{'attach'};
$o->{'canattach'} = $in{'canattach'};
$o->{'candetach'} = $in{'candetach'};
$o->{'dir'} = $in{'dir_def'} ? undef : $in{'dir'};
}

