#!/usr/local/bin/perl
# view_form.cgi
# Display options for creating a new view
use strict;
use warnings;
our (%access, %text);

require './bind8-lib.pl';
&ReadParse();
my $conf = &get_config();
$access{'views'} == 1 || &error($text{'vcreate_ecannot'});
$access{'ro'} && &error($text{'vcreate_ecannot'});

&ui_print_header(undef, $text{'vcreate_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Form header
print &ui_form_start("create_view.cgi", "post");
print &ui_table_start($text{'view_opts'}, "width=100%", 4);

# View name
print &ui_table_row($text{'view_name'},
	&ui_textbox("name", undef, 25));

# Custom class
print &ui_table_row($text{'view_class'},
	&ui_opt_textbox("class", undef, 4, "$text{'default'} (<tt>IN</tt>)"));

# Clients to match
print &ui_table_row($text{'view_match'},
	&ui_radio("match_def", 0, [ [ 1, $text{'vcreate_match_all'} ],
				    [ 0, $text{'vcreate_match_sel'} ] ])."<br>".
	&ui_textarea("match", undef, 5, 40));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

