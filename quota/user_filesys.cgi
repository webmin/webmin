#!/usr/local/bin/perl
# user_filesys.cgi
# List all filesystems for which some user has quotas

require './quota-lib.pl';
&ReadParse();
$u = $in{'user'};
&can_edit_user($u) ||
	&error(&text('ufilesys_ecannot', $u));
&ui_print_header(undef, $text{'ufilesys_title'}, "", "user_filesys");

foreach $f (&list_filesystems()) {
	if ($f->[4]%2 && $f->[5] && &can_edit_filesys($f->[0])) {
		push(@fslist, $f->[0]);
		$fslist{$f->[0]}++;
		}
	}

# Make sure all block sizes are the same
$n = &user_filesystems($u);
for($i=0; $i<$n; $i++) {
	$bsize = &block_size($filesys{$i,'filesys'});
	if ($last_bsize && $last_bsize != $bsize) {
		$variable_bsize++;
		}
	}

if ($n) {
	print &ui_subheading(&text('ufilesys_all', &html_escape($u)));

	# Generate top header (showing blocks/files)
	@hcols = ( undef, $variable_bsize ? $text{'ufilesys_blocks'}
					  : $text{'ufilesys_space'},
		   $text{'ufilesys_files'});
	print &ui_columns_start(\@hcols, 100, 0,
		[ undef, "colspan=3 align=center", "colspan=3 align=center" ]);

	# Generate second header
	@hcols = ( $text{'ufilesys_fs'}, $text{'ufilesys_used'},
		   $text{'ufilesys_soft'}, $text{'ufilesys_hard'},
		   $config{'show_grace'} ? ( $text{'ufilesys_grace'} ) : ( ),
		   $text{'ufilesys_used'},
		   $text{'ufilesys_soft'}, $text{'ufilesys_hard'},
		   $config{'show_grace'} ? ( $text{'ufilesys_grace'} ) : ( ),
		 );
	print &ui_columns_header(\@hcols);

	# Generate one row per filesystem the user has quota on
	for($i=0; $i<$n; $i++) {
		$f = $filesys{$i,'filesys'};
		$bsize = &block_size($f);
		local @cols;
		if ($fslist{$f} && !$access{'ro'}) {
			push(@cols, "<a href=\"edit_user_quota.cgi?filesys=$f&user=$u&source=1\">$f</a>");
			}
		else {
			push(@cols, $f);
			}
		if ($bsize) {
			push(@cols, &nice_size($filesys{$i,'ublocks'}*$bsize));
			}
		else {
			push(@cols, $filesys{$i,'ublocks'});
			}
		push(@cols, &nice_limit($filesys{$i,'sblocks'}, $bsize));
		push(@cols, &nice_limit($filesys{$i,'hblocks'}, $bsize));
		push(@cols, $filesys{$i,'gblocks'}) if ($config{'show_grace'});
		push(@cols, $filesys{$i,'ufiles'});
		push(@cols, &nice_limit($filesys{$i,'sfiles'}, $bsize, 1));
		push(@cols, &nice_limit($filesys{$i,'hfiles'}, $bsize, 1));
		push(@cols, $filesys{$i,'gfiles'}) if ($config{'show_grace'});
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
else {
	print "<b>",&text('ufilesys_nouquota', $u),"</b><p>\n";
	}

if (!$access{'ro'}) {
	print "<table width=100%><tr>\n";
	print "<form action=edit_user_quota.cgi>\n";
	print "<input type=hidden name=user value=\"$u\">\n";
	print "<input type=hidden name=source value=1>\n";
	print "<td align=left><input type=submit value=\"$text{'ufilesys_edit'}\">\n";
	print "<select name=filesys>\n";
	foreach $f (@fslist) { print "<option>$f\n"; }
	print "</select></td></form>\n";

	if ($access{'filesys'} eq "*") {
		print "<form action=copy_user_form.cgi>\n";
		print "<input type=hidden name=user value=\"$u\">\n";
		print "<td align=right><input type=submit value=\"$text{'ufilesys_copy'}\">\n";
		print "</td></form>\n";
		}
	print "</tr></table>\n";
	}

&ui_print_footer("", $text{'ufilesys_return'});


