#!/usr/local/bin/perl
# Show a status of all active jails

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './fail2ban-lib.pl';
our (%in, %text, %config);

&ui_print_header(undef, $text{'status_title'}, "");

my $out = &backquote_logged("$config{'client_cmd'} status 2>&1 </dev/null");
my ($jail_list) = $out =~ /jail\s+list:\s*(.*)/im;
my @jails = split(/,\s*/, $jail_list);
if (@jails) {
	my $tdc = 'style="text-align: center;"';
	my $tal = 'style="text-align: right; font-size: 96%;"';
	my $lwf = 'style="width: 100%; padding-right: 4px;"';
	my @links = ( &select_all_link("jail"),
	              &select_invert_link("jail") );
	my $head;
	my @jipsall;
	foreach my $jail (@jails) {
		my $fh = 'cmdjail';
		my $cmd = "$config{'client_cmd'} status ".quotemeta($jail);
		my $jcmd = "$cmd 2>&1 </dev/null";
		my @head = (undef, $text{"status_head_jail_blocks"});
		my @body = &ui_link("jail_blocks.cgi?jail=".urlize($jail), "&nbsp;".&html_escape($jail), undef);
		my $br = '<br>';
		my $nbsp = '&nbsp;';
		my $ipslimit = sub {
			my ($ips, $limit) = @_;
			$limit ||= 10;
			# Limit sanity check
			$limit = 1 if ($limit < 1);
			my $ipscount = () = $ips =~ /$br/g;
			if ($ipscount > $limit) {
				my @ips = split($br, $ips);
				@ips = @ips[0 .. $limit];
				$ips = join($br, @ips);
				$ips .= "<small style='cursor: default;'>$br".
					(&ui_link("jail_blocks.cgi?jail=".urlize($jail),
						"&nbsp;".&text('status_rules_plus_more', $ipscount-$limit), undef))."</small>";
				}
			return $ips;
		};
		my $jips;
		&open_execute_command($fh, $jcmd, 1);
		while(<$fh>) {
			if (/-\s+(.*?):\s*(.*)/) {
				my $col = $1;
				my $val = $2;
				$col = lc($col);
				$col =~ s/\s/_/g;
				if ($col !~ /journal_matches/ &&
				    $col !~ /file_list/) {
					push(@head, "<span $tdc>".$text{"status_head_$col"}."</span>");
					if ($col =~ /banned_ip_list/) {
						$jips = $val;
						my @ips = split(/\s+/, $val);
						@ips = map { "<small $tal><tt><label $lwf>" . &ui_link("unblock_jailed_ip.cgi?ip=@{[&urlize($_)]}&jail=@{[&urlize($jail)]}", $_, undef,
							         "title=\"@{[&text('status_jail_unblock_ip', &quote_escape($_))]}\" onmouseover=\"this.style.textDecoration='line-through'\" onmouseout=\"this.style.textDecoration='none'\""
							        ) . "</label></tt></small>" } @ips;
						$val = "<br>" if ($val);
						$val .= join('<br>', @ips);
						$val = &$ipslimit($val);
						$val .= "<br><br>" if ($val);
						$val .= "&ndash;" if (!$val);
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
		print &ui_checked_columns_row(\@body, [ 'width=5', undef, $tdc, $tdc, $tdc, $tdc, $tdc ], "jail", $jail);
		push(@jipsall, ["$jail" => $jips]);
	}
	if ($head) {
		print &ui_columns_end();
		print &ui_links_row(\@links);
		print &ui_form_end([ [ 'unblock', $text{'status_jail_unblock'} ] ]);
		}
}
else {
	print $text{'status_jail_noactive'};
	}

&ui_print_footer("", $text{'index_return'});
