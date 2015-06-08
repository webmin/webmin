#!/usr/local/bin/perl
# Enable or disable firewalld at boot time

use strict;
use warnings;
require './firewalld-lib.pl';
our (%in, %config);
&ReadParse();
&foreign_require("init");
if ($in{'boot'}) {
	&init::enable_at_boot($config{'init_name'});
	}
else {
	&init::disable_at_boot($config{'init_name'});
	}
&webmin_log($in{'boot'} ? "bootup" : "bootdown");
&redirect("index.cgi?zone=".&urlize($in{'zone'}));

