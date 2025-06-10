#!/usr/local/bin/perl
# save_misc.cgi
# Save inputs from conf_misc.cgi

require './samba-lib.pl';
&ReadParse();
&lock_file($config{'smb_conf'});
$global = &get_share("global");

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcm'}") unless $access{'conf_misc'};
 
&error_setup($text{'savemisc_fail'});
&setval("debug level", $in{debug_level}, "");

&setval("getwd cache", $in{getwd_cache}, "no");

if (!$in{lock_directory_def} && !(-d &parent_dir($in{lock_directory}))) {
	&error($text{'savemisc_lockdir'});
	}
&setval("lock directory", $in{lock_directory_def}?"":$in{lock_directory}, "");

if (!$in{log_file_def} && !(-d &parent_dir($in{log_file}))) {
	&error($text{'savemisc_logdir'});
	}
&setval("log file", $in{log_file_def} ? "" : $in{log_file}, "");

if (!$in{max_log_size_def} && $in{max_log_size} !~ /^\d+$/) {
	&error(&text('savemisc_logsize',$in{max_log_size}));
	}
&setval("max log size", $in{max_log_size_def} ? 0 : $in{max_log_size}, 0);

&setval("read raw", $in{read_raw}, "yes");

&setval("write raw", $in{write_raw}, "yes");

if (!$in{read_size_def} && $in{read_size} !~ /^\d+$/) {
	&error(&text('savemisc_overlap',$in{read_size}));
	}
&setval("read size", $in{read_size_def} ? 0 : $in{read_size}, 0);

if (!$in{root_directory_def} && !(-d $in{root_directory})) {
	&error(&text('savemisc_chroot', $in{root_directory}));
	}
&setval("root directory", $in{root_directory_def}?"":$in{root_directory}, "");

if (!$in{smbrun_def} && !(-x $in{smbrun})) {
	&error(&text('savemisc_smbrun', $in{smbrun}));
	}
&setval("smbrun", $in{smbrun_def} ? "" : $in{smbrun}, "");

if (!$in{time_offset_def} && $in{time_offset} !~ /^\d+$/) {
	&error(&text('savemisc_time',$in{time_offset}));
	}
&setval("time offset", $in{time_offset_def} ? 0 : $in{time_offset}, 0);

&setval("read prediction", $in{read_prediction}, "no");

if ($global) { &modify_share("global", "global"); }
else { &create_share("global"); }
&unlock_file($config{'smb_conf'});
&webmin_log("misc", undef, undef, \%in);
&redirect("");

sub parent_dir
{
$_[0] =~ /^(.*\/)[^\/]+$/; return $1;
}
