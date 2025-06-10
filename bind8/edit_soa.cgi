#!/usr/local/bin/perl
# edit_soa.cgi
# Display the SOA for an existing master zone
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %in, %text, %config);

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'params'} || &error($text{'master_esoacannot'});
&ui_print_header(&zone_subhead($zone), $text{'master_params'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

my @recs = &read_zone_file($zone->{'file'}, $dom);
my $soa;
my $defttl;
foreach my $r (@recs) {
	$soa = $r if ($r->{'type'} eq "SOA");
	$defttl = $r if ($r->{'defttl'});
	}
my $v = $soa->{'values'};

# form for editing SOA record
print &ui_form_start("save_soa.cgi", "post");
print &ui_hidden("num", $soa->{'num'});
print &ui_hidden("origin", $dom);
print &ui_hidden("zone", $in{'zone'});
print &ui_hidden("view", $in{'view'});
print &ui_table_start($text{'master_params'}, "width=100%", 4);

# Master nameserver
print &ui_table_row($text{'master_server'},
	&ui_textbox("master", $v->[0], 30));

# Owner's email address
$v->[1] = &dotted_to_email($v->[1]);
print &ui_table_row($text{'master_email'},
	&ui_textbox("email", $v->[1], 30));

# Refresh time
my @u = &extract_time_units($v->[3], $v->[4], $v->[5], $v->[6]);
print &ui_table_row($text{'master_refresh'},
	&ui_textbox("refresh", $v->[3], 10)." ".
	&time_unit_choice("refunit", $u[0]));

# Retry time
print &ui_table_row($text{'master_retry'},
	&ui_textbox("retry", $v->[4], 10)." ".
	&time_unit_choice("retunit", $u[1]));

# Expiry time
print &ui_table_row($text{'master_expiry'},
	&ui_textbox("expiry", $v->[5], 10)." ".
	&time_unit_choice("expunit", $u[2]));

# Minimum TTL
print &ui_table_row($text{'master_minimum'},
	&ui_textbox("minimum", $v->[6], 10)." ".
	&time_unit_choice("minunit", $u[3]));

# Default TTL
my $ttl = $defttl->{'defttl'} if ($defttl);
my ($ttlu) = &extract_time_units($ttl);
print &ui_table_row($text{'master_defttl'},
	&ui_radio("defttl_def", $defttl ? 0 : 1,
		  [ [ 1, $text{'default'} ], [ 0, " " ] ])."\n".
	&ui_textbox("defttl", $ttl, 10)." ".
	&time_unit_choice("defttlunit", $ttlu), 3);

if (!$config{'updserial_on'}) {
	# Serial number
	print &ui_table_row($text{'master_serial'},
		&ui_textbox("serial", $v->[2], 20));
	}

print &ui_table_end();
print &ui_form_end($access{'ro'} ? [ ] : [ [ undef, $text{'save'} ] ]);

&ui_print_footer("edit_master.cgi?zone=$in{'zone'}&view=$in{'view'}",
	$text{'master_return'});

