#!/usr/local/bin/perl
# Show one existing host

require './dhcp-dns-lib.pl';
&ReadParse();
($host) = grep { $_->{'values'}->[0] eq $in{'host'} } &list_dhcp_hosts();
$host || &error($text{'edit_egone'});

&ui_print_header(undef, $text{'edit_title'}, "");
print &host_form($host);
&ui_print_footer("", $text{'index_return'});


