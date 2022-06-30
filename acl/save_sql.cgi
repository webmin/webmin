#!/usr/local/bin/perl
# Save user and group database

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'pass'} || &error($text{'sql_ecannot'});
&ReadParse();
&error_setup($text{'sql_err'});
my %miniserv;
&get_miniserv_config(\%miniserv);

# Parse inputs
my $p = $in{'proto'};
my ($host, $user, $pass, $prefix, $args);
if ($p eq 'mysql' || $p eq 'postgresql' || $p eq 'ldap') {
	&to_ipaddress($in{$p."_host"}) ||
	  $in{$p."_host"} =~ /^(\S+):(\d+)$/ && &to_ipaddress("$1") ||
	    &error($text{'sql_ehost'});
	$in{$p."_user"} =~ /^\S+$/ || &error($text{'sql_euser'});
	$in{$p."_pass"} =~ /^\S*$/ || &error($text{'sql_epass'});
	$host = $in{$p."_host"};
	$user = $in{$p."_user"};
	$pass = $in{$p."_pass"};
	}
if ($p eq 'mysql' || $p eq 'postgresql') {
	$in{$p."_db"} =~ /^\S+$/ || &error($text{'sql_edb'});
	$prefix = $in{$p."_db"};
	}
elsif ($p eq 'ldap') {
	$in{$p."_prefix"} =~ /^\S+$/ || &error($text{'sql_eprefix'});
	$in{$p."_prefix"} =~ /=/ || &error($text{'sql_eprefix2'});
	$prefix = $in{$p."_prefix"};
	$args = { };
	if ($in{'ldap_ssl'} == 0) {
		$args->{'scheme'} = 'ldap';
		}
	elsif ($in{'ldap_ssl'} == 1) {
		$args->{'scheme'} = 'ldaps';
		}
	elsif ($in{'ldap_ssl'} == 2) {
		$args->{'scheme'} = 'ldap';
		$args->{'tls'} = 1;
		}
	$in{'ldap_userclass'} =~ /^[a-z0-9]+$/i ||
		&error($text{'sql_euserclass'});
	$args->{'userclass'} = $in{'ldap_userclass'};
	$in{'ldap_groupclass'} =~ /^[a-z0-9]+$/i ||
		&error($text{'sql_egroupclass'});
	$args->{'groupclass'} = $in{'ldap_groupclass'};
	}

# Create and test connection string
my ($str, $err);
if ($p) {
	$str = &join_userdb_string($p, $user, $pass, $host,
				   $prefix, $args);
	$err = &validate_userdb($str, 1);
	&error($err) if ($err);
	}

&webmin_log("sql");

# Make sure tables exist
$err = &validate_userdb($str, 0);
if ($err && ($p eq "mysql" || $p eq "postgresql")) {
	# Tables are missing, need to create first
	&ui_print_header(undef, $text{'sql_title2'}, "");

	print &text('sql_tableerr', $err),"<p>\n";
	print $text{'sql_tableerr2'},"<br>\n";
	print &ui_form_start("maketables.cgi");
	print &ui_hidden("userdb", $str);
	print &ui_hidden("userdb_addto", $in{'addto'});
	print &ui_form_end([ [ undef, $text{'sql_make'} ] ]);

	print &ui_table_start(undef, undef, 2);
	foreach my $sql (&userdb_table_sql($str)) {
		print &ui_table_row(undef,
			"<pre>".&html_escape($sql)."</pre>", 2);
		}
	print &ui_table_end();

	&ui_print_footer("", $text{'index_return'});
	}
elsif ($err && $p eq "ldap") {
	# LDAP DN is missing
	&ui_print_header(undef, $text{'sql_title3'}, "");

	print &text('sql_dnerr', $err),"<p>\n";
	print $text{'sql_dnerr2'},"<br>\n";
	print &ui_form_start("makedn.cgi");
	print &ui_hidden("userdb", $str);
	print &ui_hidden("userdb_addto", $in{'addto'});
	print &ui_form_end([ [ undef, $text{'sql_makedn'} ] ]);

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Tables are OK, can save now
	&lock_file($ENV{'MINISERV_CONFIG'});
	$miniserv{'userdb'} = $str;
	$miniserv{'userdb_addto'} = $in{'addto'};
	$miniserv{'userdb_nocache'} = $in{'nocache'};
	if ($in{'timeout_def'}) {
		delete($miniserv{'userdb_cache_timeout'});
		}
	else {
		$in{'timeout'} =~ /^(\d+\.)?\d+$/ || &error($text{'sql_etimeout'});
		$miniserv{'userdb_cache_timeout'} = $in{'timeout'};
		}
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});
	&reload_miniserv();
	&redirect("");
	}

