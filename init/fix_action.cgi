#!/usr/local/bin/perl
# fix_action.cgi
# Convert an action from a run-level file to a proper action in init.d

require './init-lib.pl';
$access{'bootup'} == 1 || &error("You are not allowed to edit bootup actions");
$rl = $ARGV[0];
$ss = $ARGV[1];
$num = $ARGV[2];
$ac = $ARGV[3];

$oldfile = &runlevel_filename($rl, $ss, $num, $ac);
$newfile = &action_filename($ac);
while(-r $newfile) {
	if ($ac =~ /^(.*)_([0-9]+)$/) { $ac = "$1_".($2+1); }
	else { $ac = $ac."_1"; }
	$newfile = &action_filename($ac);
	}
`mv $oldfile $newfile`;
&add_rl_action($ac, $rl, $ss, $num);
&redirect("edit_action.cgi?0+$ac");

