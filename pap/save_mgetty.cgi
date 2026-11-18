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
		$in{'speed'} =~ /^\d+\z/ || &error($text{'mgetty_espeed'});
		$cmd .= " -s $in{'speed'}";
		}
	$in{'rings'} =~ /^\d+\z/ || &error($text{'mgetty_eanswer'});
	$cmd .= " -n $in{'rings'}" if ($in{'rings'} != 1);
	if ($in{'mode'} == 1) {
		$cmd .= " -D";
		}
	elsif ($in{'mode'} == 2) {
		$cmd .= " -F";
		}
	if (!$in{'back_def'}) {
		$in{'back'} =~ /^\d+\z/ || &error($text{'mgetty_eback'});
		$cmd .= " -R $in{'back'}";
		}
	if (!$in{'prompt_def'}) {
		# The command is run by a shell, so quote the prompt in a way
		# that keeps it literal
		$in{'prompt'} =~ /[\r\n\0]/ && &error($text{'mgetty_eprompt'});
		if ($in{'prompt'} !~ /'/) {
			$cmd .= " -p '$in{'prompt'}'";
			}
		elsif ($in{'prompt'} !~ /["\$`\\]/) {
			$cmd .= " -p \"$in{'prompt'}\"";
			}
		else {
			&error($text{'mgetty_eprompt'});
			}
		}
	if ($init->{'args'}) {
		$init->{'args'} =~ s/^\s+//;
		$cmd .= " $init->{'args'}";
		}
	# Device names end up in inittab, so only allow plain paths
	if ($in{'tty'}) {
		$in{'tty'} =~ /^[A-Za-z0-9\/][A-Za-z0-9\/\._\-]*\z/ &&
		    $in{'tty'} !~ /\.\./ || &error($text{'mgetty_etty'});
		$cmd .= " $in{'tty'}";
		$init->{'tty'} = $in{'tty'};
		}
	else {
		$in{'other'} =~ /^\/[A-Za-z0-9\/\._\-]+\z/ && -r $in{'other'} ||
			&error($text{'mgetty_etty'});
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

