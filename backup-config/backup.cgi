#!/usr/local/bin/perl
# Do an immediate backup

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './backup-config-lib.pl';
our (%in, %text, %config, $module_config_file);
&ReadParse();

# Validate inputs
&error_setup($text{'backup_err'});
my $dest = &parse_backup_destination("dest", \%in);
my ($configfile, $nofiles, $others) = &parse_backup_what("what", \%in);
$others ||= "";
my @mods = split(/\0/, $in{'mods'});
@mods || ($nofiles && !$configfile) || &error($text{'backup_emods'});

# Go for it
my ($mode, $user, $pass, $server, $path, $port) = &parse_backup_url($dest);
my $err;
if ($mode != 4) {
	# Save somewhere, and tell the user
	&ui_print_header(undef, $text{'backup_title'}, "");
	print &text('backup_doing', &nice_dest($dest, 1)),"<p>\n";
	my $size;
	my @files;
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
	my $temp = &transname();
	my $size;
	$err = &execute_backup(\@mods, $temp, \$size, undef,
			       $configfile, $nofiles,
			       [ split(/\t+/, $others) ]);
	if ($err) {
		&unlink_file($temp);
		&error($err);
		}
	print "Content-type: application/x-gzip\n\n";
	my $buf;
	open(TEMP, "<$temp");
	my $bs = &get_buffer_size();
	while(read(TEMP, $buf, $bs)) {
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

