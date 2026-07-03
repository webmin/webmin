
require 'user-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the useradmin module
sub acl_security_form
{
local $o = $_[0];
my $uedit_group = $o->{'uedit_mode'} == 5 ?
	join(" ", map { "".&my_getgrgid($_) } split(/\s+/, $o->{'uedit'})) : "";

print &ui_table_row($text{'acl_uedit'},
	&ui_radio_table("uedit_mode",
		defined($o->{'uedit_mode'}) ? $o->{'uedit_mode'} : 0,
		[ [ 0, $text{'acl_uedit_all'} ],
		  [ 1, $text{'acl_uedit_none'} ],
		  [ 6, $text{'acl_uedit_this'} ],
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
		    " - ".&ui_textbox("uedit_uid2",
				      $o->{'uedit_mode'} == 4 ? $o->{'uedit2'} : "", 6) ],
		  [ 5, $text{'acl_uedit_group'},
		    &ui_textbox("uedit_group", $uedit_group, 40)." ".
		    &group_chooser_button("uedit_group", 1)."<br>\n".
		    &ui_checkbox("uedit_sec", 1, $text{'acl_uedit_sec'},
				 $o->{'uedit_sec'}) ],
		  [ 7, $text{'acl_uedit_re'},
		    &ui_textbox("uedit_re",
				$o->{'uedit_mode'} == 7 ? $o->{'uedit_re'} : "", 40) ] ], 1),
	3);

print &ui_table_row($text{'acl_ucreate'},
	&ui_yesno_radio("ucreate", $o->{'ucreate'}));

print &ui_table_row($text{'acl_batch'},
	&ui_yesno_radio("batch", $o->{'batch'}));

print &ui_table_row($text{'acl_batchdir'},
	&ui_filebox("batchdir", $o->{'batchdir'}, 60), 3);

print &ui_table_row($text{'acl_export'},
	&ui_radio("export", defined($o->{'export'}) ? $o->{'export'} : 0,
		  [ [ 2, $text{'yes'} ],
		    [ 1, $text{'acl_export1'} ],
		    [ 0, $text{'no'} ] ]),
	3);

print &ui_table_row($text{'acl_uid'},
	&ui_textbox("lowuid", $o->{'lowuid'}, 6)." - ".
	&ui_textbox("hiuid", $o->{'hiuid'}, 6)."<br>\n".
	join("<br>", map { &ui_checkbox($_, 1, $text{'acl_'.$_}, $o->{$_}) }
		    ('autouid', 'calcuid', 'useruid', 'umultiple', 'uuid')),
	3);

local $uedit_gmode = defined($o->{'uedit_gmode'}) ? $o->{'uedit_gmode'} :
		     $o->{'ugroups'} eq '*' ? 0 : 2;

print &ui_table_row($text{'acl_ugroups'},
	&ui_radio_table("uedit_gmode", $uedit_gmode,
		[ [ 0, $text{'acl_gedit_all'} ],
		  [ 2, $text{'acl_gedit_only'},
		    &ui_textbox("uedit_gcan",
				$uedit_gmode == 2 ? $o->{'ugroups'} : "", 40).
		    " ".&group_chooser_button("uedit_gcan", 1) ],
		  [ 3, $text{'acl_gedit_except'},
		    &ui_textbox("uedit_gcannot",
				$uedit_gmode == 3 ? $o->{'ugroups'} : "", 40).
		    " ".&group_chooser_button("uedit_gcannot", 1) ],
		  [ 4, $text{'acl_gedit_gid'},
		    &ui_textbox("uedit_gid",
				$uedit_gmode == 4 ? $o->{'ugroups'} : "", 6).
		    " - ".&ui_textbox("uedit_gid2",
				      $uedit_gmode == 4 ? $o->{'ugroups2'} : "", 6) ] ], 1),
	3);

print &ui_table_row($text{'acl_shells'},
	&ui_radio_table("shells_def", $o->{'shells'} eq "*" ? 1 : 0,
		[ [ 1, $text{'acl_any'} ],
		  [ 0, $text{'acl_listed'},
		    &ui_textarea("shells",
				 $o->{'shells'} eq "*" ? "" :
				 join("\n", split(/\s+/, $o->{'shells'} || "")),
				 3, 40) ] ], 1),
	3);

