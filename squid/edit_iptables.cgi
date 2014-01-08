#!/usr/local/bin/perl
# Show form for adding or removing Squid transparent proxy IPtables rule

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
&ui_print_header(undef, $text{'iptables_title'}, "");
&foreign_require("firewall", "firewall-lib.pl");
&foreign_require("net", "net-lib.pl");

# Is the Linux firewall module setup OK?
my $inst = &foreign_installed("firewall", 1);
if ($inst == 0) {
	# Not installed at all
	&ui_print_endpage(&text('iptables_inst0', "../firewall/"));
	}
elsif ($inst == 1) {
	# Not properly setup
	&ui_print_endpage(&text('iptables_inst1', "../firewall/"));
	}

# See if a rule redirecting to the port exists
my $port = &get_squid_port();
my @tables = &firewall::get_iptables_save();
my ($nat) = grep { $_->{'name'} eq 'nat'} @tables;
my $rule;
foreach my $r (@{$nat->{'rules'}}) {
	if ($r->{'chain'} eq 'PREROUTING' &&
	    $r->{'j'}->[1] eq 'REDIRECT' &&
	    $r->{'dport'}->[1] == 80 &&
	    $r->{'to-ports'}->[1] == $port) {
		# Got one!
		$rule = $r;
		}
	}

# Show enabled/disable rule form
print &text('iptables_desc', 80, $port, "../firewall/"),"<p>\n";
print &ui_form_start("save_iptables.cgi", "post");
print &ui_hidden("rule", $rule->{'index'}) if ($rule);
print &ui_table_start(undef, undef, 2);

print &ui_table_row(undef,
	&ui_radio_table("enabled", !$rule ? 0 : $rule && $rule->{'s'} ? 1 :
				   $rule && $rule->{'i'} ? 2 : 0,
	  [ [ 0, $text{'iptables_disabled'} ],
	    [ 1, $text{'iptables_enabled3'},
	      &ui_textbox("net", $rule ? $rule->{'s'}->[1] : "", 20) ],
	    [ 2, $text{'iptables_enabled4'},
	      &net::interface_choice("iface", $rule ? $rule->{'i'}->[1] : "") ]
	  ]), 2);

print &ui_table_row(undef,
	&ui_checkbox("apply", 1, $text{'iptables_apply'}, 1), 2);

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});

