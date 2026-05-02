#!/usr/bin/perl
# apply.cgi
# Apply the current configuration

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'apply_err'});

my $err = apply_restore();
error($err) if ($err);

redirect("index.cgi");
