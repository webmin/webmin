#!/usr/local/bin/perl
# save_mgetty.cgi
# Save, create or delete a serial port configuration

require './pap-lib.pl';
$access{'mgetty'} || &error($text{'mgetty_ecannot'});
&foreign_require("inittab", "inittab-lib.pl");
&ReadParse();
@inittab = &inittab::parse_inittab();
@mgt = &mgetty_inittabs();
if (!$in{'new'}) {
	($init) = grep { $_->{'id'} eq $in{'id'} } @mgt;
	$oldtty = $init->{'tty'};
	$oldtty = "/dev/$oldtty" if ($oldtty !~ /^\//);
	}

&lock_file($inittab::config{'inittab_file'});
if ($in{'delete'}) {
	# Just deleting an inittab entry
	&inittab::delete_inittab($init);
	}
else {
	# Validate and store inputs
	&error_setup($text{'mgetty_err'});
	$cmd = $in{'new'} ? &has_command($config{'mgetty'}) : $init->{'mgetty'};
	$cmd .= " -r" if ($in{'direct'});
	if (!$in{'speed_def'}) {
		$in{'speed'} =~ /^\d+$/ || &error($text{'mgetty_espeed'});
		$cmd .= " -s $in{'speed'}";
		}
	$in{'rings'} =~ /^\d+$/ || &error($text{'mgetty_eanswer'});
	$cmd .= " -n $in{'rings'}" if ($in{'rings'} != 1);
	if ($in{'mode'} == 1) {
		$cmd .= " -D";
		}
	elsif ($in{'mode'} == 2) {
		$cmd .= " -F";
		}
	if (!$in{'back_def'}) {
		$in{'back'} =~ /^\d+$/ || &error($text{'mgetty_eback'});
		$cmd .= " -R $in{'back'}";
		}
	if (!$in{'prompt_def'}) {
		$cmd .= $in{'prompt'} =~ /"/ ? " -p '$in{'prompt'}'"
					     : " -p \"$in{'prompt'}\"";
		}
	if ($init->{'args'}) {
		$init->{'args'} =~ s/^\s+//;
		$cmd .= " $init->{'args'}";
		}
	if ($in{'tty'}) {
		$cmd .= " $in{'tty'}";
		$init->{'tty'} = $in{'tty'};
		}
	else {
		-r $in{'other'} || &error($text{'mgetty_etty'});
		$cmd .= " $in{'other'}";
		$init->{'tty'} = $in{'other'};
		}
	$newtty = $init->{'tty'};
	$newtty = "/dev/$newtty" if ($newtty !~ /^\//);
	if ($in{'new'} || $newtty ne $oldtty) {
		# Check for tty clash
		foreach $m (&mgetty_inittabs()) {
			local $mtty = $m->{'tty'};
			$mtty = "/dev/$mtty" if ($mtty !~ /^\//);
			&error(&text('mgetty_eclash', "<tt>$mtty</tt>"))
				if ($mtty eq $newtty);
			}
		}
	$cmd .= " $init->{'ttydefs'}" if ($init->{'ttydefs'});
	$init->{'process'} = $cmd;
	
	if ($in{'new'}) {
		$maxid = 1;
		foreach $i (@inittab) {
			$maxid = $i->{'id'} if ($i->{'id'} =~ /^\d+$/ &&
						$i->{'id'} > $maxid);
			}
		$init->{'id'} = $maxid + 1;
		$init->{'levels'} = [ 2, 3, 4, 5 ];
		$init->{'action'} = "respawn";
		&inittab::create_inittab($init);
		}
	else {
		&inittab::modify_inittab($init);
		}
	}
&unlock_file($inittab::config{'inittab_file'});
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    "mgetty", $init->{'tty'}, $init);

&redirect("list_mgetty.cgi");

