#!/usr/local/bin/perl
# Write data from an HTML editor

require './file-lib.pl';
$disallowed_buttons{'edit'} && &error($text{'ebutton'});
&ReadParseMime();
&error_setup($text{'html_err'});

# Try to write the file
$p = $in{'file'};
&switch_acl_uid_and_chroot();
if ($access{'ro'} || !&can_access($p)) {
	&popup_error(&text('edit_eaccess', $p));
	}
elsif (-l $p && !&must_follow($p)) {
	&popup_error(&text('edit_efollow', $p));
	}
elsif (!&open_tempfile(FILE, ">$p", 1)) {
	&popup_error("$!");
	}
else {
	&print_tempfile(FILE, $in{'body'});
	&close_tempfile(FILE);

	# Show JS to close page
	&popup_header($text{'html_title'});

	$info = &file_info_line($p);
	print "<script>\n";
	print "opener.document.FileManager.",
	      "upload_notify(\"$p\", \"$info\");\n";
	print "close();\n";
	print "</script>\n";

	&popup_footer();
	}
