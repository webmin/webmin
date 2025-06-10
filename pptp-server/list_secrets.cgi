#!/usr/local/bin/perl
# list_secrets.cgi
# Displays a list of all PAP secrets

require './pptp-server-lib.pl';
$access{'secrets'} || &error($text{'secrets_ecannot'});
&ui_print_header(undef, $text{'secrets_title'}, "", "secrets");

if (!-r $config{'pap_file'}) {
	print "<p>", &text('secrets_enopfile', $config{'pap_file'},
			   "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'secrets_return'});
	exit;
	}

@links = ( &select_all_link("d"),
	   &select_invert_link("d"),
	  "<a href=edit_secret.cgi>$text{'secrets_create'}</a>" );

# Get the system's hostname for selecting PPP accounts
$host = &get_ppp_hostname();

print &text('secrets_desc', "<tt>$config{'pap_file'}</tt>", "<tt>$host</tt>",
	   $config{'pap_file'} =~ /pap-secrets/ ? "PAP" : "CHAP"),"<p>\n";

@sec = grep { $_->{'server'} eq $host } &list_secrets();
if (@sec) {
	print &ui_form_start("delete_secrets.cgi", "post");
	@tds = ( "width=5", "nowrap", "nowrap" );
	print &ui_links_row(\@links);
	print &ui_columns_start(
		[ "", $text{'secrets_user'}, $text{'secrets_ips'} ],
		undef, 0, \@tds);
	for($i=0; $i<@sec; $i++) {
		$s = $sec[$i];
		local @cols;
		push(@cols, "<a href=\"edit_secret.cgi?$i\">".
			($s->{'client'} ? &html_escape($s->{'client'})
				        : $text{'index_uany'})."</a>");
		@i = @{$s->{'ips'}};
		push(@cols, $i[0] eq "*" || $i[0] eq "" ?
				$text{'edit_secret_aany'} :
			    $i[0] eq "-" ? $text{'edit_secret_anone'} :
				html_escape(join(" ", @i)));
		print &ui_checked_columns_row(\@cols, \@tds, "d", $i);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'secrets_delete'} ] ]);
	}
else {
	print "<b>$text{'secrets_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

&ui_print_footer("", $text{'secrets_return'});

