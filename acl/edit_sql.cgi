#!/usr/local/bin/perl
# Show form for an external user / group database

require './acl-lib.pl';
$access{'sql'} || &error($text{'sql_ecannot'});
&ui_print_header(undef, $text{'sql_title'}, "");
&get_miniserv_config(\%miniserv);

print &ui_form_start("save_sql.cgi");
print &ui_table_start($text{'sql_header'}, undef, 2);

($proto, $user, $pass, $host, $prefix, $args) =
	&split_userdb_string($miniserv{'userdb'});

# Build inputs for MySQL backend
@mysqlgrid = ( );
push(@mysqlgrid,
     $text{'sql_host'},
     &ui_textbox("mysql_host", $proto eq "mysql" ? $host : "", 30));
push(@mysqlgrid,
     $text{'sql_user'},
     &ui_textbox("mysql_user", $proto eq "mysql" ? $user : "", 30));
push(@mysqlgrid,
     $text{'sql_pass'},
     &ui_textbox("mysql_pass", $proto eq "mysql" ? $pass : "", 30));
push(@mysqlgrid,
     $text{'sql_db'},
     &ui_textbox("mysql_db", $proto eq "mysql" ? $prefix : "", 30));
$mysqlgrid = &ui_grid_table(\@mysqlgrid, 2, 100);

# Build inputs for PostgreSQL backend
@postgresqlgrid = ( );
push(@postgresqlgrid,
     $text{'sql_host'},
     &ui_textbox("postgresql_host", $proto eq "postgresql" ? $host : "", 30));
push(@postgresqlgrid,
     $text{'sql_user'},
     &ui_textbox("postgresql_user", $proto eq "postgresql" ? $user : "", 30));
push(@postgresqlgrid,
     $text{'sql_pass'},
     &ui_textbox("postgresql_pass", $proto eq "postgresql" ? $pass : "", 30));
push(@postgresqlgrid,
     $text{'sql_db'},
     &ui_textbox("postgresql_db", $proto eq "postgresql" ? $prefix : "", 30));
$postgresqlgrid = &ui_grid_table(\@postgresqlgrid, 2, 100);

# Build inputs for LDAP backend
@ldapgrid = ( );
push(@ldapgrid,
     $text{'sql_host'},
     &ui_textbox("ldap_host", $proto eq "ldap" ? $host : "", 30));
push(@ldapgrid,
     $text{'sql_user'},
     &ui_textbox("ldap_user", $proto eq "ldap" ? $user : "", 30));
push(@ldapgrid,
     $text{'sql_pass'},
     &ui_textbox("ldap_pass", $proto eq "ldap" ? $pass : "", 30));
push(@ldapgrid,
     $text{'sql_prefix'},
     &ui_textbox("ldap_prefix", $proto eq "ldap" ? $prefix : "", 30));
# XXX object classes?
$ldapgrid = &ui_grid_table(\@ldapgrid, 2, 100);

print &ui_table_row(undef,
	&ui_radio_table("proto", $proto,
		[ [ '', $text{'sql_none'} ],
		  [ 'mysql', $text{'sql_mysql'}, $mysqlgrid ],
		  [ 'postgresql', $text{'sql_postgresql'}, $postgresqlgrid ],
		  [ 'ldap', $text{'sql_ldap'}, $ldapgrid ] ]), 2);

print &ui_table_row(undef,
	&ui_radio("addto", int($miniserv{'userdb_addto'}),
		  [ [ 0, $text{'sql_addto0'} ],
		    [ 1, $text{'sql_addto1'} ] ]), 2);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
