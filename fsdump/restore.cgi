#!/usr/local/bin/perl
# restore.cgi
# Restore a backup dump

require './fsdump-lib.pl';
&ReadParse();
&error_setup($text{'restore_err'});
$access{'restore'} || &error($text{'restore_ecannot'});
if ($access{'dirs'} ne '*') {
	# XFS can list a backup without opening a destination directory.
	if (length($in{'dir'}) || $in{'fs'} ne 'xfs' || !$in{'test'}) {
		&can_edit_dir($in{'dir'}) || &error($text{'restore_ecannot'});
		}
	if ($in{'mode'} == 0) {
		&can_use_dump_file($in{'file'}) ||
			&error($text{'restore_ecannot'});
		}
	}
$in{'extra'} && !$access{'extra'} && &error($text{'restore_ecannot'});
if ($in{'extra'}) {
	# Extra options cannot reach beyond this user's limits
	$err = &extra_args_error($in{'fs'}, 1, $in{'extra'});
	&error($err) if ($err);
	}

$cmd = &parse_restore($in{'fs'});

&ui_print_unbuffered_header(undef, $text{'restore_title'}, "");

&create_wrappers();

# The volume-change callback opens each numbered archive separately.
local $ENV{'FSDUMP_RESTORE_DIRS'} = $access{'dirs'};
print "<b>",&text('restore_now', "<tt>".&html_escape($cmd)."</tt>"),"</b> <p>\n";
print "<pre>";
$rv = &restore_backup($in{'fs'}, $cmd);
print "</pre>\n";
if ($rv) {
	if ($rv =~ /^\d+$/) {
		# Bad exit status
		print "<b>$text{'restore_failed2'}</b><p>\n";
		}
	else {
		# Some error message
		print "<b>",&text('restore_failed', $rv),"</b><p>\n";
		}
	}
elsif (!$in{'test'}) {
	print "<b>$text{'restore_complete'}</b><p>\n";
	}
&webmin_log("restore", undef, $in{'mode'} == 0 ? $in{'file'} :
		      $in{'huser'} ? "$in{'huser'}@$in{'host'}:$in{'hfile'}" :
				     "$in{'huser'}:$in{'hfile'}");

&ui_print_footer("", $text{'index_return'});

