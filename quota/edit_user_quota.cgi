#!/usr/local/bin/perl
# edit_user_quota.cgi
# Display a form for editing the quotas for a user on some filesystem

require './quota-lib.pl';
&ReadParse();
$u = $in{'user'}; $fs = $in{'filesys'};
&can_edit_user($u) ||
	&error(&text('euser_eallowus', $u));
$access{'ro'} && &error(&text('euser_eallowus', $u));
&can_edit_filesys($fs) ||
	&error($text{'euser_eallowfs'});
&ui_print_header(undef, $text{'euser_title'}, "", "edit_user_quota");

@quot = &user_quota($u, $fs);
$first = (@quot == 0);
$bsize = &block_size($fs);
$fsbsize = &block_size($fs, 1);

print &ui_form_start("save_user_quota.cgi");
print &ui_hidden("user", $u);
print &ui_hidden("filesys", $fs);
print &ui_hidden("source", $in{'source'});
print &ui_table_start(&text('euser_quotas', &html_escape($u), $fs),
		      "width=100%", 4);

# Soft block limit
print &ui_table_row($bsize ? $text{'euser_sklimit'} : $text{'euser_sblimit'},
	&quota_input("sblocks", $quot[1], $bsize));

# Hard block limit
print &ui_table_row($bsize ? $text{'euser_hklimit'} : $text{'euser_hblimit'},
	&quota_input("hblocks", $quot[2], $bsize));

# Space used
if (!$first) {
	if ($bsize) {
		print &ui_table_row($text{'euser_kused'},
				    &nice_size($quot[0]*$bsize));
		}
	else {
		print &ui_table_row($text{'euser_bused'},
				    $quot[0]);
		}
	}

if ($access{'diskspace'}) {
	# Filesystem space
	($binfo, $finfo) = &filesystem_info($fs, undef, undef, $fsbsize);
	print &ui_table_row($bsize ? $text{'euser_sdisk'}
				   : $text{'euser_bdisk'}, $binfo);
	}

print &ui_table_hr();

# Sort file limit
print &ui_table_row($text{'euser_sflimit'},
	&quota_input("sfiles", $quot[4]));

# Hard file limit
print &ui_table_row($text{'euser_hflimit'},
	&quota_input("hfiles", $quot[5]));

# Files used
if (!$first) {
	print &ui_table_row($text{'euser_fused'}, $quot[3]);
	}

if ($access{'diskspace'}) {
	# Number of files
	print &ui_table_row($text{'euser_fdisk'}, $finfo);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'euser_update'} ] ]);

print &ui_hr();

print &ui_buttons_start();
print &ui_buttons_row("user_filesys.cgi", $text{'euser_listall'},
		      $text{'euser_listalldesc'},
		      &ui_hidden("user", $u));
print &ui_buttons_end();

if ($in{'source'}) {
	&ui_print_footer("user_filesys.cgi?user=".&urlize($u),
			 $text{'euser_freturn'});
	}
else {
	&ui_print_footer("list_users.cgi?dir=".&urlize($fs),
			 $text{'euser_ureturn'});
	}


