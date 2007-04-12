#!/usr/local/bin/perl
# list_conns.cgi
# List all active connections

require './pptp-server-lib.pl';
$access{'conns'} || &error($text{'conns_ecannot'});
&ui_print_header(undef, $text{'conns_title'}, "", "conns");

@conns = &list_connections();
if (@conns) {
	print "$text{'conns_desc'}<p>\n";
	print &ui_columns_start([ $text{'conns_iface'},
				  $text{'conns_client'},
				  $text{'conns_stime'},
				  $text{'conns_local'},
				  $text{'conns_remote'},
				  $text{'conns_user'} ]);
	foreach $c (@conns) {
		local @cols;
		push(@cols, "<a href='disc.cgi?pid=$c->[0]'>".
			    ($c->[3] ? "<tt>$c->[3]</tt>"
				     : $text{'conns_unknown'})."</a>");
		push(@cols, $c->[2]);
		push(@cols, $c->[6] || $text{'conns_unknown'});
		push(@cols, $c->[4] ? "<tt>$c->[4]</tt>"
				     : $text{'conns_unknown'});
		push(@cols, $c->[5] ? "<tt>$c->[5]</tt>"
				     : $text{'conns_unknown'});
		push(@cols, $c->[7] ? "<tt>$c->[7]</tt>"
				     : $text{'conns_unknown'});
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'conns_none'}</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

