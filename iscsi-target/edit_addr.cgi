#!/usr/local/bin/perl
# Show port and address options

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text);
my $opts = &get_iscsi_options();

&ui_print_header(undef, $text{'addr_title'}, "");

print &ui_form_start("save_addr.cgi", "post");
print &ui_table_start($text{'addr_header'}, undef, 2);

# Listen on address
my $addr = $opts->{'a'} || $opts->{'address'};
print &ui_table_row($text{'addr_addr'},
	&ui_opt_textbox("addr", $addr, 30,
			$text{'addr_any'}, $text{'addr_ip'}));

# Listen on port
my $port = $opts->{'p'} || $opts->{'port'};
print &ui_table_row($text{'addr_port'},
	&ui_opt_textbox("port", $port, 30, $text{'default'}." (3260)"));

# Debug level
my $debug = $opts->{'d'} || $opts->{'debug'};
print &ui_table_row($text{'addr_debug'},
	&ui_opt_textbox("debug", $debug, 5, $text{'addr_debugnone'}));


print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

