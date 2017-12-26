#!/usr/local/bin/perl
# upload.cgi
# Upload multiple files

require './updown-lib.pl';
&error_setup($text{'upload_err'});
&ReadParse(\%getin, "GET");
$upid = $getin{'id'};
&ReadParseMime($upload_max, \&read_parse_mime_callback, [ $upid ], 1);
foreach my $k (keys %in) {
        $in{$k} = $in{$k}->[0] if ($k !~ /^upload\d+/);
        }
$can_upload || &error($text{'upload_ecannot'});

# Validate inputs
$in{'dir'} || &error($text{'upload_edir'});
if (defined($in{'email_def'}) && !$in{'email_def'}) {
	$in{'email'} =~ /\S/ || &error($text{'upload_eemail'});
	$email = $in{'email'};
	}
if ($can_mode != 3) {
	# User can be entered
	scalar(@uinfo = getpwnam($in{'user'})) ||
		&error($text{'upload_euser'});
	&can_as_user($in{'user'}) ||
		&error(&text('upload_eucannot', $in{'user'}));
	$in{'group_def'} || scalar(@ginfo = getgrnam($in{'group'})) ||
		&error($text{'upload_egroup'});
	$can_mode == 0 || $in{'group_def'} || &in_group(\@uinfo, \@ginfo) ||
		&error($text{'upload_egcannot'});
	}
else {
	# User is fixed
	if (&supports_users()) {
		@uinfo = getpwnam($remote_user);
		}
	}
for($i=0; defined($in{"upload$i"}); $i++) {
	for(my $j=0; $j<@{$in{"upload$i"}}; $j++) {
		$d = $in{"upload${i}"}->[$j];
		$f = $in{"upload${i}_filename"}->[$j];
		$found++ if ($d && $f);
		}
	}
$found || &error($text{'upload_enone'});
&can_write_file($in{'dir'}) ||
	&error(&text('upload_eaccess', "<tt>$in{'dir'}</tt>", $!));

# Switch to the upload user
&switch_uid_to($uinfo[2], scalar(@ginfo) ? $ginfo[2] : $uinfo[3]);

# Create the directory if needed
if (!-d $in{'dir'} && $in{'mkdir'}) {
	mkdir($in{'dir'}, 0755) || &error(&text('upload_emkdir', $!));
	}

&ui_print_header(undef, $text{'upload_title'}, "");

