#!/usr/local/bin/perl
# Output one file for download

require './updown-lib.pl';
&ReadParse();
&error_setup($text{'fetch_err'});
$can_fetch || &error($text{'fetch_ecannot'});

# Validate filename
$file = $ENV{'PATH_INFO'} || $in{'fetch'};
if ($file !~ /^([a-z]:)?\// && $can_dirs[0] ne "/") {
	$file = "$can_dirs[0]/$file";
	}
$file || &error($text{'fetch_efile'});
if ($file =~ /^(.*)\.zip$/ && $in{'unzip'}) {
	# Remove .zip extension
	$file = $1;
	}
-r $file || -d $file || &error($text{'fetch_eexists2'});
&can_write_file($file) ||
	&error(&text('fetch_eaccess', "<tt>$file</tt>", $!));
if (-d $file && !&has_command("zip")) {
	&error($text{'fetch_ezip'});
	}
if ($file eq "/" || $file =~ /^[a-z]:\/$/) {
	&error($text{'fetch_eroot'});
	}

if ($ENV{'PATH_INFO'}) {
	# Switch to the correct user
	if ($can_mode == 3 && &supports_users()) {
		@uinfo = &get_remote_unix_user();
		&switch_uid_to($uinfo[2], $uinfo[3]);
		}
	elsif ($can_mode == 1 && @can_users == 1) {
		@uinfo = getpwnam($can_users[0]);
		&switch_uid_to($uinfo[2], $uinfo[3]);
		}

	if (-d $file) {
		# Zip up the whole directory
		($shortfile = $file) =~ s/^.*\///g;
		$shortfile =~ s/\s+//g;
		$temp = &transname($shortfile.".zip");
		$out = &backquote_command("cd ".quotemeta($file).
					  " && zip -r ".quotemeta($temp)." .");
		if ($?) {
			&error(&text('fetch_ezipcmd',
				     "<tt>".&html_escape($out)."</tt>"));
			}
		@st = stat($temp);
		print "Content-length: $st[7]\n";
		print "Content-type: application/zip\n\n";
		open(FILE, "<$temp");
		unlink($temp);
		while(read(FILE, $buffer, &get_buffer_size_binary())) {
			print("$buffer");
			}
		close(FILE);
		}
	else {
		# Work out the type
		&open_readfile(FILE, $file) ||
			&error(&text('fetch_eopen', $!));
		my $type = "application/octet-stream";
		my $show_inline = 0;
		if ($fetch_show) {
			# Only allow file types that are safe to render inside a
			# Webmin session. Everything else must be downloaded.
			my $guessed_type =
				&guess_mime_type($file, "application/octet-stream");
			if ($guessed_type =~ /^image\/(?:gif|png|jpe?g)$/i) {
				$type = $guessed_type;
				$show_inline = 1;
				}
			elsif ($guessed_type =~ /^text\//i &&
			       $guessed_type !~ /^text\/(?:html|xml)$/i) {
				$type = "text/plain";
				$show_inline = 1;
				}
			else {
				my $file_desc = &backquote_command("file ".
					quotemeta(&resolve_links($file)));
				if ($file_desc =~ /\btext\b/i &&
				    $file_desc !~ /\b(?:html|xml|svg|pdf)\b/i) {
					$type = "text/plain";
					$show_inline = 1;
					}
				}
			}
		if (!$show_inline) {
			print "Content-Disposition: Attachment\n";
			}

		# Send it
		my @st = stat($file);
		print "Content-length: $st[7]\n";
		print "X-Content-Type-Options: nosniff\n";
		print "Content-type: $type\n\n";
		while(read(FILE, $buffer, &get_buffer_size_binary())) {
			print("$buffer");
			}
		close(FILE);
		}

	# Switch back to root
	&switch_uid_back();
	}
else {
	# Save file in config
	if ($module_info{'usermin'}) {
		&lock_file("$user_module_config_directory/config");
		$userconfig{'fetch'} = $file;
		$userconfig{'show'} = $in{'show'};
		&write_file("$user_module_config_directory/config", \%userconfig);
		&unlock_file("$user_module_config_directory/config");
		}
	else {
		&lock_file("$module_config_directory/config");
		$config{'fetch_'.$remote_user} = $file;
		$config{'show_'.$remote_user} = $in{'show'};
		&write_file("$module_config_directory/config", \%config);
		&unlock_file("$module_config_directory/config");
		}

	# Redirect to nice URL
	$file =~ s/#/%23/g;
	if (-d $file) {
		&redirect("fetch.cgi".$file.".zip?unzip=1");
		}
	else {
		&redirect("fetch.cgi".$file);
		}
	}

