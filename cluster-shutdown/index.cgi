#!/usr/local/bin/perl
# Show a list of cluster servers that can be shut down

require './cluster-shutdown-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);

@servers = grep { $_->{'user'} } &servers::list_servers();
%up = &get_all_statuses(\@servers);

if (@servers) {
	print &ui_form_start("shutdown.cgi", "post");
	@links = ( &select_all_link("id"),
		   &select_invert_link("id") );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'index_host'},
				  $text{'index_desc'},
				  $text{'index_os'},
				  $text{'index_up'} ]);
	foreach $s (@servers) {
		($st) = grep { $_->[0] eq $s->{'type'} } @servers::server_types;
		print &ui_checked_columns_row(
			[ $s->{'host'},
			  $s->{'desc'},
			  $st->[1],
			  $up{$s} == 1 ?
			    "<font color=#00aa00>$text{'yes'}</font>" :
			  $up{$s} == 2 ?
			    "<font color=#000000>$text{'index_nu'}</font>" :
			  $up{$s} == 3 ?
			    "<font color=#ffaa00>$text{'index_nl'}</font>" :
			    "<font color=#ff0000>$text{'no'}</font>" ],
			undef, "id", $s->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	push(@buts, [ "shut", $text{'index_shut'} ]) if ($access{'shut'});
	push(@buts, [ "reboot", $text{'index_reboot'} ]) if ($access{'reboot'});
	print &ui_form_end(\@buts);
	}
else {
	print "<b>",&text('index_none', "../servers/"),"</b><p>\n";
	}

if (@servers) {
	# Show email notification form
	print "<hr>\n";
	print &ui_form_start("save_sched.cgi", "post");
	print &ui_table_start($text{'index_header'}, undef, 2);

	$job = &find_cron_job();
	print &ui_table_row($text{'index_sched'},
			    &ui_yesno_radio("sched", $job ? 1 : 0));

	print &ui_table_row($text{'index_email'},
			    &ui_textbox("email", $config{'email'}, 40));

	print &ui_table_row($text{'index_smtp'},
		    &ui_opt_textbox("smtp", $config{'smtp'}, 30,
				    $text{'index_this'}));

	print &ui_table_end();
	print &ui_form_end([ [ "save", $text{'save'} ] ]);
	}

&ui_print_footer("/", $text{'index'});

