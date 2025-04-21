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

# Show a table of TLS keys
my @tls = &find("tls", $conf);
my @links = ( &ui_link("edit_tls.cgi?new=1", $text{'tls_add'}) );
if (@tls) {
	print &ui_links_row(\@links);
	print &ui_columns_start([ $text{'tls_name'},
				  $text{'tls_key'},
				  $text{'tls_cert'} ], 100);
	# XXX
	print &ui_columns_end();
	}
print &ui_links_row(\@links);
