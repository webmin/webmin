#!/usr/local/bin/perl
# Show form for adding or removing Frox IPtables rule

require './frox-lib.pl';
&ui_print_header(undef, $text{'iptables_title'}, "");
&foreign_require("firewall", "firewall-lib.pl");
&foreign_require("net", "net-lib.pl");

# Is the Linux firewall module setup OK?
$inst = &foreign_installed("firewall", 1);
if ($inst == 0) {
	# Not installed at all
	&ui_print_endpage(&text('iptables_inst0', "../firewall/"));
	}
elsif ($inst == 1) {
	# Not properly setup
	&ui_print_endpage(&text('iptables_inst1', "../firewall/"));
	}

# See if a rule redirecting to the port exists
$conf = &get_config();
$port = &find_value("Port", $conf);
@tables = &firewall::get_iptables_save();
($nat) = grep { $_->{'name'} eq 'nat'} @tables;
foreach $r (@{$nat->{'rules'}}) {
	if ($r->{'chain'} eq 'PREROUTING' &&
	    $r->{'j'}->[1] eq 'REDIRECT' &&
	    $r->{'dport'}->[1] == 21 &&
	    $r->{'to-ports'}->[1] == $port) {
		# Got one!
		$rule = $r;
		}
	}

# Show enabled/disable rule form
print &text('iptables_desc', 21, $port, "../firewall/"),"<p>\n";
print &ui_form_start("save_iptables.cgi", "post");
print &ui_hidden("rule", $rule->{'index'}) if ($rule);

print &ui_oneradio("enabled", 0, $text{'iptables_disabled'}, !$rule),"<br>\n";

print &ui_oneradio("enabled", 1, &text('iptables_enabled',
       	&ui_textbox("net", $rule ? $rule->{'s'}->[1] : "", 20)),
	$rule && $rule->{'s'}),"<br>\n";

print &ui_oneradio("enabled", 2, &text('iptables_enabled2',
	&net::interface_choice("iface", $rule ? $rule->{'i'}->[1] : "")),
	$rule && $rule->{'i'}),"<br>\n";

print &ui_form_end([ [ 'save', $text{'iptables_save'} ] ], "100%");

&ui_print_footer("", $text{'index_return'});
