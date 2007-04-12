#!/usr/local/bin/perl
# move.cgi
# Move some file or directory

require './file-lib.pl';
$disallowed_buttons{'copy'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("move", undef, $in{'from'}, \%in);
&switch_acl_uid();
print "Content-type: text/plain\n\n";
unlink($in{'to'}); # in case we are moving a directory
if ($access{'ro'} || !&can_access($in{'to'})) {
	print &text('move_eto', $in{'to'}),"\n";
	exit;
	}
if (!&can_access($in{'from'})) {
	print &text('move_efrom', $in{'from'}),"\n";
	exit;
	}
$ok = &rename_logged(&unmake_chroot($in{'from'}),
		     &unmake_chroot($in{'to'}));
if (!$ok) {
	print $!,"\n";
	}
else {
	print "\n";
	print &file_info_line(&unmake_chroot($in{'to'})),"\n";
	}

