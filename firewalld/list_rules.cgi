#!/usr/local/bin/perl
# List FirewallD rich and direct rules

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './firewalld-lib.pl';
our (%in, %text, %config);
&ReadParse();
my $dzone = $in{'zone'};
if (!$dzone) {
	my $zone = &get_default_zone();
	$dzone = $zone->{'name'};
	}
&ui_print_header(&text('list_rules_title_sub', "<tt>".&html_escape($dzone)."</tt>"), $text{'list_rules_title'}, "");

my $head;
my @head = (undef, $text{'list_rules_type'});
my $tdc = "style=\"text-align: center\"";
my @links = ( &select_all_link("rules"),
              &select_invert_link("rules") );

# Check rich rules first
my $fh = 'rrules';
my $rcmd = "$config{'firewall_cmd'} --list-rich-rules --zone=".quotemeta($dzone)."";
&open_execute_command($fh, "$rcmd 2>&1 </dev/null", 1);
while(<$fh>) {
	my @body;
	if ($_ =~ /\S+/) {
		push(@body, $text{'list_rules_type_rich'});

		# Get protocol
		if (/family=["'](ipv\d)["']/) {
			push(@head, $text{'list_rules_protocol'});
			push(@body, $1 =~ /ipv6/i ? "IPv6" : "IPv4");
			}
		
		# Get address
		if (/address=["'](.*?)["']/) {
			push(@head, $text{'list_rules_ip'});
			push(@body, "$1&nbsp;&nbsp;");
			}

		# Get origin
		if (/\s+(source|destination)\s+/) {
			push(@head, $text{'list_rules_origin'});
			push(@body, $1 eq 'source' ? 'Input' : 'Output');
			}

		# Get action
		if (/(accept|reject|drop|mark$)/i) {
			push(@head, $text{'list_rules_action'});
			push(@body, ucfirst($1));
			}

		# Add full rule
		push(@head, $text{'list_rules_rule'});
		push(@body, "<tt>$_</tt>");
		
		# Print start
		if (!$head++) {
			print &ui_form_start("save_rules.cgi", "post");
			print &ui_hidden("zone", $dzone);
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
		my $ndash = "&ndash;";
		my $br = "<br>";
		my $nbsp = "&nbsp;";
		my $ips = $ndash;
		my $candelete = 1;
		my $ipslimit = sub {
			my ($ips, $limit) = @_;
			$limit ||= 15;
			# Limit sanity check and adjustment
			$limit = 1 if ($limit < 1);
			$limit -= 1;
			my $ipscount = () = $ips =~ /$br/g;
			if ($ipscount > $limit) {
				my @ips = split($br, $ips);
				@ips = @ips[0 .. $limit];
				$ips = join($br, @ips);
				$ips .= "<small>$br$nbsp".&text('list_rules_plus_more', $ipscount-$limit)."</small>";
				}
			return $ips;
		};
		# Extract IPs from match sets
		if (/set\s+\-\-match-set\s+(.*?)\s+/) {
			my $ipset_name = $1;
			my $ipset_cmd = &has_command($config{'firewall_ipset'} || 'ipset');
			my $ipset_cmd_out = &backquote_logged("$ipset_cmd list ".quotemeta($ipset_name)." 2>&1 </dev/null");
			if (!$?) {
				if ($ipset_cmd_out =~ /number\s+of\s+entries:\s+(\d)+/i) {
					if ($1 > 0) {
						my @ipset_cmd_out_lines = split(/\n/, $ipset_cmd_out);
						my @ips = map { $_ =~ /^([0-9\.\:a-f\/]+)/i } @ipset_cmd_out_lines;
						$ips = join("$nbsp$nbsp$br", @ips);
						}
					}
				}
				# Rules with match sets must not be controlled here
				$candelete = 0;
			}

			# Standard direct rules
			else {
				# Extract IPs from the rule,
				# considering comma separated
				my @ips = ($_ =~ /(?:-[sd]|--source|--destination)\s+([0-9\.\:a-f,\/]+)/gi);
				$ips = join("$nbsp$nbsp$br", @ips);
				$ips =~ s/\s*,\s*/$nbsp$nbsp$br/g;
				$ips ||= $ndash;
				}

			# Trim the number of IPs to allow at max 10
			$ips = &$ipslimit($ips);

			# Add type name
			push(@body, $text{'list_rules_type_direct'});

			# Get protocol
			if (/(ipv\d)/) {
				push(@head, $text{'list_rules_protocol'});
				push(@body, $1 =~ /ipv6/i ? "IPv6" : "IPv4");
				}
			
			# Get address
			push(@head, $text{'list_rules_ip'});
			push(@body, $ips);

			# Get origin
			if (/(INPUT|OUTPUT|FORWARD|POSTROUTING)/) {
				push(@head, $text{'list_rules_origin'});
				push(@body, ucfirst(lc($1)));
				}

			# Get action
			if (/(ACCEPT|REJECT|DROP|MARK|MASQUERADE|LOG)/) {
				push(@head, $text{'list_rules_action'});
				push(@body, ucfirst(lc($1)));
				}

			# Add full rule
			push(@head, $text{'list_rules_rule'});
			push(@body, "<tt>$_</tt>");
			
			# Print start
			if (!$head++) {
				print &ui_form_start("save_rules.cgi", "post");
				print &ui_hidden("zone", $dzone);
				print &ui_links_row(\@links);
				print &ui_columns_start(\@head);
				}
			print &ui_checked_columns_row(\@body, [ 'width=5', $tdc, $tdc, undef, $tdc, $tdc, undef ], "rules", $_, undef, !$candelete);
		}
	}
close($fh2);


if ($head) {
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ 'remove', $text{'list_rules_delete'} ] ] );
	}
else {
	print "There are no existing direct or rich firewall rules to display."
	}

&ui_print_footer("index.cgi?zone=".&urlize($dzone), $text{'index_return'});
