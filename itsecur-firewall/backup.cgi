#!/usr/bin/perl
# Actually do a backup

require './itsecur-lib.pl';
&can_edit_error("backup");
&error_setup($text{'backup_err'});
&ReadParse();

# Validate inputs
if ($in{'dest_mode'} == 0) {
	$file = &tempname();
	}
elsif ($in{'dest_mode'} == 1) {
	$orig_dest = $in{'dest'};
	if (-d $in{'dest'}) {
		$in{'dest'} .= "/firewall.zip";
		}
	$in{'dest'} =~ /^(.*)\// || &error($text{'backup_edest'});
	-d $1 || &error($text{'backup_edestdir'});
	$file = $in{'dest'};
	$done = &text('backup_done1', $file);
	}
elsif ($in{'dest_mode'} == 2) {
	gethostbyname($in{'ftphost'}) || &error($text{'backup_eftphost'});
	$in{'ftpfile'} =~ /^\/\S+/ || &error($text{'backup_eftpfile'});
	$in{'ftpuser'} =~ /\S/ || &error($text{'backup_eftpuser'});
	$file = "ftp://$in{'ftpuser'}:$in{'ftppass'}\@$in{'ftphost'}$in{'ftpfile'}";
	$done = &text('backup_done2', $in{'ftphost'}, $in{'ftpfile'});
	}
elsif ($in{'dest_mode'} == 3) {
	$in{'email'} =~ /^\S+\@\S+$/ || &error($text{'backup_eemail'});
	$file = "mailto:$in{'email'}";
	$done = &text('backup_done3', $in{'email'});
	}
if (!$in{'pass_def'}) {
	$in{'pass'} || &error($text{'backup_epass'});
	}
@what = split(/\0/, $in{'what'});
@what || &error($text{'backup_ewhat'});

if (!$in{'save'}) {
	# Create the tar file
	$err = &backup_firewall(\@what, $file, $in{'pass_def'} ? undef
							       : $in{'pass'});
	&error($err) if ($err);
	}

# Save settings
$config{'backup_dest'} = $in{'dest_mode'} == 0 ? undef : $file;
$config{'backup_what'} = join(" ", @what);
$config{'backup_pass'} = $in{'pass_def'} ? undef : $in{'pass'};
&write_file($module_config_file, \%config);

if ($in{'save'}) {
	# Tell the user about the cron job
	&header($text{'backup_title'}, "",
		undef, undef, undef, undef, &apply_button());
	print "<hr>\n";

	print "<p>",&text('backup_donesched'),"<p>\n";

	print "<hr>\n";
	&footer("", $text{'index_return'});
	}
elsif ($in{'dest_mode'} == 0) {
	# Send to browser
	print "Content-type: application/octet-stream\n\n";
	open(FILE, $file);
	while(<FILE>) {
		print;
		}
	close(FILE);
	unlink($file);
	&remote_webmin_log("backup");
	}
else {
	# Tell the user
	&header($text{'backup_title'}, "",
		undef, undef, undef, undef, &apply_button());
	print "<hr>\n";

	print "<p>$done<p>\n";

	print "<hr>\n";
	&footer("", $text{'index_return'});
	&remote_webmin_log("backup", undef, $in{'dest'});
	}

# Setup cron job
$job = &find_backup_job();
if ($job) {
	&cron::delete_cron_job($job);
	}
if (!$in{'sched_def'}) {
	$job = { 'special' => $in{'sched'},
		 'user' => 'root',
		 'command' => $cron_cmd,
		 'active' => 1 };
	&cron::create_wrapper($cron_cmd, $module_name, "backup.pl");
	&cron::create_cron_job($job);
	}

