#!/usr/local/bin/perl
# Show a list of clients, and a form to add

require './dhcp-dns-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);

# Check for servers
if (!&foreign_installed("bind8", 1)) {
	&ui_print_endpage(&text('index_ebind8', "../bind8/"));
	}
if (!&foreign_installed("dhcpd", 1)) {
	&ui_print_endpage(&text('index_edhcpd', "../dhcpd/"));
	}

# Check config
if (!$config{'domain'}) {
	&ui_print_endpage(&text('index_edomain', "../config.cgi?$module_name"));
	}
if (!$config{'subnets'}) {
	&ui_print_endpage(&text('index_esubnets',"../config.cgi?$module_name"));
	}

# Show form to add
print &ui_hidden_start($text{'index_cheader'}, "create", 0, "index.cgi");
print &host_form();
print &ui_hidden_end();

# Show hosts, if any
@hosts = &list_dhcp_hosts();
@links = ( "<a href='edit.cgi?new=1'>$text{'index_add'}</a>" );
if (@hosts) {
	@tds = ( "width=5" );
	print &ui_form_start("delete.cgi");
	@links = ( &select_all_link("d", 1),
		   &select_invert_link("d", 1),
		   @links );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
			 	  $text{'index_host'},
			 	  $text{'index_ip'},
			 	  $text{'index_mac'},
				], 100, 0, \@tds);
	foreach $h (@hosts) {
		$fixed = &dhcpd::find("fixed-address", $h->{'members'});
		$hard = &dhcpd::find("hardware", $h->{'members'});
		print &ui_checked_columns_row([
			&html_escape(&short_hostname($h->{'values'}->[0])),
			$fixed ? $fixed->{'values'}->[0] : undef,
			$hard ? $hard->{'values'}->[0] : undef,
			], \@tds, "d", $h->{'values'}->[0])
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("/", $text{'index'});

