#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
#
# Start postfix

require './postfix-lib.pl';

$access{'startstop'} || &error($text{'start_ecannot'});
&error_setup($text{'start_efailed'});
$err = &start_postfix();
&error($err) if ($err);
&webmin_log("start");
&redirect("");

