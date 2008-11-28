#!/usr/local/bin/perl
# Show the contents of a zip, tar, tar.gz or tar.bz file on the server

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
$realfile = &unmake_chroot($in{'file'});
&switch_acl_uid();
($err, @lines) = &extract_archive($realfile, 0, 1);
print $err,"\n";
foreach my $l (@lines) {
	print $l,"\n";
	}

