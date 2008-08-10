#!/usr/local/bin/perl
# Show hosts in BIND cluster

require './bind8-lib.pl';
$access{'slaves'} || &error($text{'slaves_ecannot'});
&foreign_require("servers", "servers-lib.pl");
&ReadParse();
&ui_print_header(undef, $text{'slaves_title'}, "");

# Show existing servers
@servers = &list_slave_servers();
if (@servers) {
	print &ui_form_start("slave_delete.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d") );
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	print &ui_columns_start([
		"",
		$text{'slaves_host'},
		$text{'slaves_dosec'},
		$text{'slaves_view'},
		$text{'slaves_desc'},
		$text{'slaves_os'} ], 100, 0, \@tds);
	foreach $s (@servers) {
		local @cols;
		push(@cols, $s->{'host'}.
			    ($s->{'nsname'} ? " ($s->{'nsname'})" : ""));
		push(@cols, $s->{'sec'} ? $text{'yes'} : $text{'no'});
		push(@cols, $s->{'bind8_view'} ||
			    "<i>$text{'slaves_noview'}</i>");
		push(@cols, $s->{'desc'});
		($type) = grep { $_->[0] eq $s->{'type'} }
			       @servers::server_types;
		push(@cols, $type->[1]);
		print &ui_checked_columns_row(\@cols, \@tds, "d", $s->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'slaves_delete'} ] ]);
	}
else {
	print "<b>$text{'slaves_none'}</b><p>\n";
	}

# Get all Webmin servers and groups
@allservers = grep { $_->{'user'} } &servers::list_servers();
%gothost = map { $_->{'id'}, 1 } @servers;
@addservers = grep { !$gothost{$_->{'id'}} } @allservers;
@groups = &servers::list_all_groups(\@allservers);

# Show form buttons to add, if any
if (@addservers || @groups) {
	print &ui_form_start("slave_add.cgi", "post");
	print &ui_table_start($text{'slaves_header'}, undef, 2);

	# Host or group to add
	@addservers = sort { $a->{'host'} cmp $b->{'host'} } @addservers;
	@opts = ( );
	if (@addservers) {
		# Add hosts not already in list
		foreach my $s (@addservers) {
			push(@opts, [ $s->{'id'},
				      $s->{'host'}.
				      ($s->{'desc'} ? " ($s->{'desc'})" : "")]);
			}
		}
	@groups = sort { $a->{'name'} cmp $b->{'name'} } @groups;
	if (@groups) {
		# Add groups
		foreach my $g (@groups) {
			push(@opts, [ "group_".$g->{'name'},
				      &text('slaves_group', $g->{'name'}) ]);
			}
		}
	print &ui_table_row($text{'slaves_add'},
		&ui_select("server", undef, \@opts));

	# Add to view
	print &ui_table_row($text{'slaves_toview'},
		&ui_radio("view_def", 1,
			  [ [ 1, $text{'slaves_noview2'}."<br>" ],
			    [ 2, $text{'slaves_sameview'}."<br>" ],
			    [ 0, $text{'slaves_inview'} ] ])." ".
		&ui_textbox("view", undef, 20));

	# Create secondary on slave?
	print &ui_table_row($text{'slaves_sec'},
		&ui_yesno_radio("sec", 0));

	# Create all existing masters?
	print &ui_table_row($text{'slaves_sync'},
		&ui_yesno_radio("sync", 0));

	# NS name
	print &ui_table_row($text{'slaves_name'},
		&ui_opt_textbox("name", undef, 30, $text{'slaves_same'}));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'slaves_ok'} ] ]);
	}
else {
	print "<b>",&text('slaves_need', '../servers/'),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

