#!/usr/local/bin/perl
# edit_user.cgi
# Display a form for editing or creating a MySQL user

require './mysql-lib.pl';
&ReadParse();
$access{'perms'} == 1 || &error($text{'perms_ecannot'});

if ($in{'new'}) {
	&ui_print_header(undef, $text{'user_title1'}, "", "create_user");
	}
else {
	&ui_print_header(undef, $text{'user_title2'}, "", "edit_user");
	if ($in{'user'}) {
		$d = &execute_sql_safe($master_db,
				       "select * from user where user = ?",
				       $in{'user'});
		$u = $d->{'data'}->[0];
		}
	else {
		$d = &execute_sql_safe($master_db,
				       "select * from user order by user");
		$u = $d->{'data'}->[$in{'idx'}];
		}
	}

# Check if this is a Virtualmin-managed user
if (!$in{'new'} && &foreign_check("virtual-server")) {
	&foreign_require("virtual-server");
	my $d = &virtual_server::get_domain_by("mysql_user", $u->[1],
					       "parent", "");
	$d ||= &virtual_server::get_domain_by("user", $u->[1],
                                              "parent", "");
	if ($d) {
		print "<b>",&text('user_vwarning',
			&virtual_server::show_domain_name($d)),"</b><p>\n";
		}
	}

# Form header
print &ui_form_start("save_user.cgi", "post");
if ($in{'new'}) {
	print &ui_hidden("new", 1);
	}
else {
	print &ui_hidden("olduser", $u->[1]);
	print &ui_hidden("oldhost", $u->[0]);
	}
print &ui_table_start($text{'user_header'}, undef, 2);
%sizes = &table_field_sizes($master_db, "user");
%fieldmap = map { $_->{'field'}, $_->{'index'} }
		&table_structure($master_db, "user");

# Username field
print &ui_table_row($text{'user_user'},
	&ui_opt_textbox("mysqluser", $u->[1], $sizes{'user'},
			$text{'user_all'}));

# Password field
print &ui_table_row($text{'user_pass'},
	&ui_radio("mysqlpass_mode", $in{'new'} ? 0 : $u->[2] ? 1 : 2,
		  [ [ 2, $text{'user_none'} ],
		    $in{'new'} ? ( ) : ( [ 1, $text{'user_leave'} ] ),
		    [ 0, $text{'user_set'} ] ])." ".
	&ui_password("mysqlpass", undef, 20));

# Allowed host / network
print &ui_table_row($text{'user_host'},
	&ui_opt_textbox("host", $u->[0] eq '%' ? '' : $u->[0], 40,
			$text{'user_any'}));

# User's permissions
foreach my $f (&priv_fields('user')) {
	push(@opts, $f);
	push(@sel, $f->[0]) if ($u->[$fieldmap{$f->[0]}] eq 'Y');
	}
print &ui_table_row($text{'user_perms'},
	&ui_select("perms", \@sel, \@opts, 10, 1, 1));

# Various per-user limits
$remote_mysql_version = &get_remote_mysql_version();
foreach $f ('max_user_connections', 'max_connections',
	    'max_questions', 'max_updates') {
	if ($remote_mysql_version >= 5 && $fieldmap{$f}) {
		print &ui_table_row($text{'user_'.$f},
			&ui_opt_textbox($f,
				$u->[$fieldmap{$f}] || undef,
				5, $text{'user_maxunlimited'},
				$text{'user_maxatmost'}));
		}
	}

# SSL needed?
if ($remote_mysql_version >= 5 && $fieldmap{'ssl_type'}) {
	print &ui_table_row($text{'user_ssl'},
		&ui_select("ssl_type", uc($u->[$fieldmap{'ssl_type'}]),
			[ [ '', $text{'user_ssl_'} ],
			  [ 'ANY', $text{'user_ssl_any'} ],
			  [ 'X509', $text{'user_ssl_x509'} ] ],
			1, 0, 1));
	print &ui_table_row($text{'user_cipher'},
		&ui_textbox("ssl_cipher", $u->[$fieldmap{'ssl_cipher'}], 80));
	}

print &ui_table_end();
print &ui_form_end([ $in{'new'} ? ( [ undef, $text{'create'} ] )
				: ( [ undef, $text{'save'} ],
				    [ 'delete', $text{'delete'} ] ) ]);

&ui_print_footer('list_users.cgi', $text{'users_return'},
	"", $text{'index_return'});

