#!/usr/local/bin/perl
# upload2.cgi
# Rename a file that has already been uploaded

require './file-lib.pl';
$disallowed_buttons{'upload'} && &error($text{'ebutton'});
&header();
&ReadParse();

if ($in{'yes'}) {
	# Put it in place, overwriting any other file
	&webmin_log("upload", undef, $in{'path'});
	&switch_acl_uid($running_as_root ? $in{'user'} : undef);
	if ($access{'ro'} || !&can_access($in{'path'})) {
		print "<p><b>",&text('upload_eperm', $in{'path'}),"</b><p>\n";
		}
	elsif (!&open_tempfile(FILE, ">".&unmake_chroot($in{'path'}), 1)) {
		print "<p><b>",&text('upload_ewrite', $in{'path'}, $!),"</b><p>\n";
		}
	else {
		open(TEMP, $in{'temp'});
		&copydata(TEMP, FILE) ||
			&error(&text('upload_ewrite', $in{'path'}, $!));
		close(TEMP);
		&close_tempfile(FILE);
		&post_upload($in{'path'}, $in{'dir'}, $in{'zip'});
		}
	unlink($in{'temp'});
	}
else {
	# Just delete the temp file
	&switch_acl_uid();
	unlink($in{'temp'});
	print "<script>\n";
	print "close();\n";
	print "</script>\n";
	}

