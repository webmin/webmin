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
	print $text{'index_descdownload'},"<p>\n";

	print &ui_form_start("download.cgi", "post");
	print &ui_table_start($text{'index_header1'}, "width=100%", 4);

	# URLs to download
	print &ui_table_row($text{'index_urls'},
		&ui_textarea("urls", undef, 4, 70), 3);

	# Destination directory
	print &ui_table_row($text{'index_ddir'},
		&ui_textbox("dir", $download_dir, 60)." ".
		&file_chooser_button("dir", 1, $form)."<br>".
		&ui_checkbox("mkdir", 1, $text{'index_mkdir'}, 0), 3);

	if ($can_mode != 3) {
		# Ask for user and group to download as
		print &ui_table_row($text{'index_user'},
			&ui_user_textbox("user", $download_user, $form));

		print &ui_table_row($text{'index_group'},
			&ui_opt_textbox("group", $download_group, 13,
					$text{'default'})." ".
			&group_chooser_button("group", 0, $form));
		}

	if ($can_schedule) {
		# Download time can be selected, for scheduling with At
		@now = localtime(time());
		print &ui_table_row($text{'index_bg'},
			&ui_radio("bg", 0, [ [ 0, $text{'index_bg0'}."<br>" ],
					     [ 1, $text{'index_bg1'} ] ])." ".
			&ui_textbox("day", $now[3], 2)."/".
			&ui_select("month", $now[4],
			  [ map { [ $_, $text{"smonth_".($_+1)} ] }
				(0 .. 11) ])."/".
			&ui_textbox("year", $now[5]+1900, 4)." ".
			&date_chooser_button("day", "month", "year", $form)." ".
			$text{'index_time'}."\n".
			&ui_textbox("hour", sprintf("%2.2d", $now[2]), 2).":".
			&ui_textbox("min", sprintf("%2.2d", $now[1]), 2), 3);
		}
	elsif ($can_background) {
		# Download must be immediate, but can be backgrounded
		print &ui_table_row($text{'index_bg'},
			&ui_radio("bg", 0, [ [ 0, $text{'index_bg0'} ],
					     [ 1, $text{'index_bg1u'} ] ]));
		}
	else {
		# Download is always right now
		}

	# Email address to notify when done
	if ($can_schedule || $can_background) {
		print &ui_table_row($text{'index_email'},
			&ui_opt_textbox("email", undef, 40,
				$text{'no'}, $text{'index_emailto'}), 3);
		}

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'index_down'} ] ]);
	$form++;

	# Show current list of scheduled or active downloads
	@downs = grep { &can_as_user($_->{'user'}) } &list_downloads();
	if (@downs) {
		@tds = $notdone ? ( "width=5" ) : ( );
		local ($notdone) = grep { !$_->{'complete'} } @downs;
		print &ui_form_start("cancel.cgi");
		print &ui_columns_start([
			$notdone ? ( "" ) : ( ),
			$text{'index_urls'}, $text{'index_dest'},
			$text{'index_when'}, $text{'index_user'},
			$text{'index_prog'} ], 100, 0, \@tds);
		foreach $d (@downs) {
			local @cols;
			local $count = 0;
			local @urls;
			while($url = $d->{"url_$count"}) {
				print "<br>\n" if ($count);
				if (length($url) > 70 && $url =~ /^([^:]+:\/\/[^\/]+\/)(.*)(\/[^\/]+)$/) {
					push(@urls, &html_escape("$1 .. $3"));
					}
				else {
					push(@urls, &html_escape($url));
					}
				$count++;
				}
			push(@cols, join("<br>\n", @urls));
			push(@cols, &html_escape($d->{'dir'}));
			push(@cols, $d->{'time'} ? &make_date($d->{'time'})
					         : $text{'index_imm'});
			push(@cols, &html_escape($d->{'user'}));
			if ($d->{'error'}) {
				push(@cols, "<font color=#ff0000>".
				   ($count > 1 ? &text('index_upto',
					$d->{'upto'}+1, $count)." " : "").
				   "$d->{'error'}</font>");
				&delete_download($d);
				}
			elsif (!defined($d->{'upto'})) {
				push(@cols, $text{'index_noprog'});
				}
			elsif ($d->{'complete'}) {
				push(@cols, "<font color=#00ff00>".
					  "$text{'index_done'} (".
					  &nice_size($d->{'total'}).")</font>");
				&delete_download($d);
				}
			else {
				push(@cols, ($count > 1 ? 
				    &text('index_upto',
					$d->{'upto'}+1, $count)." " : "").
				    &nice_size($d->{'got'})." ".
				    ($d->{'size'} ?
					"(".int($d->{'got'}*100/$d->{'size'}).
					"%)" : ""));
				}
			if (!$d->{'complete'}) {
				print &ui_checked_columns_row(\@cols, \@tds,
						      "cancel", $d->{'id'});
				}
			else {
				@cols = ( "", @cols ) if ($notdone);
				print &ui_columns_row(\@cols, \@tds);
				}
			}
		print &ui_columns_end();
		print &ui_form_end($notdone ?
			[ [ undef, $text{'index_cancel'} ] ] : [ ]);
		$form++;
		}
	print &ui_tabs_end_tab();
	}

if ($can_upload) {
	# Show form for uploading
	print &ui_tabs_start_tab("mode", "upload");
	print $text{'index_descupload'},"<p>\n";
	local $upid = time().$$;
	print &ui_form_start("upload.cgi?id=$upid", "form-data", undef,
			     &read_parse_mime_javascript($upid,
			       [ "upload0", "upload1", "upload2", "upload3" ]));
	print &ui_table_start($text{'index_header2'}, "width=100%", 2);

	# Upload fields
	$utable = "";
	for($i=0; $i<4; $i++) {
		$utable .= &ui_upload("upload$i", 40, 0, undef, 1)."\n";
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

	# Email notification
	print &ui_table_row($text{'index_email2'},
		&ui_opt_textbox("email", undef, 40,
			$text{'no'}, $text{'index_emailto'}), 3);

	print &ui_table_end();
	print &ui_form_end([ [ "ok", $text{'index_ok'} ] ]);
	$form++;
	print &ui_tabs_end_tab();
	}

if ($can_fetch) {
	# Show form to download fetch from server to PC
	print &ui_tabs_start_tab("mode", "fetch");
	print $text{'index_descfetch'},"<p>\n";
	print &ui_form_start("fetch.cgi");
	print &ui_table_start($text{'index_header3'}, "width=100%", 4);

	# File to fetch
	print &ui_table_row($text{'index_fetch'},
		&ui_textbox("fetch", $fetch_file, 50)." ".
		&file_chooser_button("fetch", 0, $form), 3);

	# Show in browser?
	print &ui_table_row($text{'index_show'},
		&ui_yesno_radio("show", $fetch_show));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'index_ok2'} ] ]);
	$form++;
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});


