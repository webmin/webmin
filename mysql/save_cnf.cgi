#!/usr/local/bin/perl
# Save mysql server configuration options

require './mysql-lib.pl';
$access{'perms'} == 1 || &error($text{'cnf_ecannot'});
&error_setup($text{'cnf_err'});
&ReadParse();

# Get the mysqld section
foreach my $l (&get_all_mysqld_files()) {
	&lock_file($l);
	}
$conf = &get_mysql_config();
($mysqld) = grep { $_->{'name'} eq 'mysqld' } @$conf;
$mysqld || &error($text{'cnf_emysqld'});
$mems = $mysqld->{'members'};

# Parse mysql server inputs
if ($in{'port_def'}) {
	&save_directive($conf, $mysqld, "port", [ ]);
	}
else {
	$in{'port'} =~ /^\d+$/ && $in{'port'} > 0 && $in{'port'} < 65536 ||
		&error($text{'cnf_eport'});
	&save_directive($conf, $mysqld, "port", [ $in{'port'} ]);
	}

if ($in{'bind_def'}) {
	&save_directive($conf, $mysqld, "bind-address", [ ]);
	}
else {
	&check_ipaddress($in{'bind'}) ||
		&error($text{'cnf_ebind'});
	&save_directive($conf, $mysqld, "bind-address", [ $in{'bind'} ]);
	}

if ($in{'socket_def'}) {
	&save_directive($conf, $mysqld, "socket", [ ]);
	}
else {
	$in{'socket'} =~ /^\/\S+$/ ||
		&error($text{'cnf_esocket'});
	&save_directive($conf, $mysqld, "socket", [ $in{'socket'} ]);
	}

if ($in{'datadir_def'}) {
	&save_directive($conf, $mysqld, "datadir", [ ]);
	}
else {
	-d $in{'datadir'} || &error($text{'cnf_edatadir'});
	&save_directive($conf, $mysqld, "datadir", [ $in{'datadir'} ]);
	}

&save_directive($conf, $mysqld, "default-storage-engine",
		$in{'stor'} ? [ $in{'stor'} ] : [ ]);

my $ifpt_def_off = &get_innodb_file_per_table_default();
&save_directive($conf, $mysqld, "innodb_file_per_table",
	[ $in{'fpt'} ? ($ifpt_def_off ? 1 : undef) : 0 ]);

if ($in{'ilt_def'}) {
	&save_directive($conf, $mysqld, "innodb_lock_wait_timeout", [ ]);
	}
else {
	$in{'ilt'} =~ /^\d+$/ || &error($text{'cnf_eilt'});
	&save_directive($conf, $mysqld, "innodb_lock_wait_timeout",
			[ $in{'ilt'} ]);
	}

if ($in{'sqlm_def'}) {
	&save_directive($conf, $mysqld, "sql_mode", [ ]);
	}
else {
	$in{'sqlm'} =~ /^\S+$/ || &error($text{'cnf_esqlm'});
	&save_directive($conf, $mysqld, "sql_mode", [ $in{'sqlm'} ]);
	}

&save_directive($conf, $mysqld, "big-tables",
		$in{'big-tables'} ? [ "" ] : [ ]);

# Save slow query log options
&save_directive($conf, $mysqld, "slow_query_log",
		[ $in{'slow'} ]);
$in{'slow_file_def'} || $in{'slow_file'} =~ /^\S+$/ ||
	&error($text{'cnf_eslow_file'});
&save_directive($conf, $mysqld, "slow_query_log_file",
		$in{'slow_file_def'} ? [ ] : [ $in{'slow_file'} ]);
$in{'long_def'} || $in{'long'} =~ /^\d+$/ ||
	&error($text{'cnf_elong'});
&save_directive($conf, $mysqld, "long_query_time",
		$in{'long_def'} ? [ ] : [ $in{'long'} ]);

# Save set variables
%vars = &parse_set_variables(&find_value("set-variable", $mems));
foreach $w (@mysql_set_variables) {
	if ($in{$w."_def"}) {
		delete($vars{$w});
		}
	else {
		$in{$w} =~ /^\d+$/ || &error($text{"cnf_e".$w});
		$vars{$w} = $in{$w}.$in{$w."_units"};
		}
	}
@sets = ( );
foreach $v (keys %vars) {
	push(@sets, $v."=".$vars{$v});
	}
&save_directive($conf, $mysqld, "set-variable", \@sets);

# Save numeric variables
foreach $w (@mysql_number_variables, @mysql_byte_variables) {
	if ($in{$w."_def"}) {
		delete($vars{$w});
		&save_directive($conf, $mysqld, $w, [ ]);
		}
	else {
		$in{$w} =~ /^\d+[kmgt]?$/i || &error($text{"cnf_e".$w});
		&save_directive($conf, $mysqld, $w,
				[ $in{$w}.$in{$w."_units"} ]);
		}
	}

# Write out file
foreach my $l (&get_all_mysqld_files()) {
	&flush_file_lines($l, undef, 1);
	&unlock_file($l);
	}
if ($in{'restart'} && &is_mysql_running() > 0) {
	&stop_mysql();
	$err = &start_mysql();
	&error($err) if ($err);
	}
&webmin_log("cnf");
&redirect("");

