#!/usr/local/bin/perl
# Delete multiple sources

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'sdelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'sdelete_enone'});
foreach my $d (@d) {
	&check_dependencies('source', $d) &&
	    &error(&text('sdelete_eused', $d));
	}

&lock_file($config{'syslogng_conf'});
$conf = &get_config();
@dests = &find("source", $conf);
foreach my $d (@d) {
	($dest) = grep { $_->{'value'} eq $d } @dests;
	$dest || &error($text{'source_egone'});
	&save_directive($conf, undef, $dest, undef, 0);
	}

&unlock_file($config{'syslogng_conf'});
&webmin_log('delete', 'sources', scalar(@d));
&redirect("list_sources.cgi");
