#!/usr/local/bin/perl
# index.cgi

require './dfs-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("dfstab share", "man"));

@shlist = &list_shares();
if (@shlist && $access{'icons'}) {
	# Display shares as icons
	print "<a href=\"edit_share.cgi\">$text{'index_add'}</a><br>\n";
	foreach $s (@shlist) {
		next if ($s->{'type'} ne 'nfs');
		push(@icons, "images/share.gif");
		push(@titles, $s->{'dir'});
		push(@links, "edit_share.cgi?$s->{'index'}");
		}
	&icons_table(\@links, \@titles, \@icons);
	if (!$access{'view'}) {
		print "<a href=\"edit_share.cgi\">$text{'index_add'}</a><br>\n";
		}
	}
elsif (@shlist) {
	# Display shares as table
	if (!$access{'view'}) {
		print &ui_form_start("delete_shares.cgi", "post");
		print &select_all_link("d"),"\n";
		print &select_invert_link("d"),"\n";
		print "<a href=\"edit_share.cgi\">$text{'index_add'}</a><br>\n";
		@tds = ( "width=5" );
		}
	print &ui_columns_start([
		$access{'view'} ? ( ) : ( "" ),
		$text{'index_dir'},
		$text{'index_clients'} ], 100, 0, \@tds);
	foreach $s (@shlist) {
		next if ($s->{'type'} ne 'nfs');
		&parse_options($s->{'opts'});
		local @cols;
		if ($access{'view'}) {
			push(@cols, &html_escape($s->{'dir'}));
			}
		elsif (defined($options{'public'})) {
			push(@cols, "<a href=\"edit_share.cgi?$s->{'index'}\">".
				    &html_escape($s->{'dir'})."</a>");
			}
		else {
			push(@cols, "<a href=\"edit_share.cgi?$s->{'index'}\">".				    &html_escape($s->{'dir'})."</a>");
			}
		undef(%clients);
		foreach (split(/:/, $options{"ro"})) { $clients{$_}++; }
		foreach (split(/:/, $options{"rw"})) { $clients{$_}++; }
		foreach (split(/:/, $options{"root"})) { $clients{$_}++; }
		if (%clients) {
			$clients = join(' &nbsp;|&nbsp; ' , sort { $a cmp $b }
			    map { &html_escape($_ =~ /^\@(.*)/ ? "$1.*" : $_) }
				     (keys %clients) );
			if (length($clients) > 80) {
				$clients = substr($clients, 0, 80)."...";
				}
			}
		else {
			$clients = $text{'index_everyone'};
			}
		push(@cols, $clients);
		if ($access{'view'}) {
			print &ui_columns_row(\@cols, \@tds);
			}
		else {
			print &ui_checked_columns_row(\@cols, \@tds, "d",
						      $s->{'index'});
			}
		}
	print &ui_columns_end();
	if (!$access{'view'}) {
		print &select_all_link("d"),"\n";
		print &select_invert_link("d"),"\n";
		print "<a href=\"edit_share.cgi\">$text{'index_add'}</a><br>\n";
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		}
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print "<a href=\"edit_share.cgi\">$text{'index_add'}</a><p>\n";
	}

if (!$access{'view'}) {
	print &ui_hr();
	print &ui_buttons_start();
	print &ui_buttons_row("restart_sharing.cgi",
			      $text{'index_apply'},
			      $text{'index_applydesc'});
	print &ui_buttons_end();
	}

&ui_print_footer("/", "index");

