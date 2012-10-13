#!/usr/local/bin/perl
# Display a list of targets and allowed IPs

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
my $allow = &get_allow_config($in{'mode'});

&ui_print_header(undef, $text{$in{'mode'}.'_title'}, "");

my @links = ( "<a href='edit_allow.cgi?new=1&mode=$in{'mode'}'>".
	      $text{'allow_add'}."</a>" );
if (@$allow) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_allows.cgi", "post");
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'allow_target'},
				  $text{$in{'mode'}.'_ips'} ], 100, 0,
				[ "width=5" ]);
	foreach my $a (@$allow) {
		my @addrs = @{$a->{'addrs'}};
		if (@addrs > 5) {
			@addrs = ( @addrs[0..4], "..." );
			}
		my $name = $a->{'name'} eq 'ALL' ? "<i>$text{'allow_all1'}</i>"
						 : $a->{'name'};
		print &ui_checked_columns_row([
			"<a href='edit_allow.cgi?idx=$a->{'index'}&".
			  "mode=$in{'mode'}'>$name</a>",
			$addrs[0] eq 'ALL' ? "<i>$text{'allow_all2'}</i>"
					   : join(" , ", @addrs),
			]);
		}
	print &ui_table_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'allow_delete'} ] ]);
	}
else {
	print "<b>",$text{$in{'mode'}.'_none'},"</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
