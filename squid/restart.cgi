#!/usr/local/bin/perl
# restart.cgi
# Restart the running squid process

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&ReadParse();
&error_setup($text{'restart_ftrs'});
my $err = &apply_configuration();
&error($err) if ($err);
&webmin_log("apply");
&redirect($in{'redir'});

