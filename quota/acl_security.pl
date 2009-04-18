
require 'quota-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the quota module
sub acl_security_form
{
local $groups = &quotas_supported() >= 2;

# Allowed filesystems
print &ui_table_row($text{'acl_fss'},
	&ui_radio("filesys_def", $_[0]->{'filesys'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_fall'} ], [ 0, $text{'acl_fsel'} ] ]).
	"<br>\n".
	&ui_select("filesys",
		   $_[0]->{'filesys'} eq '*' ? [ ] :
			[ split(/\s+/, $_[0]->{'filesys'}) ],
		   [ map { $_->[0] } grep { $_->[4] } &list_filesystems() ],
		   6, 1, 1, 0), 3);

# Readonly mode
print &ui_table_row($text{'acl_ro'},
	&ui_yesno_radio("ro", $_[0]->{'ro'}), 3);

print &ui_table_hr();

# Can enable quotas?
print &ui_table_row($text{'acl_quotaon'},
	&ui_yesno_radio("enable", $_[0]->{'enable'}));

# Can edit defaults for new users?
print &ui_table_row($text{'acl_quotanew'},
	&ui_yesno_radio("default", $_[0]->{'default'}));

# Can edit user grace times
print &ui_table_row($text{'acl_ugrace'},
	&ui_yesno_radio("ugrace", $_[0]->{'ugrace'}));

# Can edit group grace times
if ($groups) {
	print &ui_table_row($text{'acl_ggrace'},
		&ui_yesno_radio("ggrace", $_[0]->{'ggrace'}));
	}

# Can see total disk space
print &ui_table_row($text{'acl_vtotal'},
	&ui_yesno_radio("diskspace", $_[0]->{'diskspace'}));

# Maximum block quota
print &ui_table_row($text{'acl_maxblocks'},
	&ui_opt_textbox("maxblocks", $_[0]->{'maxblocks'}, 8,
			$text{'acl_unlimited'}));

# Maximum file quota
print &ui_table_row($text{'acl_maxfiles'},
	&ui_opt_textbox("maxfiles", $_[0]->{'maxfiles'}, 8,
			$text{'acl_unlimited'}));

# Can edit email notifications?
print &ui_table_row($text{'acl_email'},
	&ui_yesno_radio("email", $_[0]->{'email'}));

print &ui_table_hr();

# Allowed users
print &ui_table_row($text{'acl_uquota'},
    &ui_radio_table("umode", int($_[0]->{'umode'}),
	[ [ 0, $text{'acl_uall'} ],
	  [ 1, 	$text{'acl_uonly'},
	    &ui_textbox("ucan",
			$_[0]->{'umode'} == 1 ? $_[0]->{'users'} : "",
			40)." ".&user_chooser_button("ucan", 1) ],
	  [ 2, $text{'acl_uexcept'},
	    &ui_textbox("ucannot",
			$_[0]->{'umode'} == 2 ? $_[0]->{'users'} : "",
			40)." ".&user_chooser_button("ucannot", 1) ],
	  [ 3, $text{'acl_ugroup'},
	    &ui_group_textbox("upri", $_[0]->{'umode'} == 3 ?
				scalar(getgrgid($_[0]->{'users'})) : "") ],
	  [ 4, $text{'acl_uuid'},
	    &ui_textbox("umin",
			$_[0]->{'umode'} == 4 ? $_[0]->{'umin'} : "", 6)." - ".
	    &ui_textbox("umax",
			$_[0]->{'umode'} == 4 ? $_[0]->{'umax'} : "", 6) ]
	]), 3);

# Allowed groups
if ($groups) {
	print &ui_table_hr();

	print &ui_table_row($text{'acl_gquota'},
	    &ui_radio_table("gmode", int($_[0]->{'gmode'}),
		[ [ 0, $text{'acl_gall'} ],
		  [ 3, $text{'acl_gnone'} ],
		  [ 1, $text{'acl_gonly'},
		    &ui_textbox("gcan",
			$_[0]->{'gmode'} == 1 ? $_[0]->{'groups'} : "", 40)." ".
		    &group_chooser_button("gcan", 1) ],
		  [ 2, $text{'acl_gexcept'},
		    &ui_textbox("gcannot",
			$_[0]->{'gmode'} == 2 ? $_[0]->{'groups'} : "", 40)." ".
		    &group_chooser_button("gcannot", 1) ],
		  [ 4, $text{'acl_ggid'},
		    &ui_textbox("gmin",
			$_[0]->{'gmode'} == 4 ? $_[0]->{'gmin'} : "", 6)." - ".
		    &ui_textbox("gmax",
			$_[0]->{'gmode'} == 4 ? $_[0]->{'gmax'} : "", 6) ]
		]), 3);
	}
}

# acl_security_save(&options)
# Parse the form for security options for the quota module
sub acl_security_save
{
if ($in{'filesys_def'}) {
	$_[0]->{'filesys'} = "*";
	}
else {
	$_[0]->{'filesys'} = join(" ", split(/\0/, $in{'filesys'}));
	}
$_[0]->{'ro'} = $in{'ro'};
$_[0]->{'umode'} = $in{'umode'};
$_[0]->{'users'} = $in{'umode'} == 0 ? "" :
		   $in{'umode'} == 1 ? $in{'ucan'} :
		   $in{'umode'} == 2 ? $in{'ucannot'} :
		   $in{'umode'} == 3 ? scalar(getgrnam($in{'upri'})) : "";
$_[0]->{'umin'} = $in{'umin'};
$_[0]->{'umax'} = $in{'umax'};
$_[0]->{'gmode'} = $in{'gmode'};
$_[0]->{'groups'} = $in{'gmode'} == 0 ? "" :
		    $in{'gmode'} == 1 ? $in{'gcan'} :
		    $in{'gmode'} == 2 ? $in{'gcannot'} : "";
$_[0]->{'gmin'} = $in{'gmin'};
$_[0]->{'gmax'} = $in{'gmax'};
$_[0]->{'enable'} = $in{'enable'};
$_[0]->{'default'} = $in{'default'};
$_[0]->{'email'} = $in{'email'};
$_[0]->{'ugrace'} = $in{'ugrace'};
$_[0]->{'ggrace'} = $in{'ggrace'};
$_[0]->{'diskspace'} = $in{'diskspace'};
$_[0]->{'maxblocks'} = $in{'maxblocks_def'} ? undef : $in{'maxblocks'};
$_[0]->{'maxfiles'} = $in{'maxfiles'};
}

