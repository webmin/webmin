#!/usr/local/bin/perl
# Show a form for displaying the status of one storage daemon

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'storagestatus_title'}, "", "storagestatus");
&ReadParse();

# Storage selector
@storages = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		 &get_bacula_storages();
if (@storages == 1) {
	$in{'storage'} ||= $storages[0]->{'name'};
	}
print &ui_form_start("storagestatus_form.cgi");
print "<b>$text{'storagestatus_show'}</b>\n";
print &ui_select("storage", $in{'storage'},
	 [ map { [ $_->{'name'},
		   &text('storagestatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @storages ]);
print &ui_submit($text{'storagestatus_ok'}),"<br>\n";
print &ui_form_end();

if ($in{'storage'}) {
	# Show this storage
	($msg, $ok, $run, $done) = &get_storage_status($in{'storage'});

	if ($ok) {
		print &text('storagestatus_msg', $in{'storage'}, $msg),"<p>\n";

		# Running jobs
		print &ui_subheading($text{'dirstatus_run'});
		if (@$run) {
			print &ui_form_start("cancel_jobs.cgi", "post");
			print &ui_hidden("storage", $in{'storage'}),"\n";
			@links = ( &select_all_link("d", 1),
				   &select_invert_link("d", 1) );
			print &ui_links_row(\@links);
			@tds = ( "width=5" );
			print &ui_columns_start([ "", $text{'dirstatus_name'},
						  $text{'dirstatus_id'},
						  $text{'dirstatus_level'},
						  $text{'dirstatus_status'} ],
						"100%", 0, \@tds);
			foreach $j (@$run) {
				print &ui_checked_columns_row([
					&joblink($j->{'name'}),
					$j->{'id'},
					$j->{'level'},
					$j->{'status'} ], \@tds,
					"d", $j->{'id'});
				}
			print &ui_columns_end();
			print &ui_links_row(\@links);
			print &ui_form_end([ [ "cancel", $text{'dirstatus_cancel'} ] ]);
			}
		else {
			print "<b>$text{'dirstatus_runnone'}</b><p>\n";
			}

		# Completed jobs
		print &ui_subheading($text{'dirstatus_done'});
		if (@$done) {
			print &ui_columns_start([ $text{'dirstatus_name'},
						  $text{'dirstatus_id'},
						  $text{'dirstatus_level'},
						  $text{'dirstatus_date'},
						  $text{'dirstatus_bytes'},
						  $text{'dirstatus_files'},
						  $text{'dirstatus_status2'} ],
						"100%");
			foreach $j (@$done) {
				print &ui_columns_row([
					&joblink($j->{'name'}),
					$j->{'id'},
					$j->{'level'},
					$j->{'date'},
					&nice_size($j->{'bytes'}),
					$j->{'files'},
					$j->{'status'} ]);
				}
			print &ui_columns_end();
			}
		else {
			print "<b>$text{'dirstatus_donenone'}</b><p>\n";
			}
		}
	else {
		# Couldn't connect!
		print "<b>",&text('storagestatus_err', $in{'storage'}, $msg),
		      "</b><p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});


