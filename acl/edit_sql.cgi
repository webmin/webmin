#!/usr/local/bin/perl
# Show form for an external user / group database

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'sql'} || &error($text{'sql_ecannot'});
&ui_print_header(undef, $text{'sql_title'}, "");

my %miniserv;
&get_miniserv_config(\%miniserv);

print &ui_form_start("save_sql.cgi");
print &ui_table_start($text{'sql_header'}, undef, 2);

my ($proto, $user, $pass, $host, $prefix, $args) =
	&split_userdb_string($miniserv{'userdb'});
$proto ||= '';

# Build inputs for MySQL backend
my @mysqlgrid = ( );
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
my $mysqlgrid = &ui_grid_table(\@mysqlgrid, 2, 100);

# Build inputs for PostgreSQL backend
my @postgresqlgrid = ( );
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
my $postgresqlgrid = &ui_grid_table(\@postgresqlgrid, 2, 100);

# Build inputs for LDAP backend
my @ldapgrid = ( );
push(@ldapgrid,
     $text{'sql_host'},
     &ui_textbox("ldap_host", $proto eq "ldap" ? $host : "", 30));
push(@ldapgrid,
     $text{'sql_ssl'},
     &ui_radio("ldap_ssl", $args->{'scheme'} eq 'ldaps' ? 1 :
			   $args->{'tls'} ? 2 : 0,
	       [ [ 0, $text{'sql_ssl0'} ],
	         [ 1, $text{'sql_ssl1'} ],
	         [ 2, $text{'sql_ssl2'} ] ]));
push(@ldapgrid,
     $text{'sql_user'},
     &ui_textbox("ldap_user", $proto eq "ldap" ? $user : "", 30));
push(@ldapgrid,
     $text{'sql_pass'},
     &ui_textbox("ldap_pass", $proto eq "ldap" ? $pass : "", 30));
push(@ldapgrid,
     $text{'sql_prefix'},
     &ui_textbox("ldap_prefix", $proto eq "ldap" ? $prefix : "", 30));
push(@ldapgrid,
     $text{'sql_userclass'},
     &ui_textbox("ldap_userclass", $proto eq "ldap" && $args->{'userclass'} ?
				     $args->{'userclass'} : "webminUser", 30));
push(@ldapgrid,
     $text{'sql_groupclass'},
     &ui_textbox("ldap_groupclass", $proto eq "ldap" && $args->{'groupclass'} ?
				     $args->{'groupclass'} : "webminGroup",30));
push(@ldapgrid,
     &ui_button($text{'sql_schema'}, undef, 0,
		"onClick='window.location=\"schema.cgi\"'"), "");
my $ldapgrid = &ui_grid_table(\@ldapgrid, 2, 100);

print &ui_table_row(undef,
	&ui_radio_table("proto", $proto,
		[ [ '', $text{'sql_none'} ],
		  [ 'mysql', $text{'sql_mysql'}, $mysqlgrid ],
		  [ 'postgresql', $text{'sql_postgresql'}, $postgresqlgrid ],
		  [ 'ldap', $text{'sql_ldap'}, $ldapgrid ] ]), 2);

print &ui_table_row(undef,
	&ui_radio("addto", int($miniserv{'userdb_addto'} || 0),
		  [ [ 0, $text{'sql_addto0'} ],
		    [ 1, $text{'sql_addto1'} ] ]), 2);

print &ui_table_row(undef,
	&ui_radio("nocache", int($miniserv{'userdb_nocache'} || 0),
		  [ [ 0, $text{'sql_nocache0'} ],
		    [ 1, $text{'sql_nocache1'} ] ]), 2);

print &ui_table_row(undef,
	&ui_opt_textbox("timeout", $miniserv{'userdb_cache_timeout'},
			5, $text{'sql_timeout_def'}, $text{'sql_timeout_for'}).
			" ".$text{'sql_timeout_secs'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
