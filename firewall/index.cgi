#!/usr/local/bin/perl
# index.cgi
# Display current iptables firewall configuration from save file

require './firewall-lib.pl';
&ReadParse();
if ($iptables_save_file) {
	$desc = &text('index_editing', "<tt>$iptables_save_file</tt>");
	}
&ui_print_header(undef, $text{'index_title'}, undef, "intro", 1, 1, 0,
	&help_search_link("iptables", "man", "doc"), undef, undef, $desc);

# Check for iptables and iptables-restore commands
if ($c = &missing_firewall_commands()) {
	print "<p>",&text('index_ecommand', "<tt>$c</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the kernel supports iptables
$out = `iptables -n -t filter -L OUTPUT 2>&1`;
if ($?) {
	print "<p>",&text('index_ekernel', "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if the distro supports iptables
if (!$config{'direct'} && defined(&check_iptables) &&
    ($err = &check_iptables())) {
	print "<p>$err</p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if firewall is being started at boot
if (!$config{'direct'} && &foreign_check("init")) {
	$init_support++;
	if (defined(&started_at_boot)) {
		$atboot = &started_at_boot();
		}
	else {
		&foreign_require("init", "init-lib.pl");
		$atboot = &init::action_status("webmin-iptables") == 2;
		}
	}

# Check if the save file exists. If not, check for any existing firewall
# rules, and offer to create a save file from them
@livetables = &get_iptables_save("iptables-save 2>/dev/null |");
&shorewall_message(\@livetables);
if (!$config{'direct'} &&
    (!-s $iptables_save_file || $in{'reset'}) && $access{'setup'}) {
	@tables = @livetables;
	foreach $t (@tables) {
		$rules++ if (@{$t->{'rules'}});
		foreach $c (keys %{$t->{'defaults'}}) {
			$chains++ if ($t->{'defaults'}->{$c} ne 'ACCEPT');
			}
		$hastable{$t->{'name'}}++;
		}
	foreach $t (@known_tables) {
		system("iptables -t $t -n -L >/dev/null") if (!$hastable{$t});
		}
	if (!$in{'reset'} && ($rules || $chains)) {
		# Offer to save the current rules
		print &text('index_existing', $rules,
			    "<tt>$iptables_save_file</tt>"),"<p>\n";
		print "<form action=convert.cgi>\n";
		print "<center><input type=submit ",
		      "value='$text{'index_saveex'}'><p>\n";
		if ($init_support && !$atboot) {
			print "<input type=checkbox name=atboot value=1> ",
			      "$text{'index_atboot'}\n";
			}
		print "</center></form><p>\n";

		print "<table border width=100%>\n";
		print "<tr $tb><td><b>$text{'index_headerex'}</b></td></tr>\n";
		print "<tr $cb> <td><pre>";
		open(OUT, "iptables-save 2>/dev/null |");
		while(<OUT>) {
			print &html_escape($_);
			}
		close(OUT);
		print "</pre></td> </tr></table>\n";
		}
	else {
		# Offer to set up a firewall
		print &text($in{'reset'} ? 'index_rsetup' : 'index_setup',
			    "<tt>$iptables_save_file</tt>"),"<p>\n";
		print "<form action=setup.cgi>\n";
		print &ui_hidden("reset", $in{'reset'});
		print "<center><table><tr><td>\n";
		print "<input type=radio name=auto value=0 checked> ",
		      "$text{'index_auto0'}<p>\n";
		foreach $a (1 .. 5) {
			print "<input type=radio name=auto value=$a> ",
			      "$text{'index_auto'.$a} ",
			      &interface_choice("iface".$a),"<p>\n";
			}
		print "</td></tr></table>\n";
		print "<input type=submit value='$text{'index_auto'}'><p>\n";
		if ($init_support && !$atboot) {
			print "<input type=checkbox name=atboot value=1> ",
			      "$text{'index_atboot'}\n";
			}
		print "</center></form>\n";
		}
	}
else {
	$form = 0;
	@tables = &get_iptables_save();
	if (!$config{'direct'}) {
		# Verify that all known tables exist, and if not add them to the
		# save file
		foreach $t (@tables) {
			$hastable{$t->{'name'}}++;
			}
		foreach $t (@known_tables) {
			if (!$hastable{$t}) {
				local ($missing) = &get_iptables_save(
				    "iptables-save --table $t 2>/dev/null |");
				if ($missing) {
					delete($missing->{'line'});
					&save_table($missing);
					}
				$need_reload++;
				}
			}
		@tables = &get_iptables_save() if ($need_reload);
		}

	# Work out the default table
	if (!defined($in{'table'})) {
		foreach $t (@tables) {
			if (@{$t->{'rules'}} && &can_edit_table($t->{'name'})) {
				$in{'table'} = $t->{'index'};
				last;
				}
			}
		}
	if (!defined($in{'table'})) {
		foreach $t (@tables) {
			if (&can_edit_table($t->{'name'})) {
				$in{'table'} = $t->{'index'};
				last;
				}
			}
		}
	$table = $tables[$in{'table'}];

	# Allow selection of a table
	print "<table width=100%><tr>\n";
	print "<form action=index.cgi>\n";
	print "<td><input type=submit value='$text{'index_change'}'>\n";
	print "<select name=table onChange='form.submit()'>\n";
	foreach $t (@tables) {
		if (&can_edit_table($t->{'name'})) {
			printf "<option value=%s %s>%s\n",
			    $t->{'index'}, $t eq $table ? "selected" : "",
			    &text('index_table_'.$t->{'name'}) || $t->{'name'};
			}
		}
	print "</select></td></form>\n";
	$form++;

	if ($access{'newchain'}) {
		# Show form to create a chain
		print "<form action=newchain.cgi>\n";
		print "<td align=right>",&ui_hidden("table", $in{'table'});
		print "<input type=submit value='$text{'index_cadd'}'>\n";
		print "<input name=chain size=20></td></form>\n";
		print "</tr></table>\n";
		$form++;
		}

	# Display a table of rules for each chain
	foreach $c (sort by_string_for_iptables keys %{$table->{'defaults'}}) {
		print &ui_hr();
		@rules = grep { lc($_->{'chain'}) eq lc($c) }
			      @{$table->{'rules'}};
		print "<b>",$text{"index_chain_".lc($c)} ||
			    &text('index_chain', "<tt>$c</tt>"),"</b><br>\n";
		print "<form action=save_policy.cgi>\n";
		print &ui_hidden("table", $in{'table'});
		print &ui_hidden("chain", $c);
		if (@rules) {
			@links = ( &select_all_link("d", $form),
				   &select_invert_link("d", $form) );
			print &ui_links_row(\@links);

			# Generate the header
			local (@hcols, @tds);
			push(@hcols, "", $text{'index_action'});
			push(@tds, "width=5", "width=10% nowrap");
			if ($config{'view_condition'}) {
				push(@hcols, $text{'index_desc'});
				push(@tds, "");
				}
			if ($config{'view_comment'}) {
				push(@hcols, $text{'index_comm'});
				push(@tds, "");
				}
			push(@hcols, $text{'index_move'}, $text{'index_add'});
			push(@tds, "width=32", "width=32");
			print &ui_columns_start(\@hcols, 100, 0, \@tds);

			# Generate a row for each rule
			foreach $r (@rules) {
				$edit = &can_jump($r);
				local @cols;
				local $act =
				  $text{"index_jump_".lc($r->{'j'}->[1])} ||
				  &text('index_jump', $r->{'j'}->[1]);
				if ($edit) {
					push(@cols, "<a href='edit_rule.cgi?table=".&urlize($in{'table'})."&idx=$r->{'index'}'>$act</a>");
					}
				else {
					push(@cols, $act);
					}
				if ($config{'view_condition'}) {
					push(@cols, &describe_rule($r));
					}
				if ($config{'view_comment'}) {
					$cmt = $config{'comment_mod'} ?
					    $r->{'comment'}->[1] : $r->{'cmt'};
					push(@cols, $cmt);
					}

				# Up/down mover
				local $mover;
				if ($r eq $rules[@rules-1]) {
					$mover .= "<img src=images/gap.gif>";
					}
				else {
					$mover .= "<a href='move.cgi?table=".
					      &urlize($in{'table'}).
					      "&idx=$r->{'index'}&".
					      "down=1'><img src=".
					      "images/down.gif border=0></a>";
					}
				if ($r eq $rules[0]) {
					$mover .= "<img src=images/gap.gif>";
					}
				else {
					$mover .= "<a href='move.cgi?table=".
					      &urlize($in{'table'}).
					      "&idx=$r->{'index'}&".
					      "up=1'><img src=images/up.gif ".
					      "border=0></a>";
					}
				push(@cols, $mover);

				# Before / after adder
				local $adder;
				$adder .= "<a href='edit_rule.cgi?table=".
				      &urlize($in{'table'}).
				      "&chain=".&urlize($c)."&new=1&".
				      "after=$r->{'index'}'><img src=".
				      "images/after.gif border=0></a>";
				$adder .= "<a href='edit_rule.cgi?table=".
				      &urlize($in{'table'}).
				      "&chain=".&urlize($c)."&new=1&".
				      "before=$r->{'index'}'><img src=".
				      "images/before.gif border=0></a>";
				push(@cols, $adder);

				if ($edit) {
					print &ui_checked_columns_row(
					    \@cols, \@tds, "d", $r->{'index'});
					}
				else {
					print &ui_columns_row(\@cols, \@tds);
					}
				}
			print &ui_columns_end();
			print &ui_links_row(\@links);
			}
		else {
			print "<b>$text{'index_none'}</b><br>\n";
			}

		# Show policy changing button for chains that support it,
		# and rule-adding button
		print "<table width=100%><tr>\n";
		local $d = $table->{'defaults'}->{$c};
		if ($d ne '-') {
			# Built-in chain
			if ($access{'policy'}) {
				# Change default button
				print "<td width=33% nowrap>",
				      &ui_submit($text{'index_policy'}),"\n";
				print "<select name=policy>\n";
				foreach $t ('ACCEPT','DROP','QUEUE','RETURN') {
					printf "<option value=%s %s>%s\n",
						$t, $d eq $t ? "selected" : "",
						$text{"index_policy_".lc($t)};
					}
				print "</select></td>\n";
				}
			else {
				print "<td width=33%></td>\n";
				}
			print "<td align=center width=33%>\n";
			if (@rules) {
				# Delete selected button
				print &ui_submit($text{'index_cdeletesel'},
						 "delsel"),"\n";

				# Move selected button
				print &ui_submit($text{'index_cmovesel'},
						 "movesel"),"\n";
				}
			print "</td>\n";
			}
		else {
			# Custom chain
			if ($access{'delchain'}) {
				# Delete and rename chain buttons
				print "<td width=33%>",
				   &ui_submit($text{'index_cdelete'}, "delete"),
				   "\n",
				   &ui_submit($text{'index_crename'}, "rename"),
				   "</td>\n";
				}
			print "<td align=center width=33%>\n";
			if (@rules) {
				# Clear chain button
				if ($access{'delchain'}) {
					print &ui_submit($text{'index_cclear'},
							 "clear"),"\n";
					}

				# Delete rules button
				print &ui_submit($text{'index_cdeletesel'},
						 "delsel"),"\n";

				# Move selected button
				print &ui_submit($text{'index_cmovesel'},
						 "movesel"),"\n";
				}
			print "</td>\n";
			}
		print "<td align=right width=33%>",
		      &ui_submit($text{'index_radd'}, "add"),"</td>\n";
		print "</tr></table></form>\n";
		$form++;
		}

	# Display buttons for applying and un-applying the configuration,
	# and for creating an init script if possible
	print &ui_hr();
	print "<table width=100%>\n";

	if (!$config{'direct'}) {
		if (&foreign_check("servers")) {
			@servers = &list_cluster_servers();
			}
		if ($access{'apply'}) {
			print "<tr><form action=apply.cgi>\n";
			print &ui_hidden("table", $in{'table'});
			print "<td><input type=submit ",
			      "value='$text{'index_apply'}'></td>\n";
			if (@servers) {
				print "<td>$text{'index_applydesc2'}</td>\n";
				}
			else {
				print "<td>$text{'index_applydesc'}</td>\n";
				}
			print "</form></tr>\n";
			}

		if ($access{'unapply'}) {
			print "<tr><form action=unapply.cgi>\n";
			print &ui_hidden("table", $in{'table'});
			print "<td><input type=submit ",
			      "value='$text{'index_unapply'}'></td>\n";
			print "<td>$text{'index_unapplydesc'}</td>\n";
			print "</form></tr>\n";
			}

		if ($init_support && $access{'bootup'}) {
			print "<tr><form action=bootup.cgi>\n";
			print &ui_hidden("table", $in{'table'});
			print "<td nowrap><input type=submit ",
			      "value='$text{'index_bootup'}'>\n";
			printf "<input type=radio name=boot value=1 %s> %s\n",
				$atboot ? "checked" : "", $text{'yes'};
			printf "<input type=radio name=boot value=0 %s> %s\n",
				$atboot ? "" : "checked", $text{'no'};
			print "</td> <td>$text{'index_bootupdesc'}</td>\n";
			print "</form></tr>\n";
			}

		if ($access{'setup'}) {
			print "<tr><form action=index.cgi>\n";
			print "<input type=hidden name=reset value=1>\n";
			print "<td><input type=submit ",
			      "value='$text{'index_reset'}'></td>\n";
			print "<td>$text{'index_resetdesc'}</td>\n";
			print "</form></tr>\n";
			}
		}

	# Show button for cluster page
	if (&foreign_check("servers")) {
		&foreign_require("servers", "servers-lib.pl");
		@allservers = grep { $_->{'user'} }
				&servers::list_servers();
		}
	if ($access{'cluster'} && @allservers) {
		print "<tr><form action=cluster.cgi>\n";
		print "<td><input type=submit ",
		      "value='$text{'index_cluster'}'></td>\n";
		print "<td>$text{'index_clusterdesc'}</td>\n";
		print "</form></tr>\n";
		}

	print "</table>\n";
	}

&ui_print_footer("/", $text{'index'});

sub shorewall_message
{
local ($filter) = grep { $_->{'name'} eq 'filter' } @{$_[0]};
if ($filter->{'defaults'}->{'shorewall'}) {
	print "<b><center>",
	      &text('index_shorewall', "$gconfig{'webprefix'}/shorewall/"),
	      "</b></center><p>\n";
	}
}

