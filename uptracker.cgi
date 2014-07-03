#!/usr/local/bin/perl
# Output Javascript in a loop to track an upload

BEGIN { push(@INC, ".."); };
use WebminCore;

&init_config();
&ReadParse();
$id = $in{'id'};
$id || &error($text{'uptracker_eid'});
$id =~ /^[a-z0-9_]+$/i || &error($text{'uptracker_eid2'});

&popup_header($text{'uptracker_title'}, undef,
	      "onunload='if (!window.doneupload) { opener.stop() }'");
$| = 1;

# Output text boxes that get updated with filenames and progress
$ff = "style='font-family: courier,monospace'";
print "<form>\n";
print "<center><table>\n";
print "<tr> <td><b>$text{'uptracker_file'}</b></td>\n";
print "<td>",&ui_textbox("file", undef, 50, 1, undef, $ff),"</td> </tr>\n";
print "<tr> <td><b>$text{'uptracker_size'}</b></td>\n";
print "<td>",&ui_textbox("size", undef, 50, 1, undef, $ff),"</td> </tr>\n";
print "<tr> <td><b>$text{'uptracker_pc'}</b></td>\n";
print "<td>",&ui_textbox("pc", undef, 50, 1, undef, $ff),"</td> </tr>\n";
print "</table></center>\n";
print "</form>\n";

# Find the location of the user's upload progess file
if ($in{'uid'}) {
	@uinfo = getpwuid($in{'uid'});
	$upfile = "$uinfo[7]/.tmp/upload.$id";
	}
else {
	$upfile = "$ENV{'WEBMIN_VAR'}/upload.$id";
	}

# Read the tracker file in a loop until done, or until 1 minute has passed
# with no progress
print "<script>\n";
print "window.doneupload = 1;\n";
print "</script>\n";
$start = time();
while(1) {
	sleep(1);
	$now = time();
	if (!open(UPFILE, $upfile)) {
		# Doesn't exist yet
		if ($now - $start > 60) {
			# Give up after 60 seconds
			print "<script>\n";
			print "document.forms[0].pc.value = \"Not started\";\n";
			print "</script>\n";
			last;
			}
		next;
		}
	@lines = <UPFILE>;
	chop(@lines);
	close(UPFILE);
	($size, $totalsize, $filename) = @lines;
	if ($size == -1) {
		# Come to the end OK .. set percent bar to 100
		print "<script>\n";
		print "document.forms[0].pc.value = \"".("X" x 50)."\";\n";
		print "window.doneupload = 1;\n";
		print "</script>\n";
		last;
		}

	# Check if there has been no activity for 60 seconds
	if ($size == $last_size) {
		if ($last_time && $last_time < $now-60) {
			# Too slow! Give up
			print "<script>\n";
			print "document.forms[0].pc.value = \"Timeout\";\n";
			print "</script>\n";
			last;
			}
		}
	else {
		$last_size = $size;
		$last_time = $now;
		}

	$pc = int(100 * $size / $totalsize) / 2;
	next if (defined($lastpc) && $pc == $lastpc);
	print "<script>\n";
	print "document.forms[0].file.value = \"".
		&quote_javascript($filename)."\";\n";
	print "document.forms[0].size.value = \"".
		&quote_javascript(&text('uptracker_of',
				&nice_size($size),
				&nice_size($totalsize)))."\";\n";
	print "document.forms[0].pc.value = \"".("|" x $pc)."\";\n";
	print "</script>\n";
	
	$lastpc = $pc;
	last if ($size >= $totalsize);
	}

# All done, so close the window and remove the file
print "<script>\n";
print "window.close();\n";
print "</script>\n";
unlink($upfile);

&popup_footer();

