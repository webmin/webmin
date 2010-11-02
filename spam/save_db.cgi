#!/usr/local/bin/perl
# Save LDAP and SQL database options

require './spam-lib.pl';
&error_setup($text{'db_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("db");
&execute_before("db");
&lock_spam_files();
$conf = &get_config();

# Parse backend DSN
if ($in{'mode'} == 0) {
	# Files only
	$dsn = undef;
	}
elsif ($in{'mode'} == 1) {
	# Database of some type
	&to_ipaddress($in{'dbhost'}) || &error($text{'db_edbhost'});
	$in{'dbdb'} =~ /^[a-z0-9\.\-\_]+$/ || &error($text{'db_edbdb'});
	$in{'dbport_def'} || $in{'dbport'} =~ /^\d+$/ ||
		&error($text{'db_edbport'});
	$dsn = join(":", "DBI", $in{'dbdriver'}, $in{'dbdb'}, $in{'dbhost'});
	$dsn .= ":".$in{'dbport'} if (!$in{'dbport_def'});
	}
elsif ($in{'mode'} == 3) {
	# LDAP
	&to_ipaddress($in{'ldaphost'}) || &to_ip6address($in{'ldaphost'}) ||
		&error($text{'db_eldaphost'});
	$in{'ldapport_def'} || $in{'ldapport'} =~ /^\d+$/ ||
		&error($text{'db_eldapport'});
	$in{'ldapdn'} =~ /^\S+$/ || &error($text{'db_eldapdn'});
	$in{'ldapattr'} =~ /^\S+$/ || &error($text{'db_eldapattr'});
	$in{'ldapuid'} =~ /^\S+$/ || &error($text{'db_eldapuid'});
	$dsn = "ldap://".$in{'ldaphost'}.
	       ($in{'ldapport_def'} ? "" : ":".$in{'ldapport'})."/".
	       $in{'ldapdn'}."?".$in{'ldapattr'}."?".$in{'ldapscope'}."?".
	       $in{'ldapuid'}."=__USERNAME__";
	}
else {
	# Other DSN
	$in{'dsn'} =~ /\S/ || &error($text{'db_edsn'});
	$dsn = $in{'dsn'};
	}
&save_directives($conf, "user_scores_dsn", [ $dsn ], 1);

# Parse username and password
&parse_opt($conf, "user_scores_sql_username", \&username_check);
&parse_opt($conf, "user_scores_sql_password");
&parse_opt($conf, "user_scores_ldap_username", \&username_check);
&parse_opt($conf, "user_scores_ldap_password");

&flush_file_lines();
&unlock_spam_files();
&execute_after("db");
&webmin_log("db");
&redirect($redirect_url);

sub username_check
{
return $_[0] =~ /^\S+$/ ? undef : $text{'db_eusername'};
}

