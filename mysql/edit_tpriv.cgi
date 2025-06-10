#!/usr/local/bin/perl
# edit_tpriv.cgi
# Display a form for editing or creating new table permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});
if (defined($in{'db'})) {
	$in{'db'} =~ /^\S+$/ || &error($text{'tpriv_edb'});
	&ui_print_header(undef, $text{'tpriv_title1'}, "", "create_tpriv");
	}
else {
	$d = &execute_sql_safe($master_db, "select * from tables_priv order by table_name");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	&ui_print_header(undef, $text{'tpriv_title2'}, "", "edit_tpriv");
	}

print &ui_form_start("save_tpriv.cgi");
if ($in{'db'}) {
	print &ui_hidden("db", $in{'db'});
	}
else {
	print &ui_hidden("oldhost", $u->[0]);
	print &ui_hidden("olddb", $u->[1]);
	print &ui_hidden("olduser", $u->[2]);
	print &ui_hidden("oldtable", $u->[3]);
	}
print &ui_table_start($text{'tpriv_header'}, undef, 2);

# Apply to DB
print &ui_table_row($text{'tpriv_db'}, $in{'db'} || $u->[1]);

# Apply to table
print &ui_table_row($text{'tpriv_table'},
	&ui_select("table", $in{'db'} ? '' : $u->[3],
		   [ $in{'db'} ? ( [ '' ] ) : ( ),
		     &list_tables($in{'db'} || $u->[1]) ], 1, 0, 1));

# Apply to user
print &ui_table_row($text{'tpriv_user'},
	&ui_opt_textbox("user", $u->[2], 20, $text{'tpriv_anon'}));

# Apply to host
print &ui_table_row($text{'tpriv_host'},
	&ui_opt_textbox("host", $u->[0] eq '%' ? '' : $u->[0], 40,
			$text{'tpriv_any'}));

# Table permissions
$remote_mysql_version = &get_remote_mysql_version();
print &ui_table_row($text{'tpriv_perms1'},
	&ui_select("perms1", [ split(/,/, $u->[6]) ],
		   [ 'Select','Insert','Update','Delete','Create',
		     'Drop','Grant','References','Index','Alter',
		     ($remote_mysql_version >= 5 ?
			('Create View', 'Show view') : ( )) ],
		   4, 1));

# Field permissions
print &ui_table_row($text{'tpriv_perms2'},
	&ui_select("perms2", [ split(/,/, $u->[7]) ],
		   [ 'Select','Insert','Update','References' ], 4, 1));

print &ui_table_end();
print &ui_form_end([ $in{'db'} ? ( [ undef, $text{'create'} ] )
				: ( [ undef, $text{'save'} ],
				    [ 'delete', $text{'delete'} ] ) ]);

&ui_print_footer('list_tprivs.cgi', $text{'tprivs_return'},
	"", $text{'index_return'});

