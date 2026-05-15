
use WebminCore;
&init_config();

# acl_security_form(&options)
# Output HTML for editing global security options
sub acl_security_form
{
my ($o) = @_;

# Root directory for file browser
print &ui_table_row($text{'acl_root'},
	&ui_opt_textbox("root", $o->{'root'}, 40, $text{'acl_home'})." ".
	&file_chooser_button("root", 1));

# Other dirs to allow
print &ui_table_row($text{'acl_otherdirs'},
	&ui_textarea("otherdirs", join("\n", split(/\t+/, $o->{'otherdirs'})),
		     3, 40), 3);

# Can see dot files?
print &ui_table_row($text{'acl_nodot'},
	&ui_yesno_radio("nodot", int($o->{'nodot'})));

# Browse as Unix user
print &ui_table_row($text{'acl_fileunix'},
	&ui_opt_textbox("fileunix", $o->{'fileunix'}, 13,
			$text{'acl_sameunix'})." ".
	&user_chooser_button("fileunix"));

print &ui_hr();

# Users visible in chooser
print &ui_table_row($text{'acl_uedit'},
  &ui_radio_table("uedit_mode", int($o->{'uedit_mode'}),
	[ [ 0, $text{'acl_uedit_all'} ],
	  [ 1, $text{'acl_uedit_none'} ],
	  [ 2, $text{'acl_uedit_only'},
	       &ui_textbox("uedit_can",
			   $o->{'uedit_mode'} == 2 ? $o->{'uedit'} : "", 40).
	       " ".&user_chooser_button("uedit_can", 1) ],
	  [ 3, $text{'acl_uedit_except'},
	       &ui_textbox("uedit_cannot",
			   $o->{'uedit_mode'} == 3 ? $o->{'uedit'} : "", 40).
	       " ".&user_chooser_button("uedit_cannot", 1) ],
	  [ 4, $text{'acl_uedit_uid'},
	       &ui_textbox("uedit_uid",
			   $o->{'uedit_mode'} == 4 ? $o->{'uedit'} : "", 6).
	       " - ".
	       &ui_textbox("uedit_uid2",
			   $o->{'uedit_mode'} == 4 ? $o->{'uedit2'} : "", 6) ],
	  [ 5, $text{'acl_uedit_group'},
	       &ui_group_textbox("uedit_group",
		$o->{'uedit_mode'} == 5 ? $dummy=getgrgid($o->{'uedit'}) : "")],
	]));

# Groups visible in chooser
print &ui_table_row($text{'acl_gedit'},
    &ui_radio_table("gedit_mode", int($o->{'gedit_mode'}),
	[ [ 0, $text{'acl_gedit_all'} ],
	  [ 1, $text{'acl_gedit_none'} ],
	  [ 2, $text{'acl_gedit_only'},
	       &ui_textbox("gedit_can",
			   $o->{'gedit_mode'} == 2 ? $o->{'gedit'} : "", 40).
	       " ".&group_chooser_button("gedit_can", 1) ],
	  [ 3, $text{'acl_gedit_except'},
	       &ui_textbox("gedit_cannot",
			   $o->{'gedit_mode'} == 3 ? $o->{'gedit'} : "", 40).
	       " ".&group_chooser_button("gedit_cannot", 1) ],
	  [ 4, $text{'acl_gedit_gid'},
	       &ui_textbox("gedit_gid",
			   $o->{'gedit_mode'} == 4 ? $o->{'gedit'} : "", 6).
	       " - ".
	       &ui_textbox("gedit_gid2",
			   $o->{'gedit_mode'} == 4 ? $o->{'gedit2'} : "", 6) ],
	]));

print &ui_table_hr();

# Can accept RPC calls?
print &ui_table_row($text{'acl_rpc'},
	&ui_radio("rpc", int($o->{'rpc'}),
		  [ [ 1, $text{'acl_rpc1'} ],
		    $o->{'rpc'} == 2 ? ( [ 2, $text{'acl_rpc2'} ] ) : ( ),
		    [ 0, $text{'acl_rpc0'} ] ]));

# Get new permissions?
print &ui_table_row($text{'acl_negative'},
	&ui_radio("negative", int($o->{'negative'}),
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

# Readonly mode
print &ui_table_row($text{'acl_readonly2'},
	&ui_radio("readonly", int($o->{'readonly'}),
		  [ [ 1, $text{'acl_readonlyyes'} ],
		    [ 0, $text{'no'} ] ]));

# Allow use of search field
print &ui_table_row($text{'acl_webminsearch'},
	&ui_radio("webminsearch", int($o->{'webminsearch'}),
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));
}

# acl_security_save(&options)
# Parse the form for global security options
sub acl_security_save
{
my ($o) = @_;
$o->{'root'} = $in{'root_def'} ? undef : $in{'root'};
$o->{'otherdirs'} = join("\t", split(/\r?\n/, $in{'otherdirs'}));
$o->{'nodot'} = $in{'nodot'};

$o->{'uedit_mode'} = $in{'uedit_mode'};
$o->{'uedit'} = $in{'uedit_mode'} == 2 ? $in{'uedit_can'} :
		   $in{'uedit_mode'} == 3 ? $in{'uedit_cannot'} :
		   $in{'uedit_mode'} == 4 ? $in{'uedit_uid'} :
		   $in{'uedit_mode'} == 5 ? getgrnam($in{'uedit_group'}) : "";
$o->{'uedit2'} = $in{'uedit_mode'} == 4 ? $in{'uedit_uid2'} : undef;

$o->{'gedit_mode'} = $in{'gedit_mode'};
$o->{'gedit'} = $in{'gedit_mode'} == 2 ? $in{'gedit_can'} :
		   $in{'gedit_mode'} == 3 ? $in{'gedit_cannot'} :
		   $in{'gedit_mode'} == 4 ? $in{'gedit_gid'} : "";
$o->{'gedit2'} = $in{'gedit_mode'} == 4 ? $in{'gedit_gid2'} : undef;
$o->{'rpc'} = $in{'rpc'};
$o->{'negative'} = $in{'negative'};
$o->{'readonly'} = $in{'readonly'};
$o->{'fileunix'} = $in{'fileunix_def'} ? undef : $in{'fileunix'};
$o->{'webminsearch'} = $in{'webminsearch'};
}

