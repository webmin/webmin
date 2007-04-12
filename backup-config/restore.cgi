#!/usr/local/bin/perl
# Do an immediate restore

require './backup-config-lib.pl';
&ReadParseMime();

# Validate inputs
&error_setup($text{'restore_err'});
$src = &parse_backup_destination("src", \%in);
@mods = split(/\0/, $in{'mods'});
@mods || &error($text{'restore_emods'});

# Do it ..
($mode, $user, $pass, $server, $path) = &parse_backup_url($src);
if ($mode == 3) {
	# Create temp file for uploaded file
	$temp = &transname();
	open(TEMP, ">$temp");
	print TEMP $in{$path};
	close(TEMP);
	$src = $temp;
	}
&ui_print_header(undef, $text{'restore_title'}, "");
print &text('restore_doing', &nice_dest($src)),"<p>\n";
$err = &execute_restore(\@mods, $src, \@files, $in{'apply'});
&unlink_file($temp) if ($mode == 3);
if ($err) {
	print &text('restore_failed', $err),"<p>\n";
	}
else {
	print &text('restore_done', scalar(@files)),"<p>\n";
	}
$config{'apply'} = $in{'apply'};
&lock_file($module_config_file);
&save_module_config();
&unlock_file($module_config_file);
&webmin_log("restore", undef, $src, { 'mods' => \@mods });
&ui_print_footer("", $text{'index_return2'});

