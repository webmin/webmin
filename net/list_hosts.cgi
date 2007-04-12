#!/usr/local/bin/perl
# list_hosts.cgi
# List hosts from /etc/hosts

require './net-lib.pl';
$access{'hosts'} || &error($text{'hosts_ecannot'});
&ui_print_header(undef, $text{'hosts_title'}, "");

if ($access{'hosts'} == 2) {
	print &ui_form_start("delete_hosts.cgi", "post");
	@links = ( &select_all_link("d"),
		   &select_invert_link("d"),
		   "<a href=\"edit_host.cgi?new=1\">$text{'hosts_add'}</a>" );
	print &ui_links_row(\@links);
	@tds = ( "width=5" );
	}
print &ui_columns_start([ $access{'hosts'} == 2 ? ( "" ) : ( ),
			  $text{'hosts_ip'},
			  $text{'hosts_host'} ], undef, 0, \@tds);
foreach $h (&list_hosts()) {
	local @cols;
	if ($access{'hosts'} == 2) {
		push(@cols, "<a href=\"edit_host.cgi?idx=$h->{'index'}\">".
			    &html_escape($h->{'address'})."</a>");
		}
	else {
		push(@cols, &html_escape($h->{'address'}));
		}
	push(@cols, join(" , ", map { &html_escape($_) }
				    @{$h->{'hosts'}}));
	if ($access{'hosts'} == 2) {
		print &ui_checked_columns_row(\@cols, \@tds, "d",$h->{'index'});
		}
	else {
		print &ui_columns_row(\@cols);
		}
	}
print &ui_columns_end();
if ($access{'hosts'} == 2) {
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'hosts_delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

