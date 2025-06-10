#!/usr/local/bin/perl
# list_secrets.cgi
# Displays a list of all PAP secrets

require './pap-lib.pl';
$access{'secrets'} || &error($text{'secrets_ecannot'});
&ui_print_header(undef, $text{'secrets_title'}, "");

if (!-r $config{'pap_file'}) {
	print "<b>", &text('index_enopfile', $config{'pap_file'}), "</b>.<p>\n";
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	  "<a href=edit_secret.cgi>$text{'index_create'}</a>" );

# Show table of users
@sec = &list_secrets();
@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	   "<a href=edit_secret.cgi>$text{'index_create'}</a>" );
if (@sec) {
	print &ui_form_start("delete_secrets.cgi", "post");
	@tds = ( "width=5" );
	print &ui_links_row(\@links);
	print &ui_columns_start(
		[ "", $text{'index_user'}, $text{'index_server'} ],
		undef, 0, \@tds);
	for($i=0; $i<@sec; $i++) {
		$s = $sec[$i];
		local @cols;
		push(@cols, "<a href=\"edit_secret.cgi?$i\">".
			($s->{'client'} ? &html_escape($s->{'client'})
				        : $text{'index_uany'})."</a>");
		push(@cols, $s->{'server'} eq "*" ? $text{'index_sany'}
					      : &html_escape($s->{'server'}));
		print &ui_checked_columns_row(\@cols, \@tds, "d", $i);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'secrets_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

if ($access{'sync'}) {
	print &ui_hr(), $text{'index_info'}, " <p>\n";

	print "<form action=save_sync.cgi>\n";
	printf "<input type=checkbox name=add value=1 %s>\n",
		$config{'sync_add'} ? "checked" : "";
	print $text{'index_onadd'}, "\n";
	print "<input name=server size=20 value='$config{'sync_server'}'><p>\n";

	printf "<input type=checkbox name=change value=1 %s>\n",
		$config{'sync_change'} ? "checked" : "";
	print $text{'index_onchange'}, "<p>\n";

	printf "<input type=checkbox name=delete value=1 %s>\n",
		$config{'sync_delete'} ? "checked" : "";
	print $text{'index_ondelete'}, "<p>\n";
	print "<input type=submit value=", $text{'save'}, "></form>\n";
	}

&ui_print_footer("", $text{'index_return'});

