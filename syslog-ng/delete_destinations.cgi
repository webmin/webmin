#!/usr/local/bin/perl
# Delete multiple destinations

require './syslog-ng-lib.pl';
&ReadParse();
&error_setup($text{'ddelete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'ddelete_enone'});
foreach my $d (@d) {
          &check_dependencies('destination', $d) &&
	      &error(&text('ddelete_eused', $d));
	  }

&lock_file($config{'syslogng_conf'});
$conf = &get_config();
@dests = &find("destination", $conf);
foreach my $d (@d) {
	($dest) = grep { $_->{'value'} eq $d } @dests;
	$dest || &error($text{'destination_egone'});
	&save_directive($conf, undef, $dest, undef, 0);
	}

&unlock_file($config{'syslogng_conf'});
&webmin_log('delete', 'destinations', scalar(@d));
&redirect("list_destinations.cgi");
