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
&ui_print_header(&text('lusers_qoutas', $f), $text{'lusers_title'},
		 "", "list_users");

# Build and show tabs
$prog = "list_users.cgi?dir=".&urlize($f);
@tabs = ( [ 'list', $text{'lusers_tablist'}, $prog."&mode=list" ] );
if ($access{'default'}) {
	push(@tabs, [ 'default', $text{'lusers_tabdefault'},
		      $prog."&mode=default" ]);
	}
if ($access{'email'} && &foreign_check("cron") && &foreign_check("mailboxes")) {
	push(@tabs, [ 'email', $text{'lusers_tabemail'},
		      $prog."&mode=email" ]);
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || 'list', 1);

# Build user list links
@ulinks = ( );
if ($access{'ugrace'}) {
	push(@ulinks, &ui_link("user_grace_form.cgi?filesys=".&urlize($f), $text{'lusers_egrace'}) );
	}
if (!defined(&can_quotacheck) || &can_quotacheck($f)) {
	push(@ulinks, &ui_link("check_quotas.cgi?filesys=".&urlize($f)."&source=user", $text{'lusers_check'}) );
	}

# Users list, in a tab
print &ui_tabs_start_tab("mode", "list");
$n = &filesystem_users($f);
$bsize = &block_size($f);
$fsbsize = &block_size($f, 1);
if ($n > $config{'display_max'} && !$access{'ro'}) {
	print "<b>", &text('lusers_toomany', $f), "</b><p>\n";
	print &ui_links_row(\@ulinks);
	}
elsif ($n) {
	# no threshold (default) if <= 0% and >=101%
	my $threshold_pc = $config{'threshold_pc'} || 101;
	$threshold_pc = 101 if $threshold_pc < 1 or $threshold_pc > 101;
	if (!$access{'ro'}) {
		print &ui_form_start("edit_user_mass.cgi", "post");
		print &ui_hidden('dir', $f),"\n";
		}

	# Generate summary of blocks and files used
	($binfo, $finfo) = &filesystem_info($f, \%user, $n, $fsbsize);
	$show_pc_hblocks = $threshold_pc != 101 &&
			   $config{'pc_show'} >= 1;
	$show_pc_sblocks = $threshold_pc != 101 &&
			   $config{'pc_show'}%2 == 0;
	print "<b>";
	print $bsize ? $text{'lusers_space'}
		     : $text{'lusers_blocks'};
	print $access{'diskspace'} ? " ($binfo)" : "";
	print "&nbsp;\n";
	print $text{'lusers_files'};
	print $access{'diskspace'} ? " ($finfo)" : "";
	print "</b><br>\n";

	# Generate select links
	@links = ( &select_all_link("d", $form),
		   &select_invert_link("d", $form),
	 	   @ulinks );
	if (!$access{'ro'}) {
		print &ui_links_row(\@links);
		}

	# Generate header (with used/soft/hard)
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
	print &ui_columns_start(\@hcols, \@tds);

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
		next if ($config{'hide_uids'} &&
			 $user{$i,'user'} =~ /^#/);
		local @cols;
		if ($access{'ro'}) {
			push(@cols, $user{$i,'user'});
			}
		else {
			push(@cols, &ui_link("edit_user_quota.cgi?user=".
				&urlize($user{$i,'user'})."&filesys=".
				&urlize($f)."&source=0", $user{$i,'user'}) );
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
				$ublocks."</font>");
			}
		elsif ($user{$i,'sblocks'} &&
		       $user{$i,'ublocks'} > $user{$i,'sblocks'}) {
			push(@cols, "<font color=#ff7700>".
				$ublocks."</font>");
			}
		else {
			push(@cols, $ublocks);
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
	print "<b>",&text('lusers_noquota', $f),"</b><p>\n";
	print &ui_links_row(\@ulinks);
	}

# Form to edit any user
if (!$access{'ro'}) {
	print &ui_form_start("edit_user_quota.cgi");
	print &ui_hidden("filesys", $f);
	print &ui_hidden("source", 0);
	print &ui_submit($text{'lusers_equota'});
	print &ui_user_textbox("user");
	print &ui_form_end();
	}

print &ui_tabs_end_tab("mode", "list");

# Show form for setting default quotas for new users
if ($access{'default'}) {
	print &ui_tabs_start_tab("mode", "default");
	print &text('lusers_info', $text{'lusers_useradmin'}),"<p>\n";

	@dquot = split(/\s+/, $config{"sync_$f"});
	print &ui_form_start("save_sync.cgi");
	print &ui_hidden("filesys", $f);
	print &ui_table_start($text{'lusers_newuser'}, "width=100%", 4);

	# Default block limits
	print &ui_table_row($text{'lusers_sblimit'},
		&quota_input("sblocks", $dquot[0], $bsize));
	print &ui_table_row($text{'lusers_hblimit'},
		&quota_input("hblocks", $dquot[1], $bsize));

	# Default file limits
	print &ui_table_row($text{'lusers_sflimit'},
		&quota_input("sfiles", $dquot[2]));
	print &ui_table_row($text{'lusers_hflimit'},
		&quota_input("hfiles", $dquot[3]));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'lusers_apply'} ] ]);

	print &ui_tabs_end_tab("mode", "default");
	}

# Show form for email notifications
if ($access{'email'} && &foreign_check("cron") &&
    &foreign_check("mailboxes")) {
	print &ui_tabs_start_tab("mode", "email");

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
					'webmin-noreply@'.&get_system_hostname(), 30));

	print &ui_table_row($text{'lusers_cc'},
		&ui_opt_textbox("cc", $config{"email_cc_$f"}, 30,
				$text{'lusers_nocc'}), 3);

	print &ui_table_end();
	print &ui_form_end([ [ 'save', $text{'lusers_apply'} ] ]);

	print &ui_tabs_end_tab("mode", "email");
	}

print &ui_tabs_end(1);

&ui_print_footer("", $text{'lusers_return'});
