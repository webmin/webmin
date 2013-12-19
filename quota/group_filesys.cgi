#!/usr/local/bin/perl
# group_filesys.cgi
# List all filesystems for which some group has quotas

require './quota-lib.pl';
&ReadParse();
$u = $in{'group'};
$u =~ /\S/ || &error($text{'gfilesys_enone'});
&can_edit_group($u) ||
	&error(&text('gfilesys_ecannot', $u));
&ui_print_header(undef, $text{'gfilesys_title'}, "", "group_filesys");

foreach $f (&list_filesystems()) {
	if ($f->[4] > 1 && $f->[5] && &can_edit_filesys($f->[0])) {
		push(@fslist, $f->[0]);
		$fslist{$f->[0]}++;
		}
	}

# Make sure all block sizes are the same
$n = &group_filesystems($u);
for($i=0; $i<$n; $i++) {
	$bsize = &block_size($filesys{$i,'filesys'});
	if ($last_bsize && $last_bsize != $bsize) {
		$variable_bsize++;
		}
	}

if ($n) {
	print &ui_subheading(&text('gfilesys_all', &html_escape($u)));

	# Generate top header (showing blocks/files)
	@hcols = ( undef, $variable_bsize ? $text{'ufilesys_blocks'}
					  : $text{'ufilesys_space'},
		   $config{'show_grace'} ? ( undef ) : ( ),
		   $text{'ufilesys_files'},
		   $config{'show_grace'} ? ( undef ) : ( ));
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
			push(@cols, &ui_link("edit_group_quota.cgi?filesys=$f&group=$u&source=1", $f) );
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
	print "<b>",&text('gfilesys_nogquota', $u),"</b><br>\n";
	}

if (!$access{'ro'}) {
	print &ui_hr();
	print &ui_buttons_start();

	# Form to edit quota on other filesystems
	print &ui_buttons_row("edit_group_quota.cgi",
		$text{'gfilesys_edit'},
		$text{'gfilesys_editdesc'},
		&ui_hidden("group", $u).&ui_hidden("source", 1),
		&ui_select("filesys", undef, \@fslist)
		);

	if ($access{'filesys'} eq "*") {
		# Button to copy quotas
		print &ui_buttons_row("copy_group_form.cgi",
			$text{'gfilesys_copy'},
			$text{'gfilesys_copydesc'},
			&ui_hidden("group", $u));
		}

	print &ui_buttons_end();
	}

&ui_print_footer("", $text{'gfilesys_return'});

