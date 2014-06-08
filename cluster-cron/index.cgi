#!/usr/local/bin/perl
# index.cgi
# Show all cron jobs that run on multiple servers

require './cluster-cron-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit.cgi?new=1",$text{'index_add'}) );

@jobs = &list_cluster_jobs();
if (@jobs) {
	print &ui_form_start("delete_jobs.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $cron::text{'index_command'},
				  $cron::text{'index_user'},
				  $cron::text{'index_active'},
				  $text{'index_servers'},
				  $text{'index_actions'}, ],
				100, 0,
				[ "width=5" ]);
	foreach $j (@jobs) {
		local @cols;
		local $max = $cron::config{'max_len'} || 10000;
		local $cmd = $j->{'cluster_command'};
		push(@cols, 
		   sprintf &ui_link("edit.cgi?id=$j->{'cluster_id'}","%s")."%s",
			length($cmd) > $max ?
				&html_escape(substr($cmd, 0, $max)) :
			$cmd !~ /\S/ ? "BLANK" : &html_escape($cmd),
			length($cmd) > $max ? " ..." : "");
		push(@cols, "<tt>$j->{'cluster_user'}</tt>");
		push(@cols, 
			$j->{'active'} ? $text{'yes'}
				: "<font color=#ff0000>$text{'no'}</font>");
		local @servers = map {
			$_ eq "*" ? $text{'edit_this'} :
			$_ =~ /^group_(.*)$/ ? &text('edit_group', "$1") : $_
				} split(/\s+/, $j->{'cluster_server'});
		if (@servers > 3) {
			push(@cols, join(", ", @servers[0 .. 1]).", ".
			      &text('index_more', @servers-2));
			}
		else {
			push(@cols, join(", ", @servers));
			}
		push(@cols, &ui_link("exec.cgi?id=$j->{'cluster_id'}",$text{'index_run'}));
		print &ui_checked_columns_row(
			\@cols,
			[ "width=5", undef, undef, undef, undef, "width=10" ],
			"d", $j->{'cluster_id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $cron::text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("/", $text{'index'});

