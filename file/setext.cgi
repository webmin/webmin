#!/usr/local/bin/perl
# setext.cgi
# Sets the EXT attributes for some file

require './file-lib.pl';
$disallowed_buttons{'ext'} && &error($text{'ebutton'});
&ReadParse();
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
if ($access{'ro'} || !&can_access($in{'file'})) {
	print $text{'facl_eaccess'},"\n";
	}
else {
	$cmd = "chattr '=$in{'attrs'}' '$in{'file'}'";
	$out = `$cmd 2>&1`;
	if ($?) {
		print $out,"\n";
		}
	else {
		print "\n";
		}
	}

