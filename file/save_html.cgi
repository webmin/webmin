#!/usr/local/bin/perl
# Write data from an HTML editor

require './file-lib.pl';
$disallowed_buttons{'edit'} && &error($text{'ebutton'});
&ReadParseMime();
&error_setup($text{'html_err'});

# Get the original file contents, in case we need to preserve the head
$p = $in{'file'};
&switch_acl_uid_and_chroot();
$olddata = &read_file_contents($p);
if ($olddata) {
	($oldhead, $oldbody, $oldfoot) = &html_extract_head_body($olddata);
	}

# Try to write the file
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
	# Fix up HTML head, and write it out
	$in{'body'} =~ s/\r//g;
	$in{'body'} =~ s/^\s+//g;
	$in{'body'} =~ s/\s+$//g;
	if ($oldhead && $in{'body'} !~ /<body[\000-\377]*>/i) {
		&print_tempfile(FILE, $oldhead.$in{'body'}.$oldfoot);
		}
	else {
		&print_tempfile(FILE, $in{'body'});
		}
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
