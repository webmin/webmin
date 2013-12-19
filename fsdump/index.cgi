#!/usr/local/bin/perl
# index.cgi
# Display a list of scheduled dumps

require './fsdump-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

@fslist = &supported_filesystems();
if (!@fslist && !$supports_tar) {
	print "<p>",&text('index_ecommands', "<tt>dump</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

print &ui_subheading($text{'index_jobs'});
@alldumps = &list_dumps();
@dumps = grep { &can_edit_dir($_) } @alldumps;
&foreign_require("cron", "cron-lib.pl");
if (@dumps) {
	($nontar) = grep { $_->{'fs'} ne 'tar' } @dumps;
	print &ui_form_start("delete_dumps.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d") );
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([
		"",
		$text{'dump_dir'},
		$text{'dump_fs'},
		$nontar ? ( $text{'dump_level'} ) : ( ),
		$text{'dump_dest'},
		$text{'dump_sched'},
		$text{'dump_when'},
		$text{'index_action'} ], 100, 0, \@tds);
	foreach $d (@dumps) {
		local @cols;
		@dirs = &dump_directories($d);
		$dirs = join("<br>", map { &html_escape($_) } @dirs);
		if ($access{'edit'}) {
			push(@cols, &ui_link("edit_dump.cgi?id=".$d->{'id'}, "<tt>$dirs</tt>") );
			}
		else {
			push(@cols, "<tt>$dirs</tt>");
			}
		push(@cols, uc($d->{'fs'}));
		push(@cols, &html_escape($d->{'level'})) if ($nontar);
		push(@cols, "<tt>".&dump_dest($d)."</tt>");
		push(@cols, $d->{'enabled'} ? $text{'yes'} : $text{'no'});
		$using_strftime++ if ($d->{'file'} =~ /%/ ||
				      $d->{'hfile'} =~ /%/);
		if ($d->{'follow'}) {
			$f = &get_dump($d->{'follow'});
			push(@cols, &text('index_follow',
					  "<tt>$f->{'dir'}</tt>"));
			}
		else {
			push(@cols, &cron::when_text($d, 1));
			}
		push(@cols, &ui_link("backup.cgi?id=".$d->{'id'}, $text{'index_now'}) );
		print &ui_checked_columns_row(\@cols, \@tds, "d", $d->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
elsif (!@alldumps) {
	print "<b>$text{'index_none'}</b><p>\n";
	}
else {
	print "<b>$text{'index_none2'}</b><p>\n";
	}
if ($using_strftime && !$config{'date_subs'}) {
	print "<font color=#ff0000><b>$text{'index_nostrftime'}",
	      "</b></font><p>\n";
	}

# Form to add
print "<form action=edit_dump.cgi>\n";
print "<input type=submit value='$text{'index_add'}'>\n";
print "<input name=dir size=20> ",&file_chooser_button("dir"),"\n";
if ($supports_tar && !$config{'always_tar'}) {
	print &ui_checkbox("forcetar", 1, $text{'index_forcetar'}, 0),"\n";
	}
print "</form>\n";

if ($access{'restore'}) {
	# Display restore button
	print &ui_hr();
	print &ui_buttons_start();

	@fstypes = ( );
	push(@fstypes, &supported_filesystems()) if (!$config{'always_tar'});
	push(@fstypes, "tar") if ($supports_tar);
	if (@fstypes > 1) {
		print &ui_buttons_row("restore_form.cgi",
				      $text{'index_restore'},
				      $text{'index_restoremsg'},
				      undef,
				      &ui_select("fs", undef,
					[ map { [ $_, uc($_) ] } @fstypes ]));
		}
	else {
		print &ui_buttons_row("restore_form.cgi",
				      $text{'index_restore2'},
				      $text{'index_restoremsg'},
				      &ui_hidden("fs", $fstypes[0]));
		}

	print &ui_buttons_end();
	}

# Display running backup jobs list, if any
&foreign_require("proc", "proc-lib.pl");
@procs = &proc::list_processes();
@running = grep { &can_edit_dir($_) } &running_dumps(\@procs);
if (@running) {
	print &ui_hr();
	print &ui_subheading($text{'index_running'});
	print &ui_columns_start([ $text{'dump_dir'},
				  $text{'dump_dest'},
				  $text{'index_start'},
				  $text{'index_status'},
				  $text{'index_action'} ], 100);
	foreach $d (@running) {
		@dirs = &dump_directories($d);
		$dirs = join("<br>", map { &html_escape($_) } @dirs);
		local @cols;
		push(@cols, "<tt>$dirs</tt>");
		push(@cols, "<tt>".&dump_dest($d)."</tt>");
		push(@cols, &make_date($d->{'status'}->{'start'}));
		push(@cols, $text{'index_status_'.$d->{'status'}->{'status'}});
		local $action;
		if ($d->{'status'}->{'status'} eq 'running' ||
		    $d->{'status'}->{'status'} eq 'tape') {
			$action .= &ui_link("kill.cgi?id=$d->{'id'}&pid=".$d->{'pid'}, $text{'index_kill'});
            $action .= "\n";
			}
		if ($d->{'status'}->{'status'} eq 'tape') {
			$action .= "&nbsp;|&nbsp;\n";
			$action .= &ui_link("newtape.cgi?id=".$d->{'id'}."&pid=".$d->{'pid'}, $text{'index_newtape'});
            $action .= "\n";
			}
		if ($d->{'status'}->{'status'} eq 'complete' ||
		    $d->{'status'}->{'status'} eq 'failed' ||
		    $d->{'status'}->{'status'} eq 'verifyfailed') {
			$action .= $text{'index_noaction'};
			}
		push(@cols, $action);
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}

&ui_print_footer("/", $text{'index'});

