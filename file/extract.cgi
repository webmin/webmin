#!/usr/local/bin/perl
# Extract a zip, tar, tar.gz or tar.bz file on the server

require './file-lib.pl';
&ReadParse();
print "Content-type: text/plain\n\n";

# Check permissions
$disallowed_buttons{'upload'} && &error($text{'ebutton'});
if (!&can_access($in{'file'})) {
	print &text('extract_eperm', $in{'file'}),"\n";
	exit(0);
	}

# Go for it
&webmin_log("extract", undef, $in{'file'});
$realfile = &unmake_chroot($in{'file'});
&switch_acl_uid();
$err = &extract_archive($realfile, $in{'delete'});
print $err,"\n";

