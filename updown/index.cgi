#!/usr/local/bin/perl
# index.cgi
# Display scheduled downloads, plus a form for uploading a file

require './updown-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1);
&ReadParse();

# Start tabs for modes
@tabs = ( );
if ($can_download) {
	push(@tabs, [ "download", $text{'index_tabdownload'},
		      "index.cgi?mode=download" ]);
	}
if ($can_upload) {
	push(@tabs, [ "upload", $text{'index_tabupload'},
		      "index.cgi?mode=upload" ]);
	}
if ($can_fetch) {
	push(@tabs, [ "fetch", $text{'index_tabfetch'},
		      "index.cgi?mode=fetch" ]);
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

$form = 0;
if ($can_download) {
	# Show form for downloading
	print &ui_tabs_start_tab("mode", "download");
	print "<form action=download.cgi method=post>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_header1'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td valign=top><b>$text{'index_urls'}</b></td>\n";
	print "<td colspan=3><textarea name=urls rows=4 cols=70 wrap=off>",
	      "</textarea></td> </tr>\n";

	print "<tr> <td><b>$text{'index_ddir'}</b></td>\n";
	print "<td colspan=3><input name=dir size=50 value='$download_dir'> ",
		&file_chooser_button("dir", 1, $form);
	print "<input type=checkbox name=mkdir value=1> $text{'index_mkdir'}\n";
	print "</td> </tr>\n";

	if ($can_mode != 3) {
		# Ask for user and group to download as
		print "<tr> <td><b>$text{'index_user'}</b></td>\n";
		print "<td>",&unix_user_input("user", $download_user, $form),
		      "</td>\n";

		print "<td><b>$text{'index_group'}</b></td>\n";
		printf "<td><input type=radio name=group_def value=1 %s> %s\n",
			$download_group ? "" : "checked", $text{'default'};
		printf "<input type=radio name=group_def value=0 %s>\n",
			$download_group ? "checked" : "";
		printf &unix_group_input("group", $download_group, $form),
		       "</td> </tr>\n";
		}

	if ($can_schedule) {
		# Download time can be selected, for scheduling with At
		print "<tr> <td valign=top><b>$text{'index_bg'}</b></td> <td colspan=3>\n";
		print "<input type=radio name=bg value=0 checked> $text{'index_bg0'}<br>\n";
		print "<input type=radio name=bg value=1> $text{'index_bg1'}\n";

		@now = localtime(time());
		printf "<input name=day size=2 value='%d'>/", $now[3];
		print "<select name=month>\n";
		for($i=0; $i<12; $i++) {
			printf "<option value=%s %s>%s\n",
				$i, $now[4] == $i ? 'selected' : '', $text{"smonth_".($i+1)};
			}
		print "</select>/";
		printf "<input name=year size=4 value='%d'>\n", $now[5] + 1900;
		print &date_chooser_button("day", "month", "year", $form),"\n";

		print "$text{'index_time'}\n";
		printf "<input name=hour size=2 value='%2.2d'>:<input name=min size=2 value='%2.2d'></td> </tr>\n", $now[2], $now[1];
		}
	elsif ($can_background) {
		# Download must be immediate, but can be backgrounded
		print "<tr> <td valign=top><b>$text{'index_bg'}</b></td> <td colspan=3>\n";
		print "<input type=radio name=bg value=0 checked> $text{'index_bg0'}<br>\n";
		print "<input type=radio name=bg value=1> $text{'index_bg1u'}\n";
		}
	else {
		# Download is always right now
		}

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'index_down'}'></form>\n";
	$form++;

	# Show current list of scheduled or active downloads
	@downs = grep { &can_as_user($_->{'user'}) } &list_downloads();
	if (@downs) {
		local ($notdone) = grep { !$_->{'complete'} } @downs;
		print "<form action=cancel.cgi>\n";
		print "<table border width=100%>\n";
		print "<tr $tb> ",
		      $notdone ? "<td><br></td>" : "",
		      "<td><b>$text{'index_urls'}</b></td> ",
		      "<td><b>$text{'index_dest'}</b></td> ",
		      "<td><b>$text{'index_when'}</b></td> ",
		      "<td><b>$text{'index_user'}</b></td> ",
		      "<td><b>$text{'index_prog'}</b></td> </tr>\n";
		foreach $d (@downs) {
			print "<tr $cb>\n";
			if (!$d->{'complete'}) {
				printf "<td valign=top width=5><input type=checkbox ".
				       "name=cancel value=%s></td>\n", $d->{'id'};
				}
			elsif ($notdone) {
				print "<td width=5><br></td>\n";
				}
			print "<td valign=top>\n";
			local $count = 0;
			while($url = $d->{"url_$count"}) {
				print "<br>\n" if ($count);
				if (length($url) > 70 && $url =~ /^([^:]+:\/\/[^\/]+\/)(.*)(\/[^\/]+)$/) {
					print "$1 .. $3";
					}
				else {
					print $url;
					}
				$count++;
				}
			print "</td>\n";
			printf "<td valign=top>%s</td>\n", $d->{'dir'};
			print "<td valign=top nowrap>",
				$d->{'time'} ? &make_date($d->{'time'})
					     : $text{'index_imm'},"</td>\n";
			printf "<td valign=top>%s</td>\n", $d->{'user'};
			print "<td valign=top nowrap>";
			if ($d->{'error'}) {
				print "<font color=#ff0000>\n";
				if ($count > 1) {
					print &text('index_upto',
						$d->{'upto'}+1, $count),"\n";
					}
				print "$d->{'error'}</font>\n";
				&delete_download($d);
				}
			elsif (!defined($d->{'upto'})) {
				print $text{'index_noprog'};
				}
			elsif ($d->{'complete'}) {
				print "<font color=#00ff00>$text{'index_done'} (",
					&nice_size($d->{'total'}),")</font>\n";
				&delete_download($d);
				}
			else {
				if ($count > 1) {
					print &text('index_upto',
						$d->{'upto'}+1, $count),"\n";
					}
				local $sz = &nice_size($d->{'got'});
				print "$sz\n";
				if ($d->{'size'}) {
					print "(".int($d->{'got'}*100/$d->{'size'}).
					      "%)\n";
					}
				}
			print "</td>\n";
			print "</tr>\n";
			}
		print "</table>\n";
		print "<input type=submit value='$text{'index_cancel'}'>\n"
			if ($notdone);
		print "</form>\n";
		$form++;
		}
	print &ui_tabs_end_tab();
	}