# Save the actual files, showing progress
$msg = undef;
for($i=0; defined($in{"upload$i"}); $i++) {
	for(my $j=0; $j<@{$in{"upload$i"}}; $j++) {
		$d = $in{"upload${i}"}->[$j];
		$f = $in{"upload${i}_filename"}->[$j];
		next if (!$f);
		if (-d $in{'dir'}) {
			$f =~ /([^\\\/]+)$/;
			$path = "$in{'dir'}/$1";
			}
		else {
			$path = $in{'dir'};
			}
		print &text('upload_saving',
			    "<tt>".&html_escape($path)."</tt>"),"<br>\n";
		if (!&open_tempfile(FILE, ">$path", 1)) {
			&error(&text('upload_eopen', "<tt>$path</tt>", $!));
			}
		&print_tempfile(FILE, $d);
		&close_tempfile(FILE);
		push(@uploads, $path);
		@st = stat($path);
		print &text('upload_saved', &nice_size($st[7])),"<p>\n";

		$estatus = undef;
		if ($in{'zip'}) {
			print &text('upload_unzipping',
				    "<tt>$path</tt>"),"<br>\n";
			local ($err, $out);
			$path =~ /^(\S*\/)/;
			local $dir = $1;
			local $qdir = quotemeta($dir);
			local $qpath = quotemeta($path);
			local @files;
			&switch_uid_back();
			if ($path =~ /\.zip$/i) {
				# ZIP file
				if (!&has_command("unzip")) {
					$err = &text('upload_ecmd', "unzip");
					}
				else {
					open(OUT, &webmin_command_as_user($uinfo[0], 0, "(cd $qdir && unzip -o $qpath)")." 2>&1 </dev/null |");
					while(<OUT>) {
						$out .= $_;
						if (/^\s*[a-z]+:\s+(.*)/) {
							push(@files, $1);
							}
						}
					close(OUT);
					$err = $out if ($?);
					}
				$fmt = "zip";
				}
			elsif ($path =~ /\.tar$/i) {
				# Un-compressed tar file
				if (!&has_command("tar")) {
					$err = &text('upload_ecmd', "tar");
					}
				else {
					open(OUT, &webmin_command_as_user($uinfo[0], 0, "(cd $qdir && tar xvf $qpath)")." 2>&1 </dev/null |");
					while(<OUT>) {
						$out .= $_;
						if (/^(.*)/) {
							push(@files, $1);
							}
						}
					close(OUT);
					$err = $out if ($?);
					}
				$fmt = "tar";
				}
			elsif ($path =~ /\.(lha|lhz)$/i) {
				# LHAarc file
				if (!&has_command("lha")) {
					$err = &text('upload_ecmd', "lha");
					}
				else {
					open(OUT, &webmin_command_as_user($uinfo[0], 0, "(cd $qdir && lha xf $qpath)")." 2>&1 </dev/null |");
					while(<OUT>) {
						$out .= $_;
						if (/(\S[^\t]*\S)\s+\-\s+/) {
							push(@files, "/".$1);
							}
						}
					close(OUT);
					$err = $out if ($?);
					}
				$fmt = "lha";
				}
			elsif ($path =~ /\.(tar\.gz|tgz|tar\.bz|tbz|tar\.bz2|tbz2)$/i) {
				# Compressed tar file
				local $zipper = $path =~ /bz(2?)$/i ? "bunzip2"
								    : "gunzip";
				if (!&has_command("tar")) {
					$err = &text('upload_ecmd', "tar");
					}
				elsif (!&has_command($zipper)) {
					$err = &text('upload_ecmd', $zipper);
					}
				else {
					open(OUT, &webmin_command_as_user($uinfo[0], 0, "(cd $qdir && $zipper -c $qpath | tar xvf -)")." 2>&1 </dev/null |");
					while(<OUT>) {
						$out .= $_;
						if (/^(.*)/) {
							push(@files, $1);
							}
						}
					close(OUT);
					$err = $out if ($?);
					}
				$fmt = $zipper eq "gunzip" ? "tgz" : "tbz2";
				}
			else {
				# Doesn't look possible
				$err = $text{'upload_notcomp'};
				}
			&switch_uid_to($uinfo[2],
				       scalar(@ginfo) ? $ginfo[2] : $uinfo[3]);
			if (!$err) {
				my $jn = join("<br>",
					      map { "&nbsp;&nbsp;<tt>$_</tt>" }
						  @files);
				if ($in{'zip'} == 2) {
					unlink($path);
					$ext{$path} = $text{'upload_deleted'}.
						      "<br>".$jn;
					}
				else {
					$ext{$path} = $text{'upload_extracted'}.
						      "<br>".$jn;
					}
				}
			else {
				$ext{$path} = &text('email_eextract', $err);
				}
			$estatus = $err ? &text('email_extfailed', $err)
					: &text('email_extdone_'.$fmt);
			print &text('upload_unzipdone', $estatus),"<p>\n";
			}

		# Add to email message
		$msg .= &text('email_upfile', $f)."\n";
		$msg .= &text('email_uppath', $path)."\n";
		$msg .= &text('email_upsize', &nice_size($st[7]))."\n";
		if ($estatus) {
			$msg .= &text('email_upextract', $estatus)."\n";
			}
		$msg .= "\n";
		}
	}

# Switch back to root
&switch_uid_back();

# Save the settings
if ($module_info{'usermin'}) {
	&lock_file("$user_module_config_directory/config");
	$userconfig{'dir'} = $in{'dir'};
	&write_file("$user_module_config_directory/config", \%userconfig);
	&unlock_file("$user_module_config_directory/config");
	}
else {
	&lock_file("$module_config_directory/config");
	$config{'dir_'.$remote_user} = $in{'dir'};
	$config{'user_'.$remote_user} = $in{'user'};
	$config{'group_'.$remote_user} = $in{'group_def'} ? undef
							   : $in{'group'};
	&write_file("$module_config_directory/config", \%config);
	&unlock_file("$module_config_directory/config");
	}

# Send email
if ($email && $msg) {
	$msg = $text{'email_upmsg'}."\n\n".$msg;
	&send_email_notification($email, $text{'email_subjectu'}, $msg);
	}

&webmin_log("upload", undef, undef, { 'uploads' => \@uploads });

&ui_print_footer("index.cgi?mode=upload", $text{'index_return'});

