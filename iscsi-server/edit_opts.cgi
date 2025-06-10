#!/usr/local/bin/perl
# Show a form for editing command-line options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-server-lib.pl';
our (%text, %config);

&ui_print_header(undef, $text{'opts_title'}, "");

my $opts = &get_iscsi_options();
print &ui_form_start("save_opts.cgi");
print &ui_table_start($text{'opts_header'}, undef, 2);

# IPv4 / 6 mode
print &ui_table_row($text{'opts_ip4'},
	&ui_yesno_radio("ip4", defined($opts->{'4'})));
print &ui_table_row($text{'opts_ip6'},
	&ui_yesno_radio("ip6", defined($opts->{'6'})));

# Hostname
print &ui_table_row($text{'opts_name'},
	&ui_opt_textbox("name", $opts->{'t'}, 30, $text{'opts_namedef'}));

# Port number
print &ui_table_row($text{'opts_port'},
	&ui_opt_textbox("port", $opts->{'p'}, 5, $text{'default'}." (3260)"));

# Max sessions
print &ui_table_row($text{'opts_sess'},
	&ui_opt_textbox("sess", $opts->{'s'}, 5, $text{'default'}));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
