#!/usr/local/bin/perl
# save_log.cgi
# Save logging options

require './wuftpd-lib.pl';
&error_setup($text{'log_err'});
&ReadParse();

&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

$in{'commands'} =~ s/\0/,/g;
if ($in{'commands'}) {
	push(@log, { 'name' => 'log',
		     'values' => [ 'commands', $in{'commands'} ] } );
	}

$in{'transfers'} =~ s/\0/,/g;
if ($in{'transfers'}) {
	push(@log, { 'name' => 'log',
		     'values' => [ 'transfers', $in{'transfers'},
				   $in{'direction'} ] } );
	}

$in{'security'} =~ s/\0/,/g;
if ($in{'security'}) {
	push(@log, { 'name' => 'log',
		     'values' => [ 'security', $in{'security'} ] } );
	}

if ($in{'syslog'} == 1) {
	push(@log, { 'name' => 'log',
		     'values' => [ 'syslog' ] } );
	}
elsif ($in{'syslog'} == 2) {
	push(@log, { 'name' => 'log',
		     'values' => [ 'syslog+xferlog' ] } );
	}


&save_directive($conf, 'log', \@log);
&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("log", undef, undef, \%in);
&redirect("");
