#!/usr/local/bin/perl
# delete.cgi
# Delete some file or directory

require './file-lib.pl';
$disallowed_buttons{'delete'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("delete", undef, $in{'file'}, \%in);
print "Content-type: text/plain\n\n";
if ($access{'ro'} || !&can_access($in{'file'})) {
	print &text('delete_eaccess', $in{'file'}),"\n";
	exit;
	}
if (&indexof($in{'file'}, @allowed_roots) >= 0) {
	print &text('delete_eroot', $in{'file'}),"\n";
	exit;
	}
if (-r &unmake_chroot($in{'file'}) && !-d &unmake_chroot($in{'file'})) {
	&switch_acl_uid_and_chroot();
	$rv = unlink($in{'file'});
	if (!$rv) { print "$!\n"; }
	else { print "\n"; }
	}
else {
	&switch_acl_uid();
	($ok, $err) = &unlink_file(&unmake_chroot($in{'file'}));
	if (!$ok) { print "$err\n"; }
	else { print "\n"; }
	}

