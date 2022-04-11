#!/usr/local/bin/perl
# List FirewallD rich rules

use strict;
use warnings;
require './firewalld-lib.pl';
our (%in, %text, %config);

my $dzone = &get_default_zone();
&ui_print_header(&text('richrules_title_sub', "<tt>".&html_escape($dzone->{'name'})."</tt>"), $text{'richrules_title'}, "");

my $head;
my @head = (undef, "Type");
my $tdc = "style=\"text-align: center\"";
my @links = ( &select_all_link("rules"),
              &select_invert_link("rules") );

# Check rich rules first
my $fh = 'rrules';
my $rcmd = "$config{'firewall_cmd'} --list-rich-rules --zone=$dzone->{'name'}";
&open_execute_command($fh, "$rcmd 2>&1 </dev/null", 1);
while(<$fh>) {
	my @body;
	if ($_ =~ /\S+/) {
		push(@body, 'Rich');

		# Get protocol
		if (/family=["'](ipv\d)["']/) {
			push(@head, "Protocol");
			push(@body, $1 =~ /ipv6/i ? "IPv6" : "IPv4");
			}
		
		# Get address
		if (/address=["'](.*?)["']/) {
			push(@head, "IP");
			push(@body, "$1&nbsp;&nbsp;");
			}

		# Get origin
		if (/\s+(source|destination)\s+/) {
			push(@head, "Origin");
			push(@body, $1 eq 'source' ? 'Input' : 'Output');
			}

		# Get action
		if (/(accept|reject|drop|mark$)/i) {
			push(@head, "Action");
			push(@body, ucfirst($1));
			}

		# Add full rule
		push(@head, "Rule");
		push(@body, "<tt>$_</tt>");
		
		# Print start
		if (!$head++) {
			print &ui_form_start("delete_rules.cgi", "post");
			print &ui_links_row(\@links);
			print &ui_columns_start(\@head);
			}
		# print &ui_checked_columns_row(\@body, [ 'width=5', undef, $tdc, $tdc, $tdc, $tdc, $tdc ], "rules", 'rule') if ($data);
		print &ui_checked_columns_row(\@body, undef, "rules", $_);
		}
	}
close($fh);

# Check direct rules first
my $fh2 = 'drules';
my $dcmd = "$config{'firewall_cmd'} --direct --get-all-rules";
&open_execute_command($fh2, "$dcmd 2>&1 </dev/null", 1);
while(<$fh2>) {
	my @body;
	if ($_ =~ /\S+/) {
		if (/set\s+\-\-match-set\s+(.*?)\s+/) {
			my $ipset_name = $1;
			my $ips = "&ndash;";
			my $ipset_cmd = &has_command('ipset');
			my $ipset_cmd_out = &backquote_logged("$ipset_cmd list ".quotemeta($ipset_name)." 2>&1 </dev/null");
			if (!$?) {
				if ($ipset_cmd_out =~ /number\s+of\s+entries:\s+(\d)+/i) {
					if ($1 > 0) {
						my @ipset_cmd_out_lines = split(/\n/, $ipset_cmd_out);
						my @ips = map { $_ =~ /^([0-9\.\:a-f]+)/i } @ipset_cmd_out_lines;
						$ips = join("&nbsp;&nbsp;<br>", @ips);
						}
					}
				}

			push(@body, 'Direct');

			# Get protocol
			if (/(ipv\d)/) {
				push(@head, "Protocol");
				push(@body, $1 =~ /ipv6/i ? "IPv6" : "IPv4");
				}
			
			# Get address
			if (/address=["'](.*?)["']/) {
				}
				push(@head, "IP");
				push(@body, $ips);

			# Get origin
			if (/(INPUT|OUTPUT)/) {
				push(@head, "Origin");
				push(@body, ucfirst(lc($1)));
				}

			# Get action
			if (/(ACCEPT|REJECT|DROP|MARK$)/) {
				push(@head, "Action");
				push(@body, ucfirst(lc($1)));
				}

			# Add full rule
			push(@head, "Rule");
			push(@body, "<tt>$_</tt>");
			
			# Print start
			if (!$head++) {
				print &ui_form_start("delete_rules.cgi", "post");
				print &ui_links_row(\@links);
				print &ui_columns_start(\@head);
				}
			# print &ui_checked_columns_row(\@body, [ 'width=5', undef, $tdc, $tdc, $tdc, $tdc, $tdc ], "rules", 'rule') if ($data);
			print &ui_checked_columns_row(\@body, undef, "rules", $_);
		}
		}
	}
close($fh2);


if ($head) {
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ 'remove', $text{'richrules_delete'} ] ] );
	}
