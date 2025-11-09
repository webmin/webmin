#!/usr/local/bin/perl
# Show all registered TLS keys

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'tls_ecannot'});
&supports_tls() || &error($text{'tls_esupport'});
my $conf = &get_config();

&ui_print_header(undef, $text{'tls_title'}, "");

print $text{'tls_desc'},"<p>\n";

# Show a table of TLS keys
my @tls = &find("tls", $conf);
my @links = ( &ui_link("edit_tls.cgi?new=1", $text{'tls_add'}) );
if (@tls) {
	print &ui_links_row(\@links);
	print &ui_columns_start([ $text{'tls_name'},
				  $text{'tls_key'},
				  $text{'tls_cert'} ], 100);
	foreach my $tls (@tls) {
		my $mems = $tls->{'members'};
		print &ui_columns_row([
			&ui_link("edit_tls.cgi?name=".
				 &urlize($tls->{'values'}->[0]),
				 $tls->{'values'}->[0]),
			&html_escape(&find_value("key-file", $mems)),
			&html_escape(&find_value("cert-file", $mems)),
			]);
		}
	print &ui_columns_end();
	}
else {
	print &ui_alert_box($text{'tls_none'}, 'info', undef, undef, "");
	}
print &ui_links_row(\@links);

&ui_print_footer("", $text{'index_return'});
