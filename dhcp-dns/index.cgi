#!/usr/local/bin/perl
# Show a list of clients, and a form to add

require './dhcp-dns-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", undef, 1, 1);
&ReadParse();

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
($fn, $recs) = &get_dns_zone();
if (!$fn) {
	&ui_print_endpage(&text('index_edomain2', "../config.cgi?$module_name",
				'../bind8/'));
	}

# Show form to add
print &ui_hidden_start($text{'index_cheader'}, "create", 0, "index.cgi");
print &host_form();
print &ui_hidden_end();

# Show hosts, if any
@hosts = &list_dhcp_hosts();
if (@hosts) {
	# Show search form
	print &ui_form_start("index.cgi");
	print $text{'index_search'}," ",
	      &ui_textbox("search", $in{'search'}, 40)," ",
	      &ui_submit($text{'index_ok'}),"<p>\n",
	      &ui_form_end();
	if ($in{'search'}) {
		$s = $in{'search'};
		@hosts = grep {
		    $fixed = &dhcpd::find("fixed-address", $_->{'members'});
		    $hard = &dhcpd::find("hardware", $_->{'members'});
		    $_->{'values'}->[0] =~ /\Q$s\E/i ||
		     $fixed->{'values'}->[0] =~ /\Q$s\E/i ||
		     $hard->{'values'}->[1] =~ /\Q$s\E/i } @hosts;
		}
	}

if (@hosts) {
	@tds = ( "width=5" );
	print &ui_form_start("delete.cgi");
	@links = ( &select_invert_link("d", 1) );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
			 	  $text{'index_host'},
			 	  $text{'index_subnet'},
			 	  $text{'index_ip'},
			 	  $text{'index_mac'},
			 	  $text{'index_desc'},
				], 100, 0, \@tds);
	foreach $h (sort { lc($a->{'values'}->[0]) cmp
			   lc($b->{'values'}->[0]) } @hosts) {
		$fixed = &dhcpd::find("fixed-address", $h->{'members'});
		$hard = &dhcpd::find("hardware", $h->{'members'});
		my $parentdesc;
		my $par = $h->{'parent'};
		if ($par) {
			if ($par->{'name'} eq 'subnet') {
				$parentdesc = $par->{'values'}->[0];
				}
			elsif ($par->{'name'} eq 'group') {
				$parentdesc = $par->{'comment'} || 'Group';
				}
			elsif ($par->{'name'} eq 'shared-network') {
				$parentdesc = $par->{'values'}->[0];
				}
			}
		print &ui_checked_columns_row([
			"<a href='edit.cgi?host=".&urlize($h->{'values'}->[0]).
			  "'>".
			  &html_escape(&short_hostname($h->{'values'}->[0])).
			  "</a>",
			$parentdesc,
			$fixed ? $fixed->{'values'}->[0] : undef,
			$hard ? $hard->{'values'}->[1] : undef,
			&html_escape($h->{'comment'}),
			], \@tds, "d", $h->{'values'}->[0])
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'index_delete'} ] ]);
	}
elsif ($in{'search'}) {
	# Nothing matched search
	print "<b>$text{'index_none2'}</b><p>\n";
	}
else {
	# Really none
	print "<b>$text{'index_none'}</b><p>\n";
	}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("apply.cgi", $text{'index_apply'},
		      $text{'index_applydesc'});
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

