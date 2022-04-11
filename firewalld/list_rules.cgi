#!/usr/local/bin/perl
# List FirewallD rich and direct rules

use strict;
use warnings;
require './firewalld-lib.pl';
our (%in, %text, %config);
&ReadParse();
my $dzone = $in{'zone'};
if (!$dzone) {
	my $zone = &get_default_zone();
	$dzone = $zone->{'name'};
	}
&ui_print_header(&text('richrules_title_sub', "<tt>".&html_escape($dzone)."</tt>"), $text{'richrules_title'}, "");

my $head;
my @head = (undef, "Type");
my $tdc = "style=\"text-align: center\"";
my @links = ( &select_all_link("rules"),
              &select_invert_link("rules") );

# Check rich rules first
my $fh = 'rrules';
my $rcmd = "$config{'firewall_cmd'} --list-rich-rules --zone=$dzone";
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
		print &ui_checked_columns_row(\@body, [ 'width=5', $tdc, $tdc, undef, $tdc, $tdc, undef ], "rules", $_);
		}
	}
close($fh);

# Check direct rules
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
			print &ui_checked_columns_row(\@body, [ 'width=5', $tdc, $tdc, undef, $tdc, $tdc, undef ], "rules", $_);
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

&ui_print_footer("", $text{'index_return'});
