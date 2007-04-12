#!/usr/local/bin/perl
# mkdir.cgi
# Create a directory

require './file-lib.pl';
$disallowed_buttons{'mkdir'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("mkdir", undef, $in{'dir'}, \%in);
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
&lock_file($in{'dir'});
if ($access{'ro'} || !&can_access($in{'dir'})) {
	print &text('mkdir_eaccess', $in{'dir'}),"\n";
	}
elsif (!mkdir($in{'dir'}, 0777)) {
	print "$!\n";
	}
else {
	print "\n";
	print &file_info_line($in{'dir'}),"\n";
	&unlock_file($in{'dir'});
	}