if ($can_upload) {
	# Show form for uploading
	print &ui_tabs_start_tab("mode", "upload");
	local $upid = time().$$;
	print &ui_form_start("upload.cgi?id=$upid", "form-data", undef,
			     &read_parse_mime_javascript($upid,
			       [ "upload0", "upload1", "upload2", "upload3" ]));
	print &ui_table_start($text{'index_header2'}, "width=100%", 2);

	# Upload fields
	$utable = "";
	for($i=0; $i<4; $i++) {
		$utable .= &ui_upload("upload$i")."\n";
		$utable .= "<br>\n" if ($i%2 == 1);
		}
	print &ui_table_row($text{'index_upload'}, $utable);

	# Destination directory
	print &ui_table_row($text{'index_dir'},
		&ui_textbox("dir", $upload_dir, 50)." ".
		&file_chooser_button("dir", 1, $form)." ".
		&ui_checkbox("mkdir", 1, $text{'index_mkdir'}, 0));

	if ($can_mode != 3) {
		# Allow selection of user to save as
		print &ui_table_row($text{'index_user'},
			&unix_user_input("user", $upload_user, $form));

		print &ui_table_row($text{'index_group'},
			&ui_radio("group_def", $upload_group ? 0 : 1, 
				  [ [ 1, $text{'default'} ],
				    [ 0, &unix_group_input("group",
						$upload_group, $form) ] ]));
		}

	# Unzip files
	print &ui_table_row($text{'index_zip'},
		&ui_radio("zip", 0,
			  [ [ 2, $text{'index_zipyes'} ],
			    [ 1, $text{'yes'} ],
			    [ 0, $text{'no'} ] ]));

	print &ui_table_end();
	print &ui_form_end([ [ "ok", $text{'index_ok'} ] ]);
	$form++;
	print &ui_tabs_end_tab();
	}

if ($can_fetch) {
	# Show form to download fetch from server to PC
	print &ui_tabs_start_tab("mode", "fetch");
	print "<form action=fetch.cgi method=get>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_header3'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td valign=top><b>$text{'index_fetch'}</b></td>\n";
	print "<td colspan=3>\n";
	print &ui_textbox("fetch", $fetch_file, 50),"\n",
		&file_chooser_button("fetch", 0, $form);
	print "</td> </tr>\n";

	print "<tr> <td valign=top><b>$text{'index_show'}</b></td>\n";
	print "<td>",&ui_yesno_radio("show", $fetch_show),"</td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'index_ok2'}'></form>\n";
	$form++;
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});


