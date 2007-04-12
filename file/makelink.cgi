#!/usr/local/bin/perl
# makelink.cgi
# Create a symbolic link

require './file-lib.pl';
$disallowed_buttons{'makelink'} && &error($text{'ebutton'});
&ReadParse();
&webmin_log("link", undef, $in{'from'}, \%in);
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";
&lock_file($in{'from'});
if ($access{'ro'} || !&can_access($in{'from'})) {
	print &text('link_efrom2', $in{'from'}),"\n";
	}
elsif ($follow) {
	print $text{'link_efollow'},"\n";
	}
elsif (!symlink($in{'to'}, $in{'from'})) {
	print "$!\n";
	}
else {
	print "\n";
	print &file_info_line($in{'from'}),"\n";
	&unlock_file($in{'from'});
	}

