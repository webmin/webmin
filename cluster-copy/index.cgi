#!/usr/local/bin/perl
# Show all scheduled cluster copy jobs

require './cluster-copy-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   &ui_link("edit.cgi?new=1",$text{'index_add'}) );

# Get and sort jobs
@jobs = &list_copies();
if ($config{'sort_mode'} == 1) {
	# By filename
	@jobs = sort { $a->{'files'} cmp $b->{'files'} } @jobs;
	}
elsif ($config{'sort_mode'} == 2) {
	# By destination server
	@jobs = sort { $a->{'servers'} cmp $b->{'servers'} } @jobs;
	}

if (@jobs) {
	print &ui_form_start("delete.cgi", "post");
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'index_files'},
				  $text{'index_servers'},
				  $text{'index_sched'},
				  $text{'index_act'} ], "100", 0, \@tds);
	foreach $j (@jobs) {
		@servers = map {
			$_ eq "*" ? $text{'edit_this'} :
			$_ =~ /^group_(.*)$/ ? &text('edit_group', "$1") : $_
				} split(/\s+/, $j->{'servers'});
		if (@servers > 3) {
			$servers = join(", ", @servers[0 .. 1]).", ".
                              &text('index_more', @servers-2);
			}
		else {
			$servers = join(", ", @servers);
			}
		@files = split(/\t+/, $j->{'files'});
		if (@files > 3) {
			$files = join(", ", @files[0 .. 1]).", ".
                              &text('index_more', @files-2);
			}
		else {
			$files = join(", ", @files);
			}
		print &ui_checked_columns_row(
			[ &ui_link("edit.cgi?id=$j->{'id'}",$files),
			  $servers,
			  $j->{'sched'} ?
				&text('index_when', &cron::when_text($j)) :
				$text{'no'},
			  &ui_link("exec.cgi?id=$j->{'id'}",$text{'index_exec'}),
			], \@tds, "d", $j->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("/", $text{'index'});

