#!/usr/local/bin/perl
# Show a list of all defined actions

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text, %config);

&ui_print_header(undef, $text{'status_title2'}, "");

# Check if firewalld is used
&foreign_require('firewalld', 'install_check.pl');
my $is_firewalld = &firewalld::is_installed();

my $out = &backquote_logged("$config{'client_cmd'} status 2>&1 </dev/null");
my ($jail_list) = $out =~ /jail\s+list:\s*(.*)/im;
my @jails = split(/,\s*/, $jail_list);
if (@jails) {
	my $tdc = "style=\"text-align: center\"";
	my @links = ( &select_all_link("jail"),
	              &select_invert_link("jail") );
	my $head;
	my @jipsall;
	foreach my $jail (@jails) {
		my $fh = 'cmdjail';
		my $cmd = "$config{'client_cmd'} status ".quotemeta($jail);
		my $jcmd = "$cmd 2>&1 </dev/null";
		my @head = (undef, $text{"status_head_jail_name"});
		my @body = (&ui_link("edit_jail.cgi?name=".urlize($jail), "&nbsp;".&html_escape($jail)));
		my $jips;
		my $noval;
		&open_execute_command($fh, $jcmd, 1);
		while(<$fh>) {
			if (/-\s+(.*):\s*(.*)/) {
				my $col = $1;
				my $val = $2;
				$col = lc($col);
				$col =~ s/\s/_/g;
				if ($col !~ /journal_matches/) {
					push(@head, "<div $tdc>".$text{"status_head_$col"}."</div>");
					if ($col =~ /banned_ip_list/) {
						$jips = $val;
						my @ips = split(/\s+/, $val);
						@ips = map { "<label style=\"white-space: nowrap\">" .
							&ui_link("unblock_jail.cgi?unblock=1&jips-@{[&urlize($jail)]}=@{[&urlize($_)]}&jail=@{[&urlize($jail)]}", $_, undef,
							         "title=\"@{[&text('status_jail_unblock_ip', &quote_escape($_))]}\" onmouseover=\"this.style.textDecoration='line-through'\" onmouseout=\"this.style.textDecoration='none'\""
							        ) . 
							($is_firewalld ? "&nbsp; &nbsp; " .
							&ui_link("unblock_jail.cgi?permblock=1&jips-@{[&urlize($jail)]}=@{[&urlize($_)]}&jail=@{[&urlize($jail)]}", "&empty;", undef,
							         "title=\"@{[&text('status_jail_permblock_ip', &quote_escape($_))]}\" onmouseover=\"this.style.opacity='1';this.style.filter='grayscale(0)'\" onmouseout=\"this.style.opacity='0.25';this.style.filter='grayscale(100%)'\" style=\"font-size: 125%; margin-right:10px; filter: grayscale(100%); opacity: .25\""
							        ) : undef) . "</label>" } @ips;
						$val = "<br>" if ($val);
						$val .= join('<br>', @ips);
						$val .= "<br><br>" if ($val);
						$val .= "&ndash;", $noval++ if (!$val);
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
		print &ui_checked_columns_row(\@body, [ 'width=5', undef, $tdc, $tdc, $tdc, $tdc, $noval ? $tdc : undef ], "jail", $jail);
		push(@jipsall, ["$jail" => $jips]);
	}
	if ($head) {
		print &ui_columns_end();
		print &ui_links_row(\@links);
		foreach my $j (@jipsall) {
			print &ui_hidden("jips-$j->[0]", "$j->[1]");
		}
		print &ui_form_end([ [ 'unblock', $text{'status_jail_unblock'} ],
		                     $is_firewalld ?
		                       [ 'permblock', $text{'status_jail_block'} ] : undef ]);
		}
}
else {
	print $text{'status_jail_noactive'};
	}

&ui_print_footer("", $text{'index_return'});
