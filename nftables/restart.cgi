#!/usr/bin/perl
# restart.cgi
# Apply saved nftables configuration from the header action

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'apply_err'});
assert_acl('apply');

my $err = apply_restore();
error($err) if ($err);

webmin_log("apply");

# Only return to a page in this module
my $redir = $in{'redir'};
$redir = "index.cgi"
    if (!defined($redir) || $redir !~ /\A[\w.-]+\.cgi(?:\?[^\r\n]*)?\z/);
redirect($redir);