else {
	print "There are no existing direct or rich firewall rules to display."
	}


# my ($jail_list) = $out =~ /jail\s+list:\s*(.*)/im;
# my @jails = split(/,\s*/, $jail_list);
# if (@jails) {
# 	my $tdc = "style=\"text-align: center\"";
# 	my @links = ( &select_all_link("jail"),
# 	              &select_invert_link("jail") );
# 	my $head;
# 	my @jipsall;
# 	foreach my $jail (@jails) {
# 		my $cmd = "$config{'client_cmd'} status ".quotemeta($jail);
# 		my @head = (undef, $text{"status_head_jail_name"});
# 		my @body = (&ui_link("edit_jail.cgi?name=".urlize($jail), "&nbsp;".&html_escape($jail)));
# 		my $jips;
# 		my $noval;
# 		&open_execute_command($fh, $jcmd, 1);
# 		while(<$fh>) {
# 			if (/-\s+(.*):\s*(.*)/) {
# 				my $col = $1;
# 				my $val = $2;
# 				$col = lc($col);
# 				$col =~ s/\s/_/g;
# 				if ($col !~ /journal_matches/) {
# 					push(@head, "<div $tdc>".$text{"status_head_$col"}."</div>");
# 					if ($col =~ /banned_ip_list/) {
# 						$jips = $val;
# 						my @ips = split(/\s+/, $val);
# 						@ips = map { "<label style=\"white-space: nowrap\">" .
# 							&ui_link("unblock_jail.cgi?unblock=1&jips-@{[&urlize($jail)]}=@{[&urlize($_)]}&jail=@{[&urlize($jail)]}", $_, undef,
# 							         "title=\"@{[&text('status_jail_unblock_ip', &quote_escape($_))]}\" onmouseover=\"this.style.textDecoration='line-through'\" onmouseout=\"this.style.textDecoration='none'\""
# 							        ) . 
# 							($is_firewalld ? "&nbsp; &nbsp; " .
# 							&ui_link("unblock_jail.cgi?permblock=1&jips-@{[&urlize($jail)]}=@{[&urlize($_)]}&jail=@{[&urlize($jail)]}", "&empty;", undef,
# 							         "title=\"@{[&text('status_jail_permblock_ip', &quote_escape($_))]}\" onmouseover=\"this.style.opacity='1';this.style.filter='grayscale(0)'\" onmouseout=\"this.style.opacity='0.25';this.style.filter='grayscale(100%)'\" style=\"font-size: 125%; margin-right:10px; filter: grayscale(100%); opacity: .25\""
# 							        ) : undef) . "</label>" } @ips;
# 						$val = "<br>" if ($val);
# 						$val .= join('<br>', @ips);
# 						$val .= "<br><br>" if ($val);
# 						$val .= "&ndash;", $noval++ if (!$val);
# 						}
# 					push(@body, $val);
# 					}
# 				}
# 			}
# 		close($fh);
# 		if (!$head++) {
# 			print &ui_form_start("unblock_jail.cgi", "post");
# 			print &ui_links_row(\@links);
# 			print &ui_columns_start(\@head);
# 			}
# 		print &ui_checked_columns_row(\@body, [ 'width=5', undef, $tdc, $tdc, $tdc, $tdc, $noval ? $tdc : undef ], "jail", $jail);
# 		push(@jipsall, ["$jail" => $jips]);
# 	}
# 	if ($head) {
# 		print &ui_columns_end();
# 		print &ui_links_row(\@links);
# 		foreach my $j (@jipsall) {
# 			print &ui_hidden("jips-$j->[0]", "$j->[1]");
# 		}
# 		print &ui_form_end([ [ 'unblock', $text{'status_jail_unblock'} ],
# 		                     $is_firewalld ?
# 		                       [ 'permblock', $text{'status_jail_block'} ] : undef ]);
# 	};
# }
# else {
# 	print $text{'status_jail_noactive'};
# 	}

# &ui_print_footer("", $text{'index_return'});
