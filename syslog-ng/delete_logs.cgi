#!/usr/local/bin/perl
# Delete multiple logs

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'ddelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'ddelete_enone'});

&lock_file($config{'syslogng_conf'});
$conf = &get_config();
@dests = &find("log", $conf);
foreach my $d (@d) {
	($dest) = grep { $_->{'index'} == $d } @dests;
	$dest || &error($text{'log_egone'});
	&save_directive($conf, undef, $dest, undef, 0);
	}

&unlock_file($config{'syslogng_conf'});
&webmin_log('delete', 'logs', scalar(@d));
&redirect("list_logs.cgi");
