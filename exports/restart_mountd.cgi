#!/usr/local/bin/perl
# restart_mountd.cgi
# Do whatever is needed to apply changes to the exports file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './exports-lib.pl';
our (%text);    
&error_setup($text{'restart_err'});
my $err = &restart_mountd();
&error($err) if ($err);
&webmin_log('apply');
&redirect("");