print &ui_table_row($text{'acl_epeopt'},
	&ui_yesno_radio("peopt", $o->{'peopt'}));

print &ui_table_row($text{'acl_home'},
	&ui_textbox("home", $o->{'home'}, 40)." ".
	&file_chooser_button("home", 1)."<br>\n".
	&ui_checkbox("autohome", 1, $text{'acl_autohome'}, $o->{'autohome'}),
	3);

print &ui_table_row($text{'acl_udelete'},
	&ui_yesno_radio("udelete", $o->{'udelete'}));
print &ui_table_row($text{'acl_urename'},
	&ui_yesno_radio("urename", $o->{'urename'}));

print &ui_table_row($text{'acl_delhome'},
	&ui_radio("delhome", $o->{'delhome'},
		  [ [ 2, $text{'acl_option'} ],
		    [ 1, $text{'acl_always'} ],
		    [ 0, $text{'acl_never'} ] ]),
	3);

print &ui_table_span($text{'acl_saveopts'});
foreach my $opt ('chuid', 'chgid', 'movehome', 'mothers',
		 'makehome', 'copy', 'cothers', 'dothers') {
	print &ui_table_row($text{"uedit_$opt"},
		&ui_radio($opt, defined($o->{$opt}) ? $o->{$opt} : 0,
			  [ [ 1, $text{'acl_canedit'} ],
			    [ 0, $text{'acl_on'} ],
			    [ 2, $text{'acl_off'} ] ]),
		3);
	}

print &ui_table_hr();

print &ui_table_row($text{'acl_gedit'},
	&ui_radio_table("gedit_mode",
		defined($o->{'gedit_mode'}) ? $o->{'gedit_mode'} : 0,
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
		    " - ".&ui_textbox("gedit_gid2",
				      $o->{'gedit_mode'} == 4 ? $o->{'gedit2'} : "", 6) ] ], 1),
	3);

print &ui_table_row($text{'acl_gcreate'},
	&ui_radio("gcreate", defined($o->{'gcreate'}) ? $o->{'gcreate'} : 0,
		  [ [ 1, $text{'yes'} ],
		    [ 2, $text{'acl_gnew'} ],
		    [ 0, $text{'no'} ] ]),
	3);

print &ui_table_row($text{'acl_gid'},
	&ui_textbox("lowgid", $o->{'lowgid'}, 6)." - ".
	&ui_textbox("higid", $o->{'higid'}, 6)."<br>\n".
	join("<br>", map { &ui_checkbox($_, 1, $text{'acl_'.$_}, $o->{$_}) }
		    ('autogid', 'calcgid', 'usergid', 'gmultiple', 'ggid')),
	3);

print &ui_table_row($text{'acl_gdelete'},
	&ui_yesno_radio("gdelete", $o->{'gdelete'}));
print &ui_table_row($text{'acl_grename'},
	&ui_yesno_radio("grename", $o->{'grename'}));

print &ui_table_hr();

my $logins_mode = !$o->{'logins'} ? 0 : $o->{'logins'} eq "*" ? 1 : 2;
print &ui_table_row($text{'acl_logins'},
	&ui_radio_table("logins_mode", $logins_mode,
		[ [ 0, $text{'acl_lnone'} ],
		  [ 1, $text{'acl_lall'} ],
		  [ 2, "",
		    &ui_textbox("logins",
				$logins_mode == 2 ? $o->{'logins'} : "", 40)." ".
		    &user_chooser_button("logins", 1) ] ], 1),
	3);
}

