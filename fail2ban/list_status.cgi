#!/usr/local/bin/perl
# Show a list of all defined actions

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);

&ui_print_header(undef, $text{'status_title2'}, "");

my $out = &backquote_logged("$config{'client_cmd'} status 2>&1 </dev/null");
my ($jail_list) = $out =~ /jail\s+list:\s*(.*)/im;
my @jails = split(/,\s*/, $jail_list);
if (@jails) {
	my $tdc = "style=\"text-align: center\"";
	my @links = ( &select_all_link("jail"),
	              &select_invert_link("jail") );
	my $head;
	foreach my $jail (@jails) {
		my $fh = 'cmdjail';
		my $cmd = "$config{'client_cmd'} status ".quotemeta($jail);
		my $jcmd = "$cmd 2>&1 </dev/null";
		my @head = (undef, $text{"status_head_jail_name"});
		my @body = (&ui_link("edit_jail.cgi?name=".urlize($jail), "&nbsp;<tt>".&html_escape($jail)."</tt>"));
		&open_execute_command($fh, $jcmd, 1);
		while(<$fh>) {
			if (/-\s+(.*):\s*(.*)/) {
				my $col = $1;
				my $val = $2;
				$col = lc($col);
				$col =~ s/\s/_/g;
				if ($col !~ /journal_matches/) {
					push(@head, $text{"status_head_$col"});
					if ($col =~ /banned_ip_list/) {
						my @ips = split(/\s+/, $val);
						$val =~ s/\s+/<br>/g;
						}
					push(@body, $val);
					}
				}
			}
		close($fh);
		if (!$head++) {
			print &ui_form_start("unblock_jail.cgi", "post");
			print &ui_links_row(\@links);
			print &ui_columns_start(\@head);
			}
		print &ui_checked_columns_row(\@body, ['width=5', undef, $tdc, $tdc, $tdc, $tdc], "jail", $jail);
	}
	if ($head) {
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ 'unblock', $text{'status_jail_unblock'} ],
		                     [ 'permblock', $text{'status_jail_block'} ] ]);
	};
}
else {
	print $text{'status_jail_noactive'};
	}

&ui_print_footer("", $text{'index_return'});
