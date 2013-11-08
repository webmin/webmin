#!/usr/local/bin/perl
# Save, update or delete a burn profile, and maybe start the burn process

require './burner-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

if ($in{'id'}) {
	$profile = &get_profile($in{'id'});
	&can_use_profile($profile) || &error($text{'edit_ecannot'});
	}
else {
	$profile = { 'type' => $in{'type'} };
	$access{'create'} || &error($text{'edit_ecannot'});
	}

if (!$access{'edit'}) {
	# No need to save, because we cannot
	}
elsif ($in{'delete'}) {
	# Just delete a profile
	&delete_profile($profile);
	}
else {
	# Validate inputs
	$in{'name'} || &error($text{'save_ename'});
	$profile->{'name'} = $in{'name'};
	if ($profile->{'type'} == 1) {
		# Validate single ISO inputs
		-r $in{'iso'} || &error($text{'save_eiso'});
		&can_directory($in{'iso'}) || &error($text{'save_ecannot1'});
		$profile->{'iso'} = $in{'iso'};
		$profile->{'isosize'} = $in{'isosize'};
		}
	elsif ($profile->{'type'} == 2) {
		# Validate multi-directory inputs
		foreach $k (keys %$profile) {
			delete($profile->{$k}) if ($k =~ /^(source_|dest_)/);
			}
		local $j = 0;
		for($i=0; defined($s = $in{"source_$i"}); $i++) {
			next if (!$s);
			-d $s || -r $s || &error(&text('save_esource', $s));
			&can_directory($s) ||
				&error(&text('save_ecannot2', $s));
			$in{"dest_$i"} =~ /^\/\S*$/ ||
				&error(&text('save_edest', $s));
			$profile->{"source_$j"} = $s;
			$profile->{"dest_$j"} = $in{"dest_$i"};
			$j++;
			}
		$j || &error($text{'save_edirs'});
		$profile->{'rock'} = $in{'rock'};
		$profile->{'joliet'} = $in{'joliet'};
		$profile->{'netatalk'} = $in{'netatalk'};
		$profile->{'cap'} = $in{'cap'};
		$profile->{'long'} = $in{'long'};
		$profile->{'trans'} = $in{'trans'};
		$profile->{'volid'} = $in{'volid'};
		}
	elsif ($profile->{'type'} == 3) {
		# Validate audio track inputs .. each must be either an
		# mp3 file or a directory
		foreach $k (keys %$profile) {
			delete($profile->{$k}) if ($k =~ /^source_/);
			}
		local $j = 0;
		for($i=0; defined($s = $in{"source_$i"}); $i++) {
			next if (!$s);
			-d $s || -r $s || &error(&text('save_emp3', $s));
			&can_directory($s) ||
				&error(&text('save_ecannot3', $s));
			$profile->{"source_$j"} = $s;
			$j++;
			}
		$j || &error($text{'save_emp3s'});
		}
	elsif ($profile->{'type'} == 4) {
		# Validate device file inputs
		if ($in{'sdev'} eq '') {
			-r $in{'other'} || &error($text{'save_eother'});
			$profile->{'sdev'} = $in{'other'};
			$profile->{'sdesc'} = $in{'other'};
			}
		else {
			$profile->{'sdev'} = $in{'sdev'};
			foreach $d (&list_cdrecord_devices()) {
				$profile->{'sdesc'} = $d->{'name'}
					if ($d->{'dev'} eq $profile->{'sdev'});
				}
			}
		&can_directory($profile->{'sdev'}) ||
			&error($text{'save_ecannot4'});
		$profile->{'fly'} = $in{'fly'};
		$profile->{'srcdrv'} = $in{'srcdrv'};
		$profile->{'dstdrv'} = $in{'dstdrv'};
		}

	# Save or create the profile
	&save_profile($profile);
	if ($in{'new'} && !&can_use_profile($profile)) {
		# Add to this user's ACL
		$access{'profiles'} = join(" ", split(/\s+/,
				$access{'profiles'}), $profile->{'id'});
		&save_module_acl(\%access);
		}
	}

