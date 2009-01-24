#!/usr/local/bin/perl
# Show form for SpamAssassin DB options

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("db");
&ui_print_header($header_subtext, $text{'db_title'}, "");
$conf = &get_config();

print "$text{'db_desc'}<p>\n";
&start_form("save_db.cgi", $text{'db_header'});

# Work out backend type
$dsn = &find_value("user_scores_dsn", $conf);
if ($dsn =~ /^DBI:([^:]+):([^:]+):([^:]+)(:(\d+))?$/) {
	# To database
	$mode = 1;
	($dbdriver, $dbdb, $dbhost, $dbport) = ($1, $2, $3, $5);
	}
elsif ($dsn =~ /^ldap:\/\/([^:]+)(:(\d+))?\/([^\?]+)\?([^\?]+)\?([^\?]+)\?([^=]+)=__USERNAME__/) {
	# To LDAP
	$mode = 3;
	($ldaphost, $ldapport, $ldapdn, $ldapattr, $ldapscope, $ldapuid) =
 		($1, $3, $4, $5, $6, $7);
	}
elsif ($dsn) {
	$mode = 4;
	}
else {
	$mode = 0;
	}

# Generate input blocks for SQL and LDAP
$dbtable = &ui_table_start(undef, undef, 2, [ "nowrap" ]);
$dbtable .= &ui_table_row($text{'db_dbdriver'},
		&ui_select("dbdriver", $dbdriver || "mysql",
			[ [ "mysql", "MySQL" ], [ "Pg", "PostgreSQL" ] ],
			1, 0, 1));
$dbtable .= &ui_table_row($text{'db_dbhost'},
		&ui_textbox("dbhost", $dbhost, 40));
$dbtable .= &ui_table_row($text{'db_dbdb'},
		&ui_textbox("dbdb", $dbdb, 40));
$dbtable .= &ui_table_row($text{'db_dbport'},
		&ui_opt_textbox("dbport", $dbport, 5, $text{'default'}));
$dbtable .= &ui_table_end();

$ldaptable = &ui_table_start(undef, undef, 2, [ "nowrap" ]);
$ldaptable .= &ui_table_row($text{'db_ldaphost'},
		&ui_textbox("ldaphost", $ldaphost, 40));
$ldaptable .= &ui_table_row($text{'db_ldapport'},
		&ui_opt_textbox("ldapport", $ldapport, 5, $text{'default'}));
$ldaptable .= &ui_table_row($text{'db_ldapdn'},
		&ui_textbox("ldapdn", $ldapdn, 40));
$ldaptable .= &ui_table_row($text{'db_ldapattr'},
		&ui_textbox("ldapattr", $ldapattr, 20));
$ldaptable .= &ui_table_row($text{'db_ldapscope'},
		&ui_select("ldapscope", $ldapscope || "sub",
			   [ [ "sub", $text{'db_ldapsub'} ],
			     [ "one", $text{'db_ldapone'} ],
			     [ "base", $text{'db_ldapbase'} ] ], 1, 0, 1));
$ldaptable .= &ui_table_row($text{'db_ldapuid'},
		&ui_textbox("ldapuid", $ldapuid || "uid", 20));
$ldaptable .= &ui_table_end();


# Show backend type selector
print &ui_table_row($text{'db_dsn'},
   &ui_radio_table("mode", $mode,
	[ [ 0, $text{'db_mode0'} ],
	  [ 1, $text{'db_mode1'}, $dbtable ],
	  [ 3, $text{'db_mode3'}, $ldaptable ],
	  [ 4, $text{'db_mode4'},
	       &ui_textbox("dsn", $dsn, 60) ] ]));

print &ui_table_hr();

# DB login
$user = &find("user_scores_sql_username", $conf);
print &ui_table_row($text{'db_user'},
	&opt_field("user_scores_sql_username", $user, 20, undef));

# DB password
$pass = &find("user_scores_sql_password", $conf);
print &ui_table_row($text{'db_pass'},
	&opt_field("user_scores_sql_password", $pass, 20, undef));

print &ui_table_hr();

# LDAP login
$user = &find("user_scores_ldap_username", $conf);
print &ui_table_row($text{'db_luser'},
	&opt_field("user_scores_ldap_username", $user, 40, undef));

# LDAP password
$pass = &find("user_scores_ldap_password", $conf);
print &ui_table_row($text{'db_lpass'},
	&opt_field("user_scores_ldap_password", $pass, 20, undef));

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

