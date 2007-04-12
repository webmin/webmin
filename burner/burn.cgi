#!/usr/local/bin/perl
# burn.cgi
# Do a real or test burn of a CD

require './burner-lib.pl';
&ReadParse();
$profile = &get_profile($in{'id'});
&can_use_profile($profile) || &error($text{'edit_ecannot'});

if ($in{'cancel'}) {
	if ($in{'iso'}) {
		unlink($in{'iso'});
		}
	elsif ($in{'audio'}) {
		system("rm -rf $in{'audio'} >/dev/null 2>&1");
		}
	&redirect("");
	exit;
	}
if ($profile->{'type'} != 4) {
	if ($in{'iso'} && !-r $in{'iso'}) {
		&error(&text('burn_egone', "edit_profile.cgi?id=$profile->{'id'}"));
		}
	elsif ($in{'audio'} && !-d $in{'audio'}) {
		&error(&text('burn_egone2', "edit_profile.cgi?id=$profile->{'id'}"));
		}
	}

if ($in{'bg'}) {
	&ui_print_unbuffered_header(undef, $text{'burn_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'burn_title'}, "");
	}

if ($profile->{'type'} == 4) {
	# Copying a CD
	$cdrtemp = $config{'temp'} ? "$config{'temp'}/burner.bin"
				   : &tempname("burner.bin");
	if ($in{'second_step'}) {
		# Writing out a copied CD
		$cmd = "$config{'cdrdao'} write --device $config{'dev'}";
		$cmd .= " --speed $config{'speed'}";
		$cmd .= " --eject" if ($in{'eject'});
		$cmd .= " --driver $profile->{'dstdrv'}"
			if ($profile->{'dstdrv'});
		$cmd .= " $cdrtemp.toc";
		$cmd .= " ; rm -f $cdrtemp $cdrtemp.toc";
		}
	elsif ($profile->{'sdev'} eq $config{'dev'}) {
		# Using same drive .. need to create .toc and .bin files first
		$cmd = "$config{'cdrdao'} read-cd --device $config{'dev'} --datafile $cdrtemp --eject";
		$cmd .= " --driver $profile->{'srcdrv'}"
			if ($profile->{'srcdrv'});
		$cmd .= " $cdrtemp.toc";
		$second_step++;
		}
	else {
		# Copying from one drive to another
		$cmd = "$config{'cdrdao'} copy --device $config{'dev'} --source-device $profile->{'sdev'}";
		if ($profile->{'fly'}) {
			$cmd .= " --on-the-fly";
			}
		else {
			$cmd .= " --datafile $cdrtemp";
			}
		$cmd .= " --speed $config{'speed'}";
		$cmd .= " --eject" if ($in{'eject'});
		$cmd .= " --driver $profile->{'dstdrv'}"
			if ($profile->{'dstdrv'});
		$cmd .= " --source-driver $profile->{'srcdrv'}"
			if ($profile->{'srcdrv'});
		}
	}
elsif ($in{'iso'}) {
	# Burning data CD
	$cmd = "$config{'cdrecord'} -v dev=$config{'dev'} speed=$config{'speed'}";
	$cmd .= " $config{'extra'}" if ($config{'extra'});
	$cmd .= " -dummy" if ($in{'test'});
	$cmd .= " -eject" if ($in{'eject'} && !$in{'test'});
	$cmd .= " -isosize" if ($profile->{'isosize'});
	$cmd .= " blank=$in{'blank'}" if ($in{'blank'});
	$cmd .= " '$in{'iso'}'";
	}
else {
	# Burning audio CD
	$cmd = "$config{'cdrecord'} -v dev=$config{'dev'} speed=$config{'speed'}";
	$cmd .= " -dummy" if ($in{'test'});
	$cmd .= " -eject" if ($in{'eject'} && !$in{'test'});
	$cmd .= " -audio -swab -pad $in{'audio'}/*.raw";
	}

if ($in{'bg'} && !$second_step) {
	# Start in background
	if (!fork()) {
		close(STDIN); close(STDOUT); close(STDERR);
		system("$cmd >/dev/null 2>&1 </dev/null");
		if ($in{'temp'}) {
			if ($in{'iso'}) {
				unlink($in{'iso'});
				}
			else {
				system("rm -rf $in{'audio'} >/dev/null 2>&1");
				}
			}
		exit;
		}
	print "<b>",&text($in{'test'} ? 'burn_theader2' : 'burn_header2',
			  "<tt>$cmd</tt>"),"</b><p>\n";
	}
else {
	# Run command and show output
	print "<b>",&text($in{'test'} ? 'burn_theader' : 'burn_header',
			  "<tt>$cmd</tt>"),"</b><br>\n";
	print "<pre>";
	&foreign_require("proc", "proc-lib.pl");
	&foreign_call("proc", "safe_process_exec", $cmd, 0, 0, STDOUT,
		      undef, 1, 0);
	print "</pre>\n";
	$rv = $?;
	if ($in{'temp'}) {
		if ($in{'iso'}) {
			unlink($in{'iso'});
			}
		else {
			system("rm -rf $in{'audio'} >/dev/null 2>&1");
			}
		}
	if ($second_step && !$rv) {
		# Show button to write out data
		print "<center><form action=burn.cgi>\n";
		print "$text{'burn_seconddesc'}<p>\n";
		print "<input type=submit name=second_step ",
		      "value='$text{'burn_second'}'>\n";
		foreach $k (keys %in) {
			print "<input type=hidden name=$k value='$in{$k}'>\n";
			}
		print "</form></center>\n";
		}
	}

&ui_print_footer("edit_profile.cgi?id=$profile->{'id'}", $text{'edit_return'},
	"", $text{'index_return'});

