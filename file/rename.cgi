#!/usr/local/bin/perl
# rename.cgi
# Rename some file

require './file-lib.pl';
$disallowed_buttons{'rename'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("rename", undef, $in{'old'}, \%in);
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || !&can_access($in{'old'})) {
	print &text('rename_eold', $in{'old'}),"\n";
	}
elsif (!&can_access($in{'new'})) {
	print &text('rename_enew', $in{'new'}),"\n";
	}
elsif (!&rename_logged($in{'old'}, $in{'new'})) {
	print "$!\n";
	}
else {
	print "\n";
	}


