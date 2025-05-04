#!/usr/local/bin/perl
# Show form for force sending a password reset link

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&foreign_require("webmin");
&error_setup($text{'forgot_err'});
&ReadParse();


