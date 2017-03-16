#!/usr/local/bin/perl
# Show details of one Webmin cron function, and allow changing

require './webmin-lib.pl';
&ReadParse();

if (!&foreign_check("webmincron")) {
	&ui_print_endpage($text{'webmincron_emodule'});
	}
&foreign_require("webmincron");
my @wcrons = &webmincron::list_webmin_crons();
my ($wcron) = grep { $_->{'id'} eq $in{'id'} } @wcrons;
$wcron || &error($text{'webmincron_egone'});

&ui_print_header(undef, $text{'webmincron_title'}, "");

print &ui_form_start("save_webmincron.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'webmincron_header'}, undef, 2);

# Run from module
%minfo = &get_module_info($wcron->{'module'});
print &ui_table_row($text{'webmincron_module'},
	$minfo{'desc'} || $wcron->{'module'}, undef, [ "valign=middle","valign=middle" ]);

# Function to call
print &ui_table_row($text{'webmincron_func'},
	"<tt>$wcron->{'func'}</tt>", undef, [ "valign=middle","valign=middle" ]);

# Function params, if any
if (@{$wcron->{'args'}}) {
	print &ui_table_row($text{'webmincron_args'},
		join("<br>\n", map { "<tt>".&html_escape($_)."</tt>" }
				   @{$wcron->{'args'}}), undef, [ "valign=middle","valign=middle" ]);
	}

# Run-time (editable)
print &ui_table_row($text{'webmincron_when'},
	&ui_radio_table("whenmode", $wcron->{'interval'} ? 0 : 1,
			[ [ 0, $text{'webmincron_when0'},
			    &ui_textbox("interval", $wcron->{'interval'}, 5)." ".
			    $text{'webmincron_secs'} ],
			  [ 1, $text{'webmincron_when1'},
			    &webmincron::show_times_input($wcron) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'delete', $text{'delete'} ] ]);

&ui_print_footer("edit_webmincron.cgi", $text{'webmincron_return'});
