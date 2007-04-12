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

local @dadisc, @mctime, @inter;
local $val;

# Process List Items
for($i=0; $i<5; $i++) {
	if (!$in{'DADiscoveryTimeouts'}) {
		push(@dadisc, $val) if ($val=$in{"DADiscoveryTimeoutsValue_$i"});
		}
	if (!$in{'multicastTimeouts'}) {
		push(@mctime, $val) if ($val=$in{"multicastTimeoutsValue_$i"});
		}
	if (!$in{'interfaces'}) {
		push(@inter, $val) if ($val=$in{"interfacesValue_$i"});
		}
}
if (!$in{'DADiscoveryTimeouts'}) {
	&enable_list_line(@dadisc,'DADiscoveryTimeouts');
	}
else {
	&disable_line('DADiscoveryTimeouts');
	}

if (!$in{'multicastTimeouts'}) {
	&enable_list_line(@mctime,'multicastTimeouts');
	}
else {
	&disable_line('multicastTimeouts');
	}

if (!$in{'interfaces'}) {
	&enable_list_line(@inter,'interfaces');
	}
else {
	&disable_line('interfaces');
	}

# Process Boolean Items
if ($in{'isBroadcastOnly'}) {
	&enable_single_val_line('true','isBroadcastOnly');
	}
else {
	&disable_line('isBroadcastOnly');
}
if (!$in{'passiveDADetection'}) {
	&enable_single_val_line('false','passiveDADetection');
	}
else {
	&disable_line('passiveDADetection');
}
if (!$in{'activeDADetection'}) {
	&enable_single_val_line('false','activeDADetection');
	}
else {
	&disable_line('activeDADetection');
}

# Process single-value Items
if (!$in{'DAActiveDiscoveryInterval'}) {
	&enable_single_val_line($in{'DAActiveDiscoveryIntervalValue'},'DAActiveDiscoveryInterval');
	}
else {
	&disable_line('DAActiveDiscoveryInterval');
}
if (!$in{'multicastTTL'}) {
	&enable_single_val_line($in{'multicastTTLValue'},'multicastTTL');
	}
else {
	&disable_line('multicastTTL');
}
if (!$in{'DADiscoveryMaximumWait'}) {
	&enable_single_val_line($in{'DADiscoveryMaximumWaitValue'},'DADiscoveryMaximumWait');
	}
else {
	&disable_line('DADiscoveryMaximumWait');
}
if (!$in{'HintsFile'}) {
	&enable_single_val_line($in{'HintsFileValue'},'HintsFile');
	}
else {
	&disable_line('HintsFile');
}
if (!$in{'multicastMaximumWait'}) {
	&enable_single_val_line($in{'multicastMaximumWaitValue'},'multicastMaximumWait');
	}
else {
	&disable_line('multicastMaximumWait');
}
if (!$in{'unicastMaximumWait'}) {
	&enable_single_val_line($in{'unicastMaximumWaitValue'},'unicastMaximumWait');
	}
else {
	&disable_line('unicastMaximumWait');
}
if (!$in{'randomWaitBound'}) {
	&enable_single_val_line($in{'randomWaitBoundValue'},'randomWaitBound');
	}
else {
	&disable_line('randomWaitBound');
}
if (!$in{'MTU'}) {
	&enable_single_val_line($in{'MTUValue'},'MTU');
	}
else {
	&disable_line('MTU');
}

&restart();
&redirect("");

