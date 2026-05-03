#!/usr/bin/perl
# restart.cgi
# Apply saved nftables configuration from the header action

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'apply_err'});

my $err = apply_restore();
error($err) if ($err);

webmin_log("apply");
redirect($in{'redir'} || "index.cgi");
