#!/usr/local/bin/perl
# edit_cpriv.cgi
# Display a form for editing or creating new column permissions

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} || &error($text{'perms_ecannot'});
if (defined($in{'table'})) {
	&ui_print_header(undef, $text{'cpriv_title1'}, "", "create_cpriv");
	if (defined($in{'db'})) {
		# From two fields
		$d = $in{'db'};
		$t = $in{'table'};
		$in{'db'} =~ /^\S+$/ || &error($text{'cpriv_edb'});
		$in{'table'} =~ /^\S+$/ || &error($text{'cpriv_etable'});
		}
	else {
		# From selector
		($d, $t) = split(/\./, $in{'table'});
		}
	}
else {
	$d = &execute_sql_safe($master_db, "select * from columns_priv order by table_name,column_name");
	$u = $d->{'data'}->[$in{'idx'}];
	$access{'perms'} == 1 || &can_edit_db($u->[1]) ||
		&error($text{'perms_edb'});
	$d = $u->[1]; $t = $u->[3];
	&ui_print_header(undef, $text{'cpriv_title2'}, "", "edit_cpriv");
	}

print &ui_form_start("save_cpriv.cgi");
if ($in{'table'}) {
	if (defined($in{'db'})) {
		print &ui_hidden("table", $in{'db'}.".".$in{'table'});
		}
	else {
		print &ui_hidden("table", $in{'table'});
		}
	}
else {
	print &ui_hidden("oldhost", $u->[0]);
	print &ui_hidden("olddb", $u->[1]);
	print &ui_hidden("olduser", $u->[2]);
	print &ui_hidden("oldtable", $u->[3]);
	print &ui_hidden("oldfield", $u->[4]);
	}
print &ui_table_start($text{'cpriv_header'}, undef, 2);

# Apply to DB and table
print &ui_table_row($text{'cpriv_db'}, "<tt>$d</tt>");
print &ui_table_row($text{'cpriv_table'}, "<tt>$t</tt>");

# Table field
print &ui_table_row($text{'cpriv_field'},
	&ui_select("field", $in{'table'} ? '' : $u->[4],
		   [ $in{'table'} ? ( '' ) : ( ),
		     map { $_->{'field'} } &table_structure($d, $t) ], 1, 0, 1));

# Apply to user
print &ui_table_row($text{'cpriv_user'},
	&ui_opt_textbox("user", $u->[2], 20, $text{'cpriv_anon'}));

# Apply to host
print &ui_table_row($text{'cpriv_host'},
	&ui_opt_textbox("host", $u->[0] eq '%' ? '' : $u->[0], 40,
			$text{'cpriv_any'}));

# Permissions to grant
print &ui_table_row($text{'cpriv_perms'},
	&ui_select("perms", [ split(/,/, $u->[6]) ],
		   [ 'Select','Insert','Update','References' ], 4, 1));

print &ui_table_end();
print &ui_form_end([ $in{'table'} ? ( [ undef, $text{'create'} ] )
				  : ( [ undef, $text{'save'} ],
				      [ 'delete', $text{'delete'} ] ) ]);

&ui_print_footer('list_cprivs.cgi', $text{'cprivs_return'},
	"", $text{'index_return'});

