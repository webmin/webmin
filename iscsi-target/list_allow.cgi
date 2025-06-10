#!/usr/local/bin/perl
# Display a list of targets and allowed IPs

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-target-lib.pl';
our (%text, %in);
&ReadParse();
my $allow = &get_allow_config($in{'mode'});

&ui_print_header(undef, $text{$in{'mode'}.'_title'}, "");

my @links = ( &ui_link("edit_allow.cgi?new=1&mode=$in{'mode'}",$text{'allow_add'}) );
if (@$allow) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_allows.cgi", "post");
	print &ui_hidden("mode", $in{'mode'});
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'allow_target'},
				  $text{$in{'mode'}.'_ips'},
				  $text{'allow_move'} ], 100, 0,
				[ "width=5", undef, undef, "width=32" ]);
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
			&ui_up_down_arrows(
			  "up_allow.cgi?mode=$in{'mode'}&idx=$a->{'index'}",
			  "down_allow.cgi?mode=$in{'mode'}&idx=$a->{'index'}",
			  $a ne $allow->[0],
			  $a ne $allow->[@$allow-1]
			  )
			], undef, "d", $a->{'index'});
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
