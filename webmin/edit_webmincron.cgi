#!/usr/local/bin/perl
# Show a list of Webmin cron jobs

require './webmin-lib.pl';
&ui_print_header(undef, $text{'webmincron_title'}, "");

if (!&foreign_check("webmincron")) {
	&ui_print_endpage($text{'webmincron_emodule'});
	}
&foreign_require("webmincron");
&foreign_require("cron");
my @wcrons = &webmincron::list_webmin_crons();
@wcrons = sort { $a->{'module'} cmp $b->{'module'} ||
		 $a->{'func'} cmp $b->{'func'} ||
		 join(" ", @{$a->{'args'}}) cmp join(" ", @{$b->{'args'}}) }
	       @wcrons;
if (@wcrons) {
	my @tds = ( "width=5 valign=top", "valign=top", "valign=top", "valign=top" );
	print &ui_form_start("delete_webmincron.cgi");
	print &ui_columns_start([ "",
				  $text{'webmincron_module'},
				  $text{'webmincron_func'},
				  $text{'webmincron_args'},
				  $text{'webmincron_when'},
				],
				100, 0, \@tds);
	foreach my $w (@wcrons) {
		my %minfo = &get_module_info($w->{'module'});
		print &ui_checked_columns_row([
			&ui_link("view_webmincron.cgi?id=".$w->{'id'},
			  ($minfo{'desc'} || $w->{'module'}) ),
			$w->{'func'},
			join(" ", @{$w->{'args'}}),
			&cron::when_text($w, 1),
			], \@tds, "d", $w->{'id'});
		}
	print &ui_columns_end();
	print &ui_form_end([ [ "delete", $text{'webmincron_delete'} ],
			     [ "run", $text{'webmincron_run'} ] ]);
	}
else {
	print "<b>$text{'webmincron_none'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

