#!/usr/local/bin/perl
# Show a form for displaying the status of one client

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'clientstatus_title'}, "", "clientstatus");
&ReadParse();

# Client selector
@clients = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
		grep { !&is_oc_object($_, 1) } &get_bacula_clients();
if (@clients == 1) {
	$in{'client'} ||= $clients[0]->{'name'};
	}
print &ui_form_start("clientstatus_form.cgi");
print "<b>$text{'clientstatus_show'}</b>\n";
print &ui_select("client", $in{'client'},
	 [ map { [ $_->{'name'},
		   &text('clientstatus_on', $_->{'name'}, $_->{'address'}) ] }
	   @clients ]);
print &ui_submit($text{'clientstatus_ok'}),"<br>\n";
print &ui_form_end();

if ($in{'client'}) {
	# Show this client
	($msg, $ok, $run, $done) = &get_client_status($in{'client'});

	if ($ok) {
		print &text('clientstatus_msg', $in{'client'}, $msg),"<p>\n";

		# Running jobs
		print &ui_subheading($text{'dirstatus_run'});
		if (@$run) {
			print &ui_form_start("cancel_jobs.cgi", "post");
			print &ui_hidden("client", $in{'client'}),"\n";
			@links = ( &select_all_link("d", 1),
				   &select_invert_link("d", 1) );
			print &ui_links_row(\@links);
			@tds = ( "width=5" );
			print &ui_columns_start([ "", $text{'dirstatus_name'},
						  $text{'dirstatus_id'},
						  $text{'dirstatus_date2'} ],
						"100%", 0, \@tds);
			foreach $j (@$run) {
				print &ui_checked_columns_row([
					&joblink($j->{'name'}),
					$j->{'id'},
					$j->{'date'} ], \@tds, "d", $j->{'id'});
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
		print "<b>",&text('clientstatus_err', $in{'client'}, $msg),
		      "</b><p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});


