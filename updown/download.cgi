#!/usr/local/bin/perl
# download.cgi
# Save a download or start it right now

require './updown-lib.pl';
use Time::Local;
&ReadParse();
&error_setup($text{'download_err'});

# Validate and store inputs
$i = 0;
@urls = split(/[\r\n]+/, $in{'urls'});
@urls || &error($text{'download_enone'});
foreach $u (@urls) {
	local ($proto, $host, $port, $page, $ssl);
	if ($u =~ /^http/) {
		($host, $port, $page, $ssl, $user, $pass) = &parse_http_url($u);
		$proto = $ssl ? "https" : "http";
		}
	elsif ($u =~ /^ftp:\/\/([^\/]+)(:21)?(\/.*)$/) {
		$proto = "ftp";
		$host = $1; $page = $3;
		}
	else {
		&error(&text('download_eurl', $u));
		}
	if ($host =~ /^([^:\@]+):([^:\@]+)\@(\S+)/) {
		$user = $1;
		$pass = $2;
		$host = $3;
		}
	$download{"url_$i"} = $u;
	$download{"proto_$i"} = $proto;
	$download{"host_$i"} = $host;
	$download{"user_$i"} = $user;
	$download{"pass_$i"} = $pass;
	$download{"port_$i"} = $port;
	$download{"page_$i"} = $page;
	$download{"ssl_$i"} = $ssl;
	$i++;
	}
$in{'dir'} || &error($text{'upload_edir'});
&can_write_file($in{'dir'}) ||
	&error(&text('download_eaccess', "<tt>$in{'dir'}</tt>", $!));
$download{'dir'} = $in{'dir'};
if ($can_mode != 3) {
	# User can be entered
	scalar(@uinfo = getpwnam($in{'user'})) || &error($text{'upload_euser'});
	&can_as_user($in{'user'}) ||
		&error(&text('download_eucannot', $in{'user'}));
	$download{'uid'} = $uinfo[2];
	$in{'group_def'} || scalar(@ginfo = getgrnam($in{'group'})) ||
		&error($text{'upload_egroup'});
	$can_mode == 0 || $in{'group_def'} || &in_group(\@uinfo, \@ginfo) ||
		&error($text{'download_egcannot'});
	$download{'gid'} = scalar(@ginfo) ? $ginfo[2] : $uinfo[3];
	}
else {
	# User is fixed
	if (&supports_users()) {
		@uinfo = getpwnam($remote_user);
		$download{'uid'} = $uinfo[2];
		$download{'gid'} = $uinfo[3];
		}
	}
if ($in{'bg'} && $can_schedule) {
	# Validate time
	$in{'hour'} =~ /^\d+$/ && $in{'min'} =~ /^\d+$/ &&
		$in{'day'} =~ /^\d+$/ && $in{'year'} =~ /^\d+$/ ||
			&error($text{'download_edate'});
	eval { $download{'time'} = timelocal(0, $in{'min'}, $in{'hour'},
			 $in{'day'}, $in{'month'}, $in{'year'}-1900) };
	$@ && &error($text{'download_edate2'});
	}
if (defined($in{'email_def'}) && !$in{'email_def'}) {
	# Validate email
	$in{'email'} =~ /\S/ || &error($text{'upload_eemail'});
	$download{'email'} = $in{'email'};
	}

# Create the directory if needed
if (!-d $download{'dir'} && $in{'mkdir'}) {
	&switch_uid_to($download{'uid'}, $download{'gid'});
	mkdir($download{'dir'}, 0755) || &error(&text('upload_emkdir', $!));
	&switch_uid_back();
	}

# Save the settings
if ($module_info{'usermin'}) {
	&lock_file("$user_module_config_directory/config");
	$userconfig{'ddir'} = $in{'dir'};
	&write_file("$user_module_config_directory/config", \%userconfig);
	&unlock_file("$user_module_config_directory/config");
	}
else {
	&lock_file("$module_config_directory/config");
	$config{'ddir_'.$remote_user} = $in{'dir'};
	$config{'duser_'.$remote_user} = $in{'user'};
	$config{'dgroup_'.$remote_user} = $in{'group_def'} ? undef
							   : $in{'group'};
	&write_file("$module_config_directory/config", \%config);
	&unlock_file("$module_config_directory/config");
	}

if ($in{'bg'} && $can_background) {
	# Create a script to be called by At
	&foreign_require("cron", "cron-lib.pl");
	&lock_file($atjob_cmd);
	&cron::create_wrapper($atjob_cmd, $module_name, "download.pl");
	&unlock_file($atjob_cmd);
	&save_download(\%download);

	if (!$can_schedule) {
		# Just run this script right now
		&execute_command("$atjob_cmd $download{'id'} &");
		}
	else {
		# Create an At job to do the download
		&foreign_require("at", "at-lib.pl");
			{
			local %ENV;
			delete($ENV{'FOREIGN_MODULE_NAME'});
			delete($ENV{'FOREIGN_ROOT_DIRECTORY'});
			&clean_environment();
			$ENV{'REMOTE_USER'} = $remote_user;	# For usermin
			$ENV{'BASE_REMOTE_USER'} = $base_remote_user;
			&at::create_atjob(
				$module_info{'usermin'} ? $remote_user : "root",
				$download{'time'},
				"$atjob_cmd $download{'id'}",
				"/");
			&reset_environment();
			}
		}

	&redirect("index.cgi?mode=download");
	}
else {
	# Download it now, and show the results
	&ui_print_unbuffered_header(undef, $text{'download_title'}, "");

	$error = &do_download(\%download, \&progress_callback, \@paths);
	@paths = grep { $_ } @paths;
	if (@paths) {
		print "<p>$text{'download_done'}<p>\n";
		foreach $p (@paths) {
			@st = stat($p);
			print "<tt>$p</tt> ($st[7] bytes)<br>\n";
			}
		}
	if ($error) {
		print "<p><b>",&text('download_failed', $error),"</b><p>\n";
		}

	&ui_print_footer("index.cgi?mode=download", $text{'index_return'});
	}
&webmin_log("download", undef, undef, { 'urls' => \@urls,
					'time' => $download{'time'} });

