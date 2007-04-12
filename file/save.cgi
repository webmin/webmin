#!/usr/local/bin/perl
# save.cgi
# Write data to a file

require './file-lib.pl';
$disallowed_buttons{'edit'} && &error($text{'ebutton'});
$p = $ENV{'PATH_INFO'};
&webmin_log("save", undef, $p) if ($access{'uid'});
&switch_acl_uid_and_chroot();
print "Content-type: text/plain\n\n";

# Read posted data
$clen = $ENV{'CONTENT_LENGTH'};
&read_fully(STDIN, \$buf, $clen) == $clen ||
	&error("Failed to read POST input : $!");

if (defined($in{'length'}) && length($buf) != $in{'length'}) {
	print &text('edit_elength'),"\n";
	}
else {
	&lock_file($p);
	if ($access{'ro'} || !&can_access($p)) {
		print &text('edit_eaccess', $p),"\n";
		}
	elsif (-l $p && !&must_follow($p)) {
		print &text('edit_efollow', $p),"\n";
		}
	elsif (!&open_tempfile(FILE, ">$p", 1)) {
		print "$!\n";
		}
	else {
		&print_tempfile(FILE, $buf);
		&close_tempfile(FILE);
		&unlock_file($p);
		print "\n";
		print &file_info_line($p),"\n";
		&webmin_log("save", undef, $p) if (!$access{'uid'});
		}
	}
