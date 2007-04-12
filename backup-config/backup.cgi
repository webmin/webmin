#!/usr/local/bin/perl
# Do an immediate backup

require './backup-config-lib.pl';
&ReadParse();

# Validate inputs
&error_setup($text{'backup_err'});
$dest = &parse_backup_destination("dest", \%in);
($configfile, $nofiles, $others) = &parse_backup_what("what", \%in);
@mods = split(/\0/, $in{'mods'});
@mods || ($nofiles && !$configfile) || &error($text{'backup_emods'});

# Go for it
($mode, $user, $pass, $server, $path) = &parse_backup_url($dest);
if ($mode != 4) {
	# Save somewhere, and tell the user
	&ui_print_header(undef, $text{'backup_title'}, "");
	print &text('backup_doing', &nice_dest($dest, 1)),"<p>\n";
	$err = &execute_backup(\@mods, $dest, \$size, \@files,
			       $configfile, $nofiles,
			       [ split(/\t+/, $others) ]);
	if ($err) {
		print &text('backup_failed', $err),"<p>\n";
		}
	else {
		print &text('backup_done', &nice_size($size),
			    scalar(@files)),"<p>\n";
		}
	&ui_print_footer("", $text{'index_return2'});
	}
else {
	# Output file in browser
	$temp = &transname();
	$err = &execute_backup(\@mods, $temp, \$size, undef,
			       $configfile, $nofiles);
	if ($err) {
		&unlink_file($temp);
		&error($err);
		}
	print "Content-type: application/octet-stream\n\n";
	open(TEMP, $temp);
	while(read(TEMP, $buf, 1024)) {
		print $buf;
		}
	close(TEMP);
	&unlink_file($temp);
	}

if (!$err) {
	# Save config
	$config{'dest'} = $dest;
	$config{'mods'} = join(" ", @mods);
	$config{'configfile'} = $in{'configfile'};
	$config{'nofiles'} = $in{'nofiles'};
	&lock_file($module_config_file);
	&save_module_config();
	&unlock_file($module_config_file);
	&webmin_log("backup", undef, $dest, { 'mods' => \@mods });
	}

