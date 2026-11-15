
require 'postgresql-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the postgresql module
sub acl_security_form
{
my ($o) = @_;
my @listdb = &list_databases();

if (@listdb) {
	print &ui_table_row($text{'acl_dbs'},
		&ui_radio("dbs_def", $o->{'dbs'} eq '*' ? 1 : 0,
			  [ [ 1, $text{'acl_dall'} ],
			    [ 0, $text{'acl_dsel'} ] ])."<br>\n".
		&ui_select("dbs", [ split(/\s+/, $o->{'dbs'}) ], \@listdb, 5, 1).
		&ui_hidden("dblist", "1"),
		3);
	}
else {
	print &ui_table_row($text{'acl_dbs'},
		$text{'acl_dbscannot'}.&ui_hidden("dblist", "0 ".$o->{'dbs'}),
		3);
	}

print &ui_table_row($text{'acl_create'},
	&ui_radio_table("create",
		defined($o->{'create'}) ? $o->{'create'} : 0,
		[ [ 1, $text{'yes'} ],
		  [ 2, $text{'acl_max'}, &ui_textbox("max", $o->{'max'}, 5) ],
		  [ 0, $text{'no'} ] ], 1),
	3);

print &ui_table_row($text{'acl_delete'},
	&ui_yesno_radio("delete", $o->{'delete'}));
print &ui_table_row($text{'acl_stop'},
	&ui_yesno_radio("stop", $o->{'stop'}));
print &ui_table_row($text{'acl_users'},
	&ui_yesno_radio("users", $o->{'users'}));

print &ui_table_row($text{'acl_login'},
	&ui_radio_table("user_def", $o->{'user'} ? 0 : 1,
		[ [ 1, $text{'acl_user_def'} ],
		  [ 0, "",
		    $text{'acl_user'}." ".&ui_textbox("user", $o->{'user'}, 10)." ".
		    $text{'acl_pass'}." ".&ui_password("pass", $o->{'pass'}, 10)."<br>\n".
		    &ui_checkbox("sameunix", 1, $text{'acl_sameunix'}, $o->{'sameunix'}) ] ], 1),
	3);

print &ui_table_row($text{'acl_backup'},
	&ui_yesno_radio("backup", $o->{'backup'}));
print &ui_table_row($text{'acl_restore'},
	&ui_yesno_radio("restore", $o->{'restore'}));

print &ui_table_row($text{'acl_buser'},
	&ui_textbox("buser", $o->{'buser'}, 8, $text{'acl_bnone'})." ".
	&user_chooser_button("buser"),
	3);

print &ui_table_row($text{'acl_bpath'},
	&ui_textbox("bpath", $o->{'bpath'}, 40)." ".
	&file_chooser_button("bpath", 1),
	3);

print &ui_table_row($text{'acl_cmds'},
	&ui_yesno_radio("cmds", $o->{'cmds'}));
print &ui_table_row($text{'acl_views'},
	&ui_yesno_radio("views", $o->{'views'}));

print &ui_table_row($text{'acl_indexes'},
	&ui_yesno_radio("indexes", $o->{'indexes'}));
print &ui_table_row($text{'acl_seqs'},
	&ui_yesno_radio("seqs", $o->{'seqs'}));
}

# acl_security_save(&options)
# Parse the form for security options for the postgresql module
sub acl_security_save
{
my ($o) = @_;
if ($in{'dblist'} eq '1') {
	if ($in{'dbs_def'}) {
		$o->{'dbs'} = '*';
		}
	else {
		$o->{'dbs'} = join(" ", split(/\0/, $in{'dbs'}));
		}
	} 
else {
	$o->{'dbs'} = $in{'dblist'};
	$o->{'dbs'} =~ s/^0 //;
	}
$o->{'create'} = $in{'create'};
$o->{'max'} = $in{'max'};
$o->{'delete'} = $in{'delete'};
$o->{'stop'} = $in{'stop'};
$o->{'users'} = $in{'users'};
$o->{'backup'} = $in{'backup'};
$o->{'restore'} = $in{'restore'};
$o->{'cmds'} = $in{'cmds'};
$o->{'views'} = $in{'views'};
$o->{'indexes'} = $in{'indexes'};
$o->{'seqs'} = $in{'seqs'};
if ($in{'user_def'}) {
	delete($o->{'user'});
	delete($o->{'pass'});
	}
else {
	$o->{'user'} = $in{'user'};
	$o->{'pass'} = $in{'pass'};
	}
$o->{'sameunix'} = $in{'sameunix'};
$o->{'bpath'} = $in{'bpath'};
$o->{'buser'} = $in{'buser'};
}

