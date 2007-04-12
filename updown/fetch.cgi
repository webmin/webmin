#!/usr/local/bin/perl
# Output one file for download

require './updown-lib.pl';
&ReadParse();
&error_setup($text{'fetch_err'});
$can_fetch || &error($text{'fetch_ecannot'});

# Validate filename
$file = $ENV{'PATH_INFO'} || $in{'fetch'};
if ($file !~ /^\// && $can_dirs[0] ne "/") {
	$file = "$can_dirs[0]/$file";
	}
$file || &error($text{'fetch_efile'});
-r $file && !-d $file || &error($text{'fetch_eexists'});
&can_write_file($file) ||
	&error(&text('fetch_eaccess', "<tt>$file</tt>", $!));

if ($ENV{'PATH_INFO'}) {
	# Switch to the correct user
	if ($can_mode == 3) {
		@uinfo = getpwnam($remote_user);
		&switch_uid_to($uinfo[2], $uinfo[3]);
		}
	elsif ($can_mode == 1 && @can_users == 1) {
		@uinfo = getpwnam($can_users[0]);
		&switch_uid_to($uinfo[2], $uinfo[3]);
		}

	# Send it
	&open_readfile(FILE, $file) || &error(&text('fetch_eopen', $!));
	if ($fetch_show) {
		$type = &guess_mime_type($file, undef);
		if (!$type) {
			# See if it is really text
			$out = &backquote_command("file ".quotemeta(&resolve_links($file)));
			$type = "text/plain" if ($out =~ /text|script/);
			}
		}
	else {
		print "Content-Disposition: Attachment\n";
		}
	$type ||= "application/octet-stream";
	print "Content-type: $type\n\n";
	while(<FILE>) {
		print $_;
		}
	close(FILE);

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
	&redirect("fetch.cgi".$file);
	}

