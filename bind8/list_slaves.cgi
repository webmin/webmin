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

# Show buttons to add
@allservers = grep { $_->{'user'} } &servers::list_servers();
if (@allservers) {
	print "<form action=slave_add.cgi>\n";
	print "<table width=100%><tr>\n";
	%gothost = map { $_->{'id'}, 1 } @servers;
	@addservers = grep { !$gothost{$_->{'id'}} } @allservers;
	@addservers = sort { $a->{'host'} cmp $b->{'host'} } @addservers;
	if (@addservers) {
		print "<td>";
		print &ui_submit($text{'slaves_add'}, "add");
		print &ui_select("server", undef,
			[ map { [ $_->{'id'},
				  $_->{'host'}.($_->{'desc'} ? " ($_->{'desc'})"
							     : "") ] }
			      @addservers ]);
		print "</td>\n";
		}
	@groups = &servers::list_all_groups(\@allservers);
	@groups = sort { $a->{'name'} cmp $b->{'name'} } @groups;
	if (@groups) {
		print "<td align=right>\n";
		print &ui_submit($text{'slaves_gadd'}, "gadd");
		print &ui_select("group", undef,
			[ map { $_->{'name'} } @groups ]);
		print "</td>\n";
		}
	print "</tr></table>\n";

	if (@addservers || @groups) {
		# Show inputs for view and existing create
		print "<table><tr>\n";
		print "<tr> <td><b>$text{'slaves_toview'}</b></td>\n";
		print "<td>",&ui_opt_textbox("view", undef, 30,
			$text{'slaves_noview2'}, $text{'slaves_inview'}),
			"</td> </tr>\n";

		print "<tr> <td><b>$text{'slaves_sec'}</b></td>\n";
		print "<td>",&ui_yesno_radio("sec", 0),"</td> </tr>\n";

		print "<tr> <td><b>$text{'slaves_sync'}</b></td>\n";
		print "<td>",&ui_yesno_radio("sync", 0),"</td> </tr>\n";

		print "<tr> <td><b>$text{'slaves_name'}</b></td>\n";
		print "<td>",&ui_opt_textbox("name", undef, 30,
				$text{'slaves_same'}),"</td> </tr>\n";

		print "</table>\n";
		}
	print "</form>\n";
	}
else {
	print "<b>",&text('slaves_need', '../servers/'),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

