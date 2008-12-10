#!/usr/local/bin/perl
# edit_group_quota.cgi
# Display a form for editing the quotas for a group on some filesystem

require './quota-lib.pl';
&ReadParse();
$u = $in{'group'}; $fs = $in{'filesys'};
&can_edit_group($u) ||
	&error(&text('egroup_eallowgr', $u));
$access{'ro'} && &error(&text('egroup_eallowgr', $u));
&can_edit_filesys($fs) ||
	&error($text{'egroup_eallowfs'});
&ui_print_header(undef, $text{'egroup_title'}, "", "edit_group_quota");

@quot = &group_quota($u, $fs);
$first = (@quot == 0);
$bsize = &block_size($fs);
$fsbsize = &block_size($fs, 1);

print &ui_form_start("save_group_quota.cgi");
print &ui_hidden("group", $u);
print &ui_hidden("filesys", $fs);
print &ui_hidden("source", $in{'source'});
print &ui_table_start(&text('egroup_quotas', &html_escape($u), $fs),
		      "width=100%", 4);

# Soft block limit
print &ui_table_row($bsize ? $text{'egroup_sklimit'} : $text{'egroup_sblimit'},
	&quota_input("sblocks", $quot[1], $bsize));

# Hard block limit
print &ui_table_row($bsize ? $text{'egroup_hklimit'} : $text{'egroup_hblimit'},
	&quota_input("hblocks", $quot[2], $bsize));

# Space used
if (!$first) {
	if ($bsize) {
		print &ui_table_row($text{'egroup_kused'},
				    &nice_size($quot[0]*$bsize));
		}
	else {
		print &ui_table_row($text{'egroup_bused'},
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

# Soft file limit
print &ui_table_row($text{'egroup_sflimit'},
	&quota_input("sfiles", $quot[4]));

# Hard file limit
print &ui_table_row($text{'egroup_hflimit'},
	&quota_input("hfiles", $quot[5]));

# Files used
if (!$first) {
	print &ui_table_row($text{'egroup_fused'}, $quot[3]);
	}

# Filesystem files
if ($access{'diskspace'}) {
	print &ui_table_row($text{'euser_fdisk'}, $finfo);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'egroup_update'} ] ]);

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("group_filesys.cgi", $text{'egroup_listall'},
		      $text{'egroup_listalldesc'},
		      &ui_hidden("group", $u));
print &ui_buttons_end();

if ($in{'source'}) {
	&ui_print_footer("group_filesys.cgi?group=".&urlize($u),
			 $text{'egroup_freturn'});
	}
else {
	&ui_print_footer("list_groups.cgi?dir=".&urlize($fs),
			 $text{'egroup_greturn'});
	}


