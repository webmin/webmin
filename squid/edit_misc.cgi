#!/usr/local/bin/perl
# edit_misc.cgi
# A form for edit misc options

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'miscopt'} || &error($text{'emisc_ecannot'});
&ui_print_header(undef, $text{'emisc_header'}, "", "edit_misc", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_misc.cgi", "post");
print &ui_table_start($text{'emisc_mo'}, "width=100%", 4);

print &opt_input($text{'emisc_sdta'}, "dns_testnames", $conf,
		 $text{'default'}, 40);

print &opt_input($text{'emisc_slr'}, "logfile_rotate", $conf,
		 $text{'default'}, 6);
print &opt_input($text{'emisc_dd'}, "append_domain", $conf, $text{'none'}, 10);

if ($squid_version < 2) {
	print &opt_input($text{'emisc_sp'}, "ssl_proxy", $conf, $text{'none'}, 15);
	print &opt_input($text{'emisc_nghp'}, "passthrough_proxy",
			 $conf, $text{'none'}, 15);
	}

print &opt_input($text{'emisc_emt'}, "err_html_text", $conf, $text{'none'}, 40);

print &choice_input($text{'emisc_pcs'}, "client_db", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
print &choice_input($text{'emisc_xffh'}, "forwarded_for", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");

print &choice_input($text{'emisc_liq'}, "log_icp_queries", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
print &opt_input($text{'emisc_mdh'}, "minimum_direct_hops", $conf,
		 $text{'default'}, 6);

print &choice_input($text{'emisc_kmffu'}, "memory_pools", $conf,
		    "on", $text{'yes'}, "on", $text{'no'}, "off");
if ($squid_version >= 2) {
	print &opt_bytes_input($text{'emisc_aomtk'}, "memory_pools_limit",
			       $conf, $text{'emisc_u'}, 6);
	}

if ($squid_version >= 2.2 && $squid_version < 2.5) {
	my (@anon, $anon);
	foreach my $a (&find_config("anonymize_headers", $conf)) {
		my @ap = @{$a->{'values'}};
		$anon = shift(@ap);
		push(@anon, @ap);
		}
	print &ui_table_row($text{'emisc_htpt'},
		&ui_radio_radio(
			"anon_mode", !$anon ? 0 : $anon eq "allow" ? 1 : 2,
			[ [ 0, $text{'emisc_ah'} ],
			  [ 1, $text{'emisc_oh'},
			    &ui_textbox("anon_allow",
				$anon eq "allow" ? join(" ", @anon) : "", 50) ],
			  [ 2, $text{'emisc_ae'},
			    &ui_textbox("anon_deny",
				$anon eq "deny" ? join(" ", @anon) : "", 50) ],
			]));
	}
elsif ($squid_version < 2.2) {
	print &choice_input($text{'emisc_a'}, "http_anonymizer", $conf,
			    "off", $text{'emisc_off'}, "off", 
				$text{'emisc_std'}, "standard",
			    $text{'emisc_par'}, "paranoid");
	}
print &opt_input($text{'emisc_fua'}, "fake_user_agent", $conf,
		 $text{'none'}, 15);

if ($squid_version < 2.6) {
	my $host = &find_value("httpd_accel_host", $conf);
	print &ui_table_row($text{'emisc_hah'},
		&ui_radio("accel", !$host ? 0 : $host eq "virtual" ? 1 : 2,
		          [ [ 0, $text{'emisc_none'} ],
			    [ 1, $text{'emisc_virtual'} ],
			    [ 2, &ui_textbox("httpd_accel_host",
				    $host eq "virtual" ? "" : $host, 50) ] ]));

	print &opt_input($text{'emisc_hap'}, "httpd_accel_port", $conf,
			 $text{'emisc_none'}, 10);
	if ($squid_version >= 2.5) {
		print &choice_input($text{'emisc_hash'},
			"httpd_accel_single_host", $conf, "off", $text{'yes'},
			"on", $text{'no'}, "off");
		}
	print &choice_input($text{'emisc_hawp'}, "httpd_accel_with_proxy",
			  $conf, "off", $text{'on'}, "on", $text{'off'}, "off");
	print &choice_input($text{'emisc_hauhh'}, "httpd_accel_uses_host_header", 
			  $conf, "off", $text{'yes'}, "on", $text{'no'}, "off");
	}

if ( $squid_version >= 2.3) {
        print &opt_input($text{'emisc_wccprtr'}, "wccp_router", $conf,
                         $text{'default'}, 35);
        print &opt_input($text{'emisc_wccpin'}, "wccp_incoming_address",
			 $conf, $text{'default'}, 35);
        print &opt_input($text{'emisc_wccpout'}, "wccp_outgoing_address",
			 $conf, $text{'default'}, 35);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'emisc_return'});

