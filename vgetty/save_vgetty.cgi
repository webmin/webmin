#!/usr/local/bin/perl
# save_vgetty.cgi
# Save, create or delete a serial port configuration

require './vgetty-lib.pl';
&foreign_require("inittab", "inittab-lib.pl");
&ReadParse();
@inittab = &inittab::parse_inittab();
@vgt = &vgetty_inittabs();
if (!$in{'new'}) {
	($init) = grep { $_->{'id'} eq $in{'id'} } @vgt;
	$oldtty = $init->{'tty'};
	$oldtty = "/dev/$oldtty" if ($oldtty !~ /^\//);
	}
@conf = &get_config();
$rings = &find_value("rings", \@conf);
$ans = &find_value("answer_mode", \@conf);

&lock_file($inittab::config{'inittab_file'});
if ($in{'delete'}) {
	# Just deleting an inittab entry
	&inittab::delete_inittab($init);
	if (defined($in{'rings_def'})) {
		local $tf = &tty_opt_file($ans, $oldtty);
		&lock_file($tf);
		unlink($tf);
		&unlock_file($tf);
		}
	if (defined($in{'ans_def'})) {
		$tf = &tty_opt_file($rings, $oldtty);
		&lock_file($tf);
		unlink($tf);
		&unlock_file($tf);
		}
	}
else {
	# Validate and store inputs
	&error_setup($text{'vgetty_err'});
	$cmd = $in{'new'} ? &has_command("vgetty") : $init->{'vgetty'};
	if ($init->{'args'}) {
		$init->{'args'} =~ s/^\s+//;
		$cmd .= " $init->{'args'}";
		}
	if ($in{'tty'}) {
		$cmd .= " $in{'tty'}";
		$init->{'tty'} = $in{'tty'};
		}
	else {
		-r $in{'other'} || &error($text{'vgetty_etty'});
		$cmd .= " $in{'other'}";
		$init->{'tty'} = $in{'other'};
		}
	$newtty = $init->{'tty'};
	$newtty = "/dev/$newtty" if ($newtty !~ /^\//);
	if ($in{'new'} || $newtty ne $oldtty) {
		# Check for tty clash
		foreach $v (&vgetty_inittabs()) {
			local $vtty = $v->{'tty'};
			$vtty = "/dev/$vtty" if ($vtty !~ /^\//);
			&error(&text('vgetty_eclash', "<tt>$vtty</tt>"))
				if ($vtty eq $newtty);
			}
		}
	$init->{'process'} = $cmd;

	if (defined($in{'rings_def'})) {
		$tf = &tty_opt_file($rings, $init->{'tty'});
		&lock_file($tf);
		if (!$in{'new'} && $oldtty ne $newtty) {
			unlink(&tty_opt_file($rings, $oldtty));
			}
		if ($in{'rings_def'}) {
			unlink($tf);
			}
		else {
			$in{'rings'} =~ /^\d+$/ ||
				&error($text{'vgetty_erings'});
			$in{'rings'} >= 2 || &error($text{'vgetty_erings2'});
			&open_tempfile(TF, ">$tf");
			&print_tempfile(TF, $in{'rings'},"\n");
			&close_tempfile(TF);
			}
		&unlock_file($tf);
		}

	if (defined($in{'ans_def'})) {
		$tf = &tty_opt_file($ans, $init->{'tty'});
		&lock_file($tf);
		if (!$in{'new'} && $oldtty ne $newtty) {
			unlink(&tty_opt_file($ans, $oldtty));
			}
		if ($in{'ans_def'}) {
			unlink($tf);
			}
		else {
			$mode = &parse_answer_mode("ans");
			$mode || &error($text{'vgetty_eans'});
			&open_tempfile(TF, ">$tf");
			&print_tempfile(TF, $mode,"\n");
			&close_tempfile(TF);
			}
		&unlock_file($tf);
		}
	
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
	    "vgetty", $init->{'tty'}, $init);

&redirect("list_vgetty.cgi");

