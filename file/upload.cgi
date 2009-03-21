#!/usr/local/bin/perl
# upload.cgi
# Upload a file

require './file-lib.pl';
$disallowed_buttons{'upload'} && &error($text{'ebutton'});
&popup_header();
&ReadParse(\%getin, "GET");
$upid = $getin{'id'};
&ReadParseMime($upload_max, \&read_parse_mime_callback, [ $upid ]);

$realdir = &unmake_chroot($in{'dir'});
if (!$in{'file_filename'}) {
	print "<p><b>$text{'upload_efile'}</b><p>\n";
	}
elsif (!-d $realdir) {
	print "<p><b>$text{'upload_edir'}</b><p>\n";
	}
elsif ($running_as_root && !defined(getpwnam($in{'user'}))) {
	print "<p><b>$text{'upload_euser'}</b><p>\n";
	}
else {
	$in{'file_filename'} =~ /([^\\\/]+)$/;
	$path = "$in{'dir'}/$1";
	$realpath = "$realdir/$1";
	if (-e $realpath) {
		# File exists .. ask the user if he is sure
		&switch_acl_uid($running_as_root ? $in{'user'} : undef);
		$temp = &tempname();
		&open_tempfile(TEMP, ">$temp");
		if ($dostounix == 1 && $in{'dos'}) {
			$in{'file'} =~ s/\r\n/\n/g;
			}
		&print_tempfile(TEMP, $in{'file'});
		&close_tempfile(TEMP);
		print "<center>\n";
		print &ui_form_start("upload2.cgi");
		foreach $i (keys %prein) {
			print &ui_hidden($i, $prein{$i});
			}
		print &ui_hidden("dir", $in{'dir'});
		print &ui_hidden("path", $path);
		print &ui_hidden("temp", $temp);
		print &ui_hidden("zip", $in{'zip'});
		print &ui_hidden("user", $in{'user'});
		print &text('upload_already', "<tt>$path</tt>"),"<p>\n";
		print &ui_form_end([ [ "yes", $text{'yes'} ],
				     [ "no", $text{'no'} ] ]);
		print "</form>\n";
		print "</center>\n";
		}
	else {
		# Go ahread and do it!
		&webmin_log("upload", undef, $path);
		&switch_acl_uid($running_as_root ? $in{'user'} : undef);
		if ($access{'ro'} || !&can_access($path)) {
			print "<p><b>",&text('upload_eperm', $path),"</b><p>\n";
			}
		elsif (-l $path && !&must_follow($realpath)) {
			print "<p><b>",&text('upload_elink', $path),"</b><p>\n";
			}
		elsif (!&open_tempfile(FILE, ">$realpath", 1)) {
			print "<p><b>",&text('upload_ewrite', $path, $!),"</b><p>\n";
			}
		else {
			if ($dostounix == 1 && $in{'dos'}) {
				$in{'file'} =~ s/\r\n/\n/g;
				}
			&print_tempfile(FILE, $in{'file'});
			&close_tempfile(FILE);
			&post_upload($path, $in{'dir'}, $in{'zip'});
			}
		}
	}

&popup_footer();
