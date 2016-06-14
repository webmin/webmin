#!/usr/local/bin/perl
# restart.cgi
# Restart the running named
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'restart_ecannot'});
$access{'apply'} == 1 || $access{'apply'} == 3 ||
	&error($text{'restart_ecannot'});
&error_setup($text{'restart_err'});
my $err = &restart_bind();
&error($err) if ($err);

if ($access{'remote'}) {
	# Restart all slaves too
	&error_setup();
	my @slaveerrs = &restart_on_slaves();
	if (@slaveerrs) {
		&error(&text('restart_errslave',
		     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				      	    @slaveerrs)));
		}
	}

&webmin_log("apply");
&redirect($in{'return'} ? $ENV{'HTTP_REFERER'} : "");

