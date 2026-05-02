#!/usr/bin/perl
# apply.cgi
# Apply the current configuration

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%config, %in, %text);
ReadParse();
error_setup($text{'apply_err'});

redirect("index.cgi") if ($config{'direct'});

my $err = apply_restore();
error($err) if ($err);

redirect("index.cgi");