if ($in{'burn'} || $in{'test'}) {
	&ui_print_unbuffered_header(undef, $text{'burn_title'}, "");

	if (!$config{'dev'}) {
		# Cannot burn until device is set
		print "<p>",&text('burn_edev', "edit_dev.cgi"),"<p>\n";
		&ui_print_footer("", $text{"index_return"});
		exit;
		}

	local ($iso, $temp, $msg);
	if ($profile->{'type'} == 1) {
		# No preparation to do
		$iso = $profile->{'iso'};
		$temp = 0;
		$msg = &text($in{'test'} ? 'burn_rutest1' : 'burn_rusure1',
			     "<tt>$iso</tt>");
		}
	elsif ($profile->{'type'} == 2) {
		# Need to build the ISO image
		$temp = 1;
		$iso = $config{'temp'} ? "$config{'temp'}/burner.iso"
				       : &tempname("burner.iso");
		local $cmd = "$config{'mkisofs'} -graft-points -o $iso";
		$cmd .= " -J" if ($profile->{'joliet'});
		$cmd .= " --netatalk" if ($profile->{'netatalk'});
		$cmd .= " --cap" if ($profile->{'cap'});
		$cmd .= " -l" if ($profile->{'long'});
		$cmd .= " -T" if ($profile->{'trans'});
		if ($profile->{'rock'} == 2) {
			$cmd .= " -r";
			}
		elsif ($profile->{'rock'} == 1) {
			$cmd .= " -R";
			}
		if ($profile->{'volid'}) {
			$cmd .= " -V '$profile->{'volid'}'";
			}
		$cmd .= " -N" if ($config{'novers'});
		$cmd .= " -U" if ($config{'notrans'});
		$cmd .= " -f" if ($config{'fsyms'});
		$cmd .= " -nobak" if ($config{'nobak'});
		for($i=0; defined($profile->{"source_$i"}); $i++) {
			local $d = quotemeta($profile->{"dest_$i"});
			$d .= "/" if ($d !~ /\/$/);
			$cmd .= " ".$d."=".quotemeta($profile->{"source_$i"});
			}

		print "<b>",&text('burn_mheader', "<tt>$cmd</tt>"),"</b><br>\n";
		print "<pre>";
		open(MAKE, "$cmd 2>&1 |");
		while(<MAKE>) {
			print &html_escape($_);
			}
		close(MAKE);
		print "</pre>\n";
		if ($?) {
			# Failed! No point going on ..
			unlink($iso);
			print "<b>$text{'burn_mfailed'}</b><br>\n";
			&ui_print_footer("", $text{'index_return'});
			exit;
			}
		$msg = $in{'test'} ? $text{'burn_rutest2'}
				   : $text{'burn_rusure2'};

		# Check the size of the resulting ISO
		local @st = stat($iso);
		local $mb = int($st[7]/(1024*1024));
		if ($mb > 700) {
			print "<b>",&text('burn_700', $mb),"</b><br>\n";
			}
		elsif ($mb > 650) {
			print "<b>",&text('burn_650', $mb),"</b><br>\n";
			}
		else {
			print &text('burn_size', $mb, 650),"<br>\n";
			}
		}
	elsif ($profile->{'type'} == 3) {
		# To convert MP3s into data suitable for CDs, run
		# mpg123 -s -r 44100 file.mp3 >file.raw
		#
		# To burn to a CD, run
		# cdrecord dev=0,0,0 -v -audio -swab -pad speed=8 *.raw
		$temp = 1;
		$audio = $config{'temp'} ? "$config{'temp'}/burner.audio"
					 : &tempname("burner.audio");
		system("rm -rf $audio >/dev/null 2>&1");
		mkdir($audio, 0755);
		local (@srcs, $src);
		for($i=0; defined($src = $profile->{"source_$i"}); $i++) {
			if (-d $src) {
				opendir(DIR, $src);
				foreach $m (sort { $a cmp $b } readdir(DIR)) {
					push(@srcs, "$src/$m")
					    if ($m !~ /^\./ && -r "$src/$m");
					}
				closedir(DIR);
				}
			else {
				push(@srcs, $src);
				}
			}
		if (!@srcs) {
			# No files to burn
			print "<b>$text{'burn_nomp3s'}</b><br>\n";
			&ui_print_footer("", $text{'index_return'});
			exit;
			}

		local $mp3_basecmd = "$config{'mpg123'} -s -r 44100";
		local $wav_basecmd = "$config{'sox'} -V";
		print "<b>",&text('burn_mp3header', "<tt>$basecmd</tt>"),
		      "</b><br>\n";
		print "<pre>";
		local $size;
		local $errors;
		for($i=0; $i<@srcs; $i++) {
			print "<b>$srcs[$i]</b><br>\n";
			local $dst = sprintf "%s/track-%3.3d.raw", $audio, $i;
			local $q = quotemeta($srcs[$i]);
			if ($srcs[$i] =~ /\.(mp3|mp2|mpg|mpeg)$/i) {
				# Convert from MP3
				open(MPG, "$mp3_basecmd $q 2>&1 >$dst |");
				while(<MPG>) {
					next if (/^High Performance/i ||
						 /^Version\s+(\S+)/i ||
						 /^Uses code from various people/i ||
						 /^THIS SOFTWARE COMES WITH/i ||
						 /^Directory: /i ||
						 !/\S/);
					print &html_escape($_);
					}
				close(MPG);
				}
			elsif ($srcs[$i] =~ /\.(wav|ogg)$/i) {
				# Convert from WAV or OGG
				open(SOX, "$wav_basecmd $q -r 44100 $dst 2>&1 |");
				while(<SOX>) {
					print &html_escape($_);
					}
				close(SOX);
				}
			if ($?) {
				$errors++;
				}
			else {
				local @st = stat($dst);
				$size += $st[7];
				}
			print "<p>\n";
			}
		print "</pre>";
		if (!$size) {
			# Totally failed! No point going on ..
			system("rm -rf ".quotemeta($audio)." >/dev/null 2>&1");
			print "<b>$text{'burn_mp3failed'}</b><br>\n";
			&ui_print_footer("", $text{'index_return'});
			exit;
			}
		elsif ($errors) {
			# Some errors occurred
			print "<b>$text{'burn_mp3failed2'}</b><p>\n";
			}
		$msg = $in{'test'} ? $text{'burn_rutest3'}
				   : $text{'burn_rusure3'};

		# Check the total size
		local $mb = int($size/(1024*1024));
		if ($mb > 746) {
			print "<b>",&text('burn_746', $mb),"</b><br>\n";
			}
		elsif ($mb > 807) {
			print "<b>",&text('burn_807', $mb),"</b><br>\n";
			}
		else {
			print &text('burn_mp3size', $mb, 746),"<br>\n";
			}
		}
	elsif ($profile->{'type'} == 4) {
		# No preparation to do for a copy
		$iso = $profile->{'sdev'};
		$temp = 0;
		$msg = &text('burn_rusure4', $profile->{'sdesc'});
		}

	if ($in{'ask'}) {
		# Show confirm page
		print "<center><form action=burn.cgi>\n";
		print "<input type=hidden name=iso value='$iso'>\n";
		print "<input type=hidden name=audio value='$audio'>\n";
		print "<input type=hidden name=temp value='$temp'>\n";
		print "<input type=hidden name=id value='$profile->{'id'}'>\n";
		printf "<input type=hidden name=test value='%d'>\n",
			$in{'test'} ? 1 : 0;
		print "<b>$msg</b><p>\n";
		print "<input type=submit name=ok value='$text{'burn_ok'}'>\n";
		if ($temp) {
			print "<input type=submit name=cancel value='$text{'burn_cancel'}'>\n";
			}
		if (!$in{'test'}) {
			print "<br>$text{'burn_eject'}\n";
			print "<input type=radio name=eject value=1> $text{'yes'}\n";
			print "<input type=radio name=eject value=0 checked> $text{'no'}\n";
			}
		if ($profile->{'type'} != 4 ||
		    $profile->{'sdev'} ne $config{'dev'}) {
			printf "<br>$text{'burn_bg'}\n";
			print "<input type=radio name=bg value=1> $text{'yes'}\n";
			print "<input type=radio name=bg value=0 checked> $text{'no'}\n";
			}

		if ($profile->{'type'} != 4) {
			print "<br>$text{'burn_blank'} <select name=blank>\n";
			print "<option value='' selected>$text{'no'}</option>\n";
			print "<option value=fast>$text{'burn_bfast'}</option>\n";
			print "<option value=all>$text{'burn_ball'}</option>\n";
			print "</select>\n";
			}
		print "</form></center>\n";
		}
	else {
		# Redirect to the burn page
		print "<script>document.location = \"burn.cgi?iso=$iso&audio=$audio&temp=$temp&id=$profile->{'id'}&test=",$in{'test'} ? 1 : 0,"\";</script>\n";
		}

	&ui_print_footer("", $text{'index_return'});
	}
else {
	&redirect("");
	}

