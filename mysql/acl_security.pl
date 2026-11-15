
require 'mysql-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the mysql module
sub acl_security_form
{
my ($o) = @_;
my @dbs = &list_databases();

print &ui_table_row($text{'acl_dbs'},
	&ui_radio("dbs_def", $o->{'dbs'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_dall'} ],
		    [ 0, $text{'acl_dsel'} ] ])."<br>\n".
	&ui_select("dbs", [ split(/\s+/, $o->{'dbs'}) ], \@dbs, 3, 1),
	3);

print &ui_table_row($text{'acl_delete'},
	&ui_yesno_radio("delete", $o->{'delete'}));
print &ui_table_row($text{'acl_stop'},
	&ui_yesno_radio("stop", $o->{'stop'}));
print &ui_table_row($text{'acl_edonly'},
	&ui_yesno_radio("edonly", $o->{'edonly'}));

print &ui_table_row($text{'acl_indexes'},
	&ui_yesno_radio("indexes", $o->{'indexes'}));
print &ui_table_row($text{'acl_views'},
	&ui_yesno_radio("views", $o->{'views'}));

print &ui_table_row($text{'acl_create'},
	&ui_radio_table("create",
		defined($o->{'create'}) ? $o->{'create'} : 0,
		[ [ 1, $text{'yes'} ],
		  [ 2, $text{'acl_max'},
		    &ui_textbox("max", $o->{'max'}, 5) ],
		  [ 0, $text{'no'} ] ], 1),
	3);

print &ui_table_row($text{'acl_perms'},
	&ui_radio("perms", defined($o->{'perms'}) ? $o->{'perms'} : 0,
		  [ [ 1, $text{'yes'} ],
		    [ 2, $text{'acl_only'} ],
		    [ 0, $text{'no'} ] ]),
	3);

print &ui_table_row($text{'acl_login'},
	&ui_radio_table("user_def", $o->{'user'} ? 0 : 1,
		[ [ 1, $text{'acl_user_def'} ],
		  [ 0, "",
		    $text{'acl_user'}." ".
		    &ui_textbox("user", $o->{'user'}, 10)." ".
		    $text{'acl_pass'}." ".
		    &ui_password("pass", $o->{'pass'}, 10) ] ], 1),
	3);

print &ui_table_row($text{'acl_buser'},
	&ui_opt_textbox("buser", $o->{'buser'}, 8, $text{'acl_bnone'})." ".
	&user_chooser_button("buser"),
	3);

print &ui_table_row($text{'acl_bpath'},
	&ui_textbox("bpath", $o->{'bpath'}, 40)." ".
	&file_chooser_button("bpath", 1),
	3);
}

# acl_security_save(&options)
# Parse the form for security options for the mysql module
sub acl_security_save
{
my ($o) = @_;
if ($in{'dbs_def'}) {
	$o->{'dbs'} = '*';
	}
else {
	$o->{'dbs'} = join(" ", split(/\0/, $in{'dbs'}));
	}
$o->{'create'} = $in{'create'};
$o->{'indexes'} = $in{'indexes'};
$o->{'views'} = $in{'views'};
$o->{'max'} = $in{'max'};
$o->{'delete'} = $in{'delete'};
$o->{'bpath'} = $in{'bpath'};
$o->{'buser'} = $in{'buser_def'} ? undef : $in{'buser'};
$o->{'stop'} = $in{'stop'};
$o->{'perms'} = $in{'perms'};
$o->{'edonly'} = $in{'edonly'};
if ($in{'user_def'}) {
	delete($o->{'user'});
	delete($o->{'pass'});
	}
else {
	$o->{'user'} = $in{'user'};
	$o->{'pass'} = $in{'pass'};
	}
}

