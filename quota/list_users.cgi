#!/usr/local/bin/perl
# list_users.cgi
# Lists all the users with quotas on some filesystem

require './quota-lib.pl';
&ReadParse();
$f = $in{'dir'};
$whatfailed = $text{'lusers_failed'};
&can_edit_filesys($f) ||
	&error($text{'lusers_eallow'});
$form = 0;

# List quotas
&ui_print_header(undef, $text{'lusers_title'}, "", "list_users");

$n = &filesystem_users($f);
$bsize = &block_size($f);
$fsbsize = &block_size($f, 1);
if ($n > $config{'display_max'} && !$access{'ro'}) {
	print "<b>", &text('lusers_toomany', $f), "</b><br>\n";
	}
elsif ($n) {
	# no threshold (default) if <= 0% and >=101%
	my $threshold_pc = $config{'threshold_pc'} || 101;
	$threshold_pc = 101 if $threshold_pc < 1 or $threshold_pc > 101;
	print &ui_subheading(&text('lusers_qoutas', $f));
	&show_buttons();
	if (!$access{'ro'}) {
		print &ui_form_start("edit_user_mass.cgi", "post");
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
	($binfo, $finfo) = &filesystem_info($f, \%user, $n, $fsbsize);
	$show_pc_hblocks = $threshold_pc != 101 &&
			   $config{'pc_show'} >= 1;
	$show_pc_sblocks = $threshold_pc != 101 &&
			   $config{'pc_show'}%2 == 0;
	$cols1 = 3 + ($show_pc_hblocks ? 1 : 0) +
		     ($show_pc_sblocks ? 1 : 0) +
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
	push(@hcols, $text{'lusers_user'});
	if ($show_pc_hblocks) {
		push(@hcols, $text{'lusers_pc_hblocks'});
		}
	if ($show_pc_sblocks) {
		push(@hcols, $text{'lusers_pc_sblocks'});
		}
	push(@hcols, $text{'lusers_used'}, $text{'lusers_soft'},
		    $text{'lusers_hard'},
		    $config{'show_grace'} ? ( $text{'lusers_grace'} ) : ( ));
	push(@hcols, $text{'lusers_used'}, $text{'lusers_soft'},
		    $text{'lusers_hard'},
		    $config{'show_grace'} ? ( $text{'lusers_grace'} ) : ( ));
	print &ui_columns_header(\@hcols, \@tds);

	# Sort users
	@order = (0 .. $n-1);
	if ($config{'sort_mode'} == 0) {
		@order = sort { $user{$b,'ublocks'} <=> $user{$a,'ublocks'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 3) {
		@order = sort { $user{$b,'hblocks'} <=> $user{$a,'hblocks'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 4) {
		@order = sort { $user{$b,'sblocks'} <=> $user{$a,'sblocks'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 2) {
		@order = sort { $user{$a,'user'} cmp $user{$b,'user'} }
			      @order;
		}
	elsif ($config{'sort_mode'} == 5) {
		@order = sort { &to_percent($user{$b,'ublocks'},
					    $user{$b,'hblocks'}) <=>
				&to_percent($user{$a,'ublocks'},
					    $user{$a,'hblocks'}) }
			      @order;
		}
	elsif ($config{'sort_mode'} == 6) {
		@order = sort { &to_percent($user{$b,'ublocks'},
					    $user{$b,'sblocks'}) <=>
				&to_percent($user{$a,'ublocks'},
					    $user{$a,'sblocks'}) } @order;
		}

	# Generate table of users
	foreach $i (@order) {
		next if (!&can_edit_user($user{$i,'user'}));
		local @cols;
		if ($access{'ro'}) {
			push(@cols, $user{$i,'user'});
			}
		else {
			push(@cols, "<a href=\"edit_user_quota.cgi?user=".
				&urlize($user{$i,'user'})."&filesys=".
				&urlize($f)."&source=0\">$user{$i,'user'}".
				"</a>");
			}
                my $pc_hblocks=0;
                my $pc_sblocks=0;
                if($user{$i,'hblocks'}) {
                        $pc_hblocks = 100 * $user{$i,'ublocks'};
                        $pc_hblocks/= $user{$i,'hblocks'};
                        $pc_hblocks = int($pc_hblocks);
			}
                if($user{$i,'sblocks'}) {
                        $pc_sblocks = 100 * $user{$i,'ublocks'};
                        $pc_sblocks/= $user{$i,'sblocks'};
                        $pc_sblocks = int($pc_sblocks);
			}
		if ($show_pc_hblocks) {
			if ($pc_hblocks > $threshold_pc) {
				push(@cols, "<font color=#ff0000>".
					&html_escape($pc_hblocks)."%</font>");
				}
			else {
				push(@cols, &html_escape($pc_hblocks)."%");
				}
			}
		if ($show_pc_sblocks) {
			if ($pc_sblocks > $threshold_pc) {
				push(@cols, "<font color=#ff0000>".
					&html_escape($pc_sblocks)."%</font>");
				}
			else {
				push(@cols, &html_escape($pc_sblocks)."%");
				}
			}
		local $ublocks = $user{$i,'ublocks'}; 
		if ($bsize) {
			$ublocks = &nice_size($ublocks*$bsize);
			}
		if ($user{$i,'hblocks'} &&
		    $user{$i,'ublocks'} > $user{$i,'hblocks'}) {
			push(@cols, "<font color=#ff0000>".
				&html_escape($ublocks)."</font>");
			}
		elsif ($user{$i,'sblocks'} &&
		       $user{$i,'ublocks'} > $user{$i,'sblocks'}) {
			push(@cols, "<font color=#ff7700>".
				&html_escape($ublocks)."</font>");
			}
		else {
			push(@cols, &html_escape($ublocks));
			}
		push(@cols, &nice_limit($user{$i,'sblocks'}, $bsize));
		push(@cols, &nice_limit($user{$i,'hblocks'}, $bsize));
		push(@cols, $user{$i,'gblocks'}) if ($config{'show_grace'});
		push(@cols, $user{$i,'ufiles'});
		push(@cols, &nice_limit($user{$i,'sfiles'}, $bsize, 1));
		push(@cols, &nice_limit($user{$i,'hfiles'}, $bsize, 1));
		push(@cols, $user{$i,'gfiles'}) if ($config{'show_grace'});
		if ($access{'ro'}) {
			print &ui_columns_row(\@cols, \@tds);
			}
		else {
			print &ui_checked_columns_row(\@cols, \@tds, "d",
						      $user{$i,'user'});
			}
		}
	print &ui_columns_end();
	if (!$access{'ro'}) {
		print &ui_links_row(\@links);
		print &ui_submit($text{'lusers_mass'}, "mass"),"<br>\n";
		print &ui_form_end();
		}
	}
else {
	print "<b>",&text('lusers_noquota', $f),"</b><br>\n";
	}
&show_buttons();

# Show form for setting default quotas for new users
if ($access{'default'}) {
	print "<hr>\n";
	print &text('lusers_info', $text{'lusers_useradmin'});
	print "<p>\n";

	@dquot = split(/\s+/, $config{"sync_$f"});
	print "<form action=save_sync.cgi>\n";
	print "<input type=hidden name=filesys value=\"$f\">\n";
	print "<table width=100% border> <tr $tb>\n";
	print "<td colspan=2><b>$text{'lusers_newuser'}</b></td> </tr> <tr $cb>\n";

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
	print &ui_form_start("save_email.cgi");
	print &ui_hidden("filesys", $f);
	print &ui_table_start($text{'lusers_emailheader'}, "width=100%", 4);

	print &ui_table_row($text{'lusers_email'},
		    &ui_radio("email", $config{"email_$f"} ? 1 : 0,
			      [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

	print &ui_table_row($text{'lusers_interval'},
		    &ui_textbox("interval", $config{"email_interval_$f"}, 5).
		    " ".$text{'lusers_hours'});

	print &ui_table_row($text{'lusers_ltype'},
		    &ui_radio("type", $config{"email_type_$f"} ? 1 : 0,
			      [ [ 1, $text{'lusers_hard'} ],
				[ 0, $text{'lusers_soft'} ] ]));

	print &ui_table_row($text{'lusers_percent'},
		    &ui_textbox("percent", $config{"email_percent_$f"}, 5).
		    " %");

	print &ui_table_row($text{'lusers_domain'},
		    &ui_textbox("domain", $config{"email_domain_$f"} ||
					  &get_system_hostname(), 20)."<br>".
		    &ui_checkbox("virtualmin", 1, $text{'luser_virtualmin'},
				 $config{"email_virtualmin_$f"}));

	print &ui_table_row($text{'lusers_from'},
		    &ui_textbox("from", $config{"email_from_$f"} ||
					'webmin@'.&get_system_hostname(), 20));

	print &ui_table_end();
	print &ui_form_end([ [ 'save', $text{'lusers_apply'} ] ]);
	}

&ui_print_footer("", $text{'lusers_return'});

# show_buttons(form)
sub show_buttons
{
print "<table width=100%><tr>\n";
if (!$access{'ro'}) {
	print "<form action=edit_user_quota.cgi>\n";
	print "<input type=hidden name=filesys value=\"$f\">\n";
	print "<input type=hidden name=source value=0>\n";
	print "<td align=left width=33%>\n";
	print "<input type=submit value=\"$text{'lusers_equota'}\">\n";
	print "<input name=user size=8> ",
	      &user_chooser_button("user", 0, $form),"</td></form>\n";
	$form++;
	}
else { print "<td width=33%></td>\n"; }

if ($access{'ugrace'}) {
	print "<form action=user_grace_form.cgi>\n";
	print "<input type=hidden name=filesys value=\"$f\">\n";
	print "<td align=center width=33%>\n";
	print "<input type=submit value=\"$text{'lusers_egrace'}\">\n";
	print "</td></form>\n";
	$form++;
	}
else { print "<td width=33%></td>\n"; }

print "<form action=check_quotas.cgi>\n";
print "<input type=hidden name=filesys value=\"$f\">\n";
print "<input type=hidden name=source value=user>\n";
print "<td align=right width=33%><input type=submit value=\"$text{'lusers_check'}\">\n";
print "</td></form> </tr></table>\n";
$form++;
}

