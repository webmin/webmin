#!/usr/local/bin/perl
# Update options related to database connections

require './phpini-lib.pl';
&error_setup($text{'db_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

# Validate and save MySQL settings
&save_directive($conf, "mysql.allow_persistent",
		$in{"mysql.allow_persistent"} || undef);

if ($in{"mysql.max_persistent_def"}) {
	&save_directive($conf, "mysql.max_persistent", -1);
	}
else {
	$in{"mysql.max_persistent"} =~ /^\d+$/ ||
		&error($text{'db_emaxpersist'});
	&save_directive($conf, "mysql.max_persistent",
			$in{"mysql.max_persistent"});
	}

if ($in{"mysql.max_links_def"}) {
	&save_directive($conf, "mysql.max_links", -1);
	}
else {
	$in{"mysql.max_links"} =~ /^\d+$/ ||
		&error($text{'db_emaxlinks'});
	&save_directive($conf, "mysql.max_links",
			$in{"mysql.max_links"});
	}

if ($in{"mysql.connect_timeout_def"}) {
	&save_directive($conf, "mysql.connect_timeout", -1);
	}
else {
	$in{"mysql.connect_timeout"} =~ /^\d+$/ ||
		&error($text{'db_etimeout'});
	&save_directive($conf, "mysql.connect_timeout",
			$in{"mysql.connect_timeout"});
	}

if ($in{"mysql.default_host_def"}) {
	&save_directive($conf, "mysql.default_host", undef);
	}
else {
	&to_ipaddress($in{"mysql.default_host"}) ||
		&error($text{'db_ehost'});
	&save_directive($conf, "mysql.default_host",
			$in{"mysql.default_host"});
	}

if ($in{"mysql.default_port_def"}) {
	&save_directive($conf, "mysql.default_port", undef);
	}
else {
	$in{"mysql.default_port"} =~ /^\d+$/ ||
		&error($text{'db_eport'});
	&save_directive($conf, "mysql.default_port",
			$in{"mysql.default_port"});
	}

# Validate and save PostgreSQL settings
&save_directive($conf, "pgsql.allow_persistent",
		$in{"pgsql.allow_persistent"} || undef);
&save_directive($conf, "pgsql.auto_reset_persistent",
		$in{"pgsql.auto_reset_persistent"} || undef);

if ($in{"pgsql.max_persistent_def"}) {
	&save_directive($conf, "pgsql.max_persistent", -1);
	}
else {
	$in{"pgsql.max_persistent"} =~ /^\d+$/ ||
		&error($text{'db_emaxpersist'});
	&save_directive($conf, "pgsql.max_persistent",
			$in{"pgsql.max_persistent"});
	}

if ($in{"pgsql.max_links_def"}) {
	&save_directive($conf, "pgsql.max_links", -1);
	}
else {
	$in{"pgsql.max_links"} =~ /^\d+$/ ||
		&error($text{'db_emaxlinks'});
	&save_directive($conf, "pgsql.max_links",
			$in{"pgsql.max_links"});
	}

&flush_file_lines_as_user($in{'file'});
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("db", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));

