#!/usr/local/bin/perl
# edit_soptions.cgi
# Display options for an existing slave or stub zone
use strict;
use warnings;
our (%access, %in, %text);
our $scriptname;

require './bind8-lib.pl';
&ReadParse();

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $z = &zone_to_config($zone);
my $zconf = $z->{'members'};
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

$access{'opts'} || &error($text{'slave_ecannot'});
my $desc = &ip6int_to_net(&arpa_to_ip($dom));
&ui_print_header($desc, $text{'master_opts'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

# Start of the form
print &ui_form_start("save_slave.cgi", "post");
print &ui_hidden("zone", $in{'zone'});
print &ui_hidden("view", $in{'view'});
print &ui_hidden("slave_stub", $scriptname);
print &ui_table_start($text{'slave_opts'}, "width=100%", 2);

# Master addresses and port
print &address_port_input($text{'slave_masters'},
			  $text{'slave_masterport'},
			  $text{'slave_master_port'}, 
			  $text{'default'}, 
			  "masters",
			  "port",
			  $zconf,
			  5);

# Transfer time max
print &opt_input($text{'slave_max'}, "max-transfer-time-in",
		 $zconf, $text{'default'}, 4, $text{'slave_mins'});

# Slave records file
print &opt_input($text{'slave_file'}, "file", $zconf, $text{'slave_none'}, 40);

print &choice_input($text{'slave_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);
print &choice_input($text{'slave_notify'}, "notify", $zconf,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'default'}, undef);

print &addr_match_input($text{'slave_update'}, "allow-update", $zconf);
print &addr_match_input($text{'slave_transfer'}, "allow-transfer", $zconf);

print &addr_match_input($text{'slave_query'}, "allow-query", $zconf);
print &address_input($text{'slave_notify2'}, "also-notify", $zconf);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_slave.cgi?zone=$in{'zone'}&view=$in{'view'}",
		 $text{'master_return'});