# acl_security_save(&options)
# Parse the form for security options for the useradmin module
sub acl_security_save
{
$_[0]->{'lowuid'} = $in{'lowuid'};
$_[0]->{'hiuid'} = $in{'hiuid'};
$_[0]->{'autouid'} = $in{'autouid'};
$_[0]->{'autogid'} = $in{'autogid'};
$_[0]->{'calcuid'} = $in{'calcuid'};
$_[0]->{'calcgid'} = $in{'calcgid'};
$_[0]->{'useruid'} = $in{'useruid'};
$_[0]->{'usergid'} = $in{'usergid'};
$_[0]->{'lowgid'} = $in{'lowgid'};
$_[0]->{'higid'} = $in{'higid'};
$_[0]->{'uedit_mode'} = $in{'uedit_mode'};
$_[0]->{'uedit'} = $in{'uedit_mode'} == 2 ? $in{'uedit_can'} :
		   $in{'uedit_mode'} == 3 ? $in{'uedit_cannot'} :
		   $in{'uedit_mode'} == 4 ? $in{'uedit_uid'} :
		   $in{'uedit_mode'} == 5 ?
			join(" ", map { "".&my_getgrnam($_) }
			     split(/\s+/, $in{'uedit_group'})) : "";
$_[0]->{'uedit2'} = $in{'uedit_mode'} == 4 ? $in{'uedit_uid2'} : undef;
$_[0]->{'uedit_sec'} = $in{'uedit_mode'} == 5 ? $in{'uedit_sec'} : undef;
$_[0]->{'uedit_re'} = $in{'uedit_mode'} == 7 ? $in{'uedit_re'} : undef;
$_[0]->{'gedit_mode'} = $in{'gedit_mode'};
$_[0]->{'gedit'} = $in{'gedit_mode'} == 2 ? $in{'gedit_can'} :
		   $in{'gedit_mode'} == 3 ? $in{'gedit_cannot'} :
		   $in{'gedit_mode'} == 4 ? $in{'gedit_gid'} : "";
$_[0]->{'gedit2'} = $in{'gedit_mode'} == 4 ? $in{'gedit_gid2'} : undef;
$_[0]->{'ucreate'} = $in{'ucreate'};
$_[0]->{'gcreate'} = $in{'gcreate'};
if ($in{'uedit_gmode'} == 0) {
	delete($_[0]->{'uedit_gmode'});
	$_[0]->{'ugroups'} = "*";
	}
elsif ($in{'uedit_gmode'} == 2) {
	delete($_[0]->{'uedit_gmode'});
	$_[0]->{'ugroups'} = $in{'uedit_gcan'};
	}
else {
	$_[0]->{'uedit_gmode'} = $in{'uedit_gmode'};
	$_[0]->{'ugroups'} = $in{'uedit_gmode'} == 3 ? $in{'uedit_gcannot'} :
			     $in{'uedit_gmode'} == 4 ? $in{'uedit_gid'} : "";
	}
$_[0]->{'ugroups2'} = $in{'uedit_gmode'} == 4 ? $in{'uedit_gid2'} : undef;

$_[0]->{'logins'} = $in{'logins_mode'} == 0 ? "" :
		    $in{'logins_mode'} == 1 ? "*" : $in{'logins'};
$_[0]->{'shells'} = $in{'shells_def'} ? "*"
				      : join(" ", split(/\s+/, $in{'shells'}));
$_[0]->{'peopt'} = $in{'peopt'};
$_[0]->{'batch'} = $in{'batch'};
$_[0]->{'batchdir'} = $in{'batchdir'};
$_[0]->{'export'} = $in{'export'};
$_[0]->{'home'} = $in{'home'};
$_[0]->{'delhome'} = $in{'delhome'};
$_[0]->{'autohome'} = $in{'autohome'};
$_[0]->{'umultiple'} = $in{'umultiple'};
$_[0]->{'uuid'} = $in{'uuid'};
$_[0]->{'gmultiple'} = $in{'gmultiple'};
$_[0]->{'ggid'} = $in{'ggid'};
foreach $o ('chuid', 'chgid', 'movehome', 'mothers',
	    'makehome', 'copy', 'cothers', 'dothers') {
	$_[0]->{$o} = $in{$o};
	}
$_[0]->{'udelete'} = $in{'udelete'};
$_[0]->{'urename'} = $in{'urename'};
$_[0]->{'gdelete'} = $in{'gdelete'};
$_[0]->{'grename'} = $in{'grename'};
}

