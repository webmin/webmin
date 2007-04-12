#!/usr/local/bin/perl
# list_groups.cgi
# Lists all the groups with quotas on some filesystem

require './quota-lib.pl';
&ReadParse();
$f = $in{'dir'};
$whatfailed = $text{'lgroups_failed'};
&can_edit_filesys($f) ||
	&error($text{'lgroups_eallow'});
$form = 0;

# List quotas
&ui_print_header(undef, $text{'lgroups_title'}, "", "list_groups");

$n = &filesystem_groups($f);
$bsize = &block_size($f);
$fsbsize = &block_size($f);
if ($n > $config{'display_max'} && !$access{'ro'}) {
	print "<b>",&text('lgroups_toomany', $f),"</b><br>\n";
	}
elsif ($n) {
	my $threshold_pc = $config{'threshold_pc'} || 101;
	$threshold_pc = 101 if $threshold_pc < 1 or $threshold_pc > 101;
	print &ui_subheading(&text('lgroups_quotas', $f));
	&show_buttons();
	if (!$access{'ro'}) {
		print &ui_form_start("edit_group_mass.cgi", "post");
		print &ui_hidden('dir', $f),"\n";
		}

	# Generate select links
	@links = ( &select_all_link("d", $form),
		   &select_invert_link("d", $form) );
	if (!$access{'ro'}) {
		print &ui_links_row(\@links);
		}

	# Generate first header (with blocks and files)
	local @hcols;
	local @tds;
	if (!$access{'ro'}) {
		push(@hcols, "");
		push(@tds, "width=5");
		}
	push(@hcols, "");
	push(@tds, "");
	($binfo, $finfo) = &filesystem_info($f, \%group, $n, $fsbsize);
	$cols1 = 3 + ($threshold_pc != 101 ? 1 : 0) +
		     ($config{'show_grace'} ? 1 : 0);
	$cols2 = 3 + ($config{'show_grace'} ? 1 : 0);
	push(@hcols, ($bsize ? $text{'lusers_space'} :
			      $text{'lusers_blocks'}).
		    ($access{'diskspace'} ? " ($binfo)" : ""));
	push(@tds, "colspan=$cols1 align=center");
	push(@hcols, $text{'lusers_files'}.
		    ($access{'diskspace'} ? " ($finfo)" : ""));
	push(@tds, "colspan=$cols2 align=center");
	print &ui_columns_start(\@hcols, 100, 0, \@tds);

	# Generate second header (with used/soft/hard)
	local @hcols;
	local @tds;
	if (!$access{'ro'}) {
		push(@hcols, "");
		push(@tds, "width=5");
		}
	push(@hcols, $text{'lgroups_group'});
	if ($threshold_pc != 101) {
		push(@hcols, $text{'lusers_pc_hblocks'});
		}
	push(@hcols, $text{'lusers_used'}, $text{'lusers_soft'},
		    $text{'lusers_hard'},
		    $config{'show_grace'} ? ( $text{'lusers_grace'} ) : ( ));
	push(@hcols, $text{'lusers_used'}, $text{'lusers_soft'},
		    $text{'lusers_hard'},
		    $config{'show_grace'} ? ( $text{'lusers_grace'} ) : ( ));
	print &ui_columns_header(\@hcols, \@tds);

	# Sort groups
	@order = (0 .. $n-1);
	if ($config{'sort_mode'} == 0) {
		@order = sort { $group{$b,'ublocks'} <=> $group{$a,'ublocks'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 3) {
		@order = sort { $group{$b,'hblocks'} <=> $group{$a,'hblocks'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 4) {
		@order = sort { $group{$b,'sblocks'} <=> $group{$a,'sblocks'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 2) {
		@order = sort { $group{$a,'group'} cmp $group{$b,'group'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 5) {
		@order = sort { &to_percent($group{$b,'ublocks'},
					    $group{$b,'hblocks'}) <=>
				&to_percent($group{$a,'ublocks'},
					    $group{$a,'hblocks'}) } @order;
		}
	elsif ($config{'sort_mode'} == 6) {
		@order = sort { &to_percent($group{$b,'ublocks'},
					    $group{$b,'sblocks'}) <=>
				&to_percent($group{$a,'ublocks'},
					    $group{$a,'sblocks'}) } @order;
		}

	# Generate table of groups
	foreach $i (@order) {
		next if (!&can_edit_group($group{$i,'group'}));
		local @cols;
		if ($access{'ro'}) {
			push(@cols, $group{$i,'group'});
			}
		else {
			push(@cols, "<a href=\"edit_group_quota.cgi?group=".
				&urlize($group{$i,'group'})."&filesys=".
				&urlize($f)."&source=0\">$group{$i,'group'}".
				"</a>");
			}
                my $pc_hblocks=0;
                if($group{$i,'hblocks'}) {
                        $pc_hblocks = 100 * $group{$i,'ublocks'};
                        $pc_hblocks/= $group{$i,'hblocks'};
                        $pc_hblocks = int($pc_hblocks);
			}
		if ($threshold_pc != 101) {
			if ($pc_hblocks > $threshold_pc) {
				push(@cols, "<font color=#ff0000>".
					&html_escape($pc_hblocks)."%</font>");
				}
			else {
				push(@cols, &html_escape($pc_hblocks)."%");
				}
			}
		local $ublocks = $group{$i,'ublocks'}; 
		if ($bsize) {
			$ublocks = &nice_size($ublocks*$bsize);
			}
		if ($group{$i,'hblocks'} &&
		    $group{$i,'ublocks'} > $group{$i,'hblocks'}) {
			push(@cols, "<font color=#ff0000>".
				&html_escape($ublocks)."</font>");
			}
		elsif ($group{$i,'sblocks'} &&
		       $group{$i,'ublocks'} > $group{$i,'sblocks'}) {
			push(@cols, "<font color=#ff7700>".
				&html_escape($ublocks)."</font>");
			}
		else {
			push(@cols, &html_escape($ublocks));
			}
		push(@cols, &nice_limit($group{$i,'sblocks'}, $bsize));
		push(@cols, &nice_limit($group{$i,'hblocks'}, $bsize));
		push(@cols, $group{$i,'gblocks'}) if ($config{'show_grace'});
		push(@cols, $group{$i,'ufiles'});
		push(@cols, &nice_limit($group{$i,'sfiles'}, $bsize, 1));
		push(@cols, &nice_limit($group{$i,'hfiles'}, $bsize, 1));
		push(@cols, $group{$i,'gfiles'}) if ($config{'show_grace'});
		if ($access{'ro'}) {
			print &ui_columns_row(\@cols, \@tds);
			}
		else {
			print &ui_checked_columns_row(\@cols, \@tds, "d",
						      $group{$i,'group'});
			}
		}
	print &ui_columns_end();

	if (!$access{'ro'}) {
		print &ui_links_row(\@links);
		print &ui_submit($text{'lgroups_mass'}, "mass"),"<br>\n";
		print &ui_form_end();
		}
	}
else {
	print "<b>",&text('lgroups_noquota', $f),"</b><br>\n";
	}
&show_buttons();

if ($access{'default'}) {
	print "<hr>\n";
	print &text('lgroups_info', $text{'lusers_useradmin'});
	print "<p>\n";

	@dquot = split(/\s+/, $config{"gsync_$f"});
	print "<form action=save_gsync.cgi>\n";
	print "<input type=hidden name=filesys value=\"$f\">\n";
	print "<table width=100% border> <tr $tb>\n";
	print "<td colspan=2><b>$text{'lgroups_newgroup'}</b></td> </tr> <tr $cb>\n";

	print "<td width=50%><table><tr>\n";
	print "<td><b>$text{'lusers_sblimit'}</b></td> <td>\n";
	&quota_input("sblocks", $dquot[0], $bsize);
	print "</td> </tr><tr> <td><b>$text{'lusers_hblimit'}</b></td> <td>\n";
	&quota_input("hblocks", $dquot[1], $bsize);
	print "</td> </tr></table></td>\n";

	print "<td width=50%><table><tr>\n";
	print "<td><b>$text{'lusers_sflimit'}</b></td> <td>\n";
	&quota_input("sfiles", $dquot[2]);
	print "</td> </tr><tr> <td><b>$text{'lusers_hflimit'}</b></td> <td>\n";
	&quota_input("hfiles", $dquot[3]);
	print "</td> </tr></table></td>\n";
	print "</tr> </table>\n";
	print "<input type=submit value=$text{'lusers_apply'}></form>\n";
	}

# Show form for email notifications
if ($access{'email'} && &foreign_check("cron") &&
    &foreign_check("mailboxes")) {
	print "<hr>\n";
	print &ui_form_start("save_gemail.cgi");
	print &ui_hidden("filesys", $f);
	print &ui_table_start($text{'lgroups_emailheader'}, "width=100%", 4);

	print &ui_table_row($text{'lgroups_email'},
		    &ui_radio("email", $config{"gemail_$f"} ? 1 : 0,
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

	print &ui_table_row($text{'lusers_interval'},
		    &ui_textbox("interval", $config{"gemail_interval_$f"}, 5).
		    " ".$text{'lusers_hours'});

	print &ui_table_row($text{'lusers_ltype'},
		    &ui_radio("type", $config{"gemail_type_$f"} ? 1 : 0,
			      [ [ 1, $text{'lusers_hard'} ],
				[ 0, $text{'lusers_soft'} ] ]));

	print &ui_table_row($text{'lusers_percent'},
		    &ui_textbox("percent", $config{"gemail_percent_$f"}, 5).
		    " %");

	print &ui_table_row($text{'lgroups_to'},
	   &ui_radio("tomode", int($config{"gemail_tomode_$f"}),
	      [ [ 0, $text{'lgroups_tosame'} ],
		[ 1, &text('lgroups_tofixed',
			   &ui_textbox("to", $config{"gemail_to_$f"}, 20)) ],
		&foreign_installed("virtual-server") ?
		  ( [ 2, $text{'lgroups_tovirt'} ] ) : ( ) ]), 3);

	print &ui_table_row($text{'lusers_from'},
		    &ui_textbox("from", $config{"gemail_from_$f"} ||
					'webmin@'.&get_system_hostname(), 20));

	print &ui_table_end();
	print &ui_form_end([ [ 'save', $text{'lusers_apply'} ] ]);
	}



&ui_print_footer("", $text{'lgroups_return'});

sub show_buttons
{
print "<table width=100%><tr>\n";
if (!$access{'ro'}) {
	print "<form action=edit_group_quota.cgi>\n";
	print "<input type=hidden name=filesys value=\"$f\">\n";
	print "<input type=hidden name=source value=0>\n";
	print "<td align=left width=33%>\n";
	print "<input type=submit value=\"$text{'lgroups_equota'}\">\n";
	print "<input name=group size=8> ",
	      &group_chooser_button("group", 0, $form),"</td></form>\n";
	$form++;
	}
else { print "<td width=33%></td>\n"; }

if ($access{'ggrace'}) {
	print "<form action=group_grace_form.cgi>\n";
	print "<input type=hidden name=filesys value=\"$f\">\n";
	print "<td align=center width=33%>\n";
	print "<input type=submit value=\"$text{'lgroups_grace'}\">\n";
	print "</td></form>\n";
	$form++;
	}
else { print "<td width=33%></td>\n"; }

print "<form action=check_quotas.cgi>\n";
print "<input type=hidden name=filesys value=\"$f\">\n";
print "<input type=hidden name=source value=group>\n";
print "<td align=right width=33%><input type=submit value=\"$text{'lgroups_check'}\">\n";
print "</td></form> </tr></table>\n";
$form++;
}

