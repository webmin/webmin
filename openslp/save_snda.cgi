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

local @scopes, @daaddr;
local $val = "";

# Process List Items
for($i=0; $i<3; $i++) {
	if (!$in{'useScopes'}) {
		push(@scopes, $val) if ($val=$in{"useScopesValue_$i"});
		}
	if (!$in{'DAAddresses'}) {
		push(@daaddr, $val) if ($val=$in{"DAAddressesValue_$i"});
		}
}
if (!$in{'useScopes'}) {
	&enable_list_line(@scopes,'useScopes');
	}
else {
	&disable_line('useScopes');
	}

if (!$in{'DAAddresses'}) {
	&enable_list_line(@daaddr,'DAAddresses');
	}
else {
	&disable_line('DAAddresses');
	}

&restart();
&redirect("");

