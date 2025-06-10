#!/usr/local/bin/perl
#
# An OpenSLP webmin module
# by Monty Charlton <monty@caldera.com>,
#
# Copyright (c) 2000 Caldera Systems
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#

require './slp-lib.pl';
&ReadParse();

if ($in{'traceDATraffic'}) {
	&enable_single_val_line('true','traceDATraffic');
	}
else {
	&disable_line('traceDATraffic');
}
if ($in{'traceMsg'}) {
	&enable_single_val_line('true','traceMsg');
	}
else {
	&disable_line('traceMsg');
}
if ($in{'traceDrop'}) {
	&enable_single_val_line('true','traceDrop');
	}
else {
	&disable_line('traceDrop');
}

if ($in{'traceReg'}) {
	&enable_single_val_line('true','traceReg');
	}
else {
	&disable_line('traceReg');
}


&restart();
&redirect("");

