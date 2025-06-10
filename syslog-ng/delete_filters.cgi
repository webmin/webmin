#!/usr/local/bin/perl
# Delete multiple filters

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'fdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'fdelete_enone'});
foreach my $d (@d) {
	&check_dependencies('filter', $d) &&
	    &error(&text('fdelete_eused', $d));
	}

&lock_file($config{'syslogng_conf'});
$conf = &get_config();
@dests = &find("filter", $conf);
foreach my $d (@d) {
	($dest) = grep { $_->{'value'} eq $d } @dests;
	$dest || &error($text{'filter_egone'});
	&save_directive($conf, undef, $dest, undef, 0);
	}

&unlock_file($config{'syslogng_conf'});
&webmin_log('delete', 'filters', scalar(@d));
&redirect("list_filters.cgi");
