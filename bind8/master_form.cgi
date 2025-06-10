#!/usr/local/bin/perl
# master_form.cgi
# Form for creating a new master zone
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %config);

require './bind8-lib.pl';
&ReadParse();
$access{'master'} || &error($text{'mcreate_ecannot'});
&ui_print_header(undef, $text{'mcreate_title'}, "",
		 undef, undef, undef, undef, &restart_links());

print &ui_form_start("create_master.cgi", "post");
print &ui_table_start($text{'mcreate_opts'}, "width=100%", 4);

# Forward or reverse?
print &ui_table_row($text{'mcreate_type'},
	&ui_radio("rev", 0, [ [ 0, $text{'mcreate_fwd'} ],
			      [ 1, $text{'mcreate_rev'} ] ]), 3);

# Domain / network name
print &ui_table_row($text{'mcreate_dom'},
	&ui_textbox("zone", undef, 40), 3);

# Sign zones automatically
if (&have_dnssec_tools_support()) {
	print &ui_table_row($text{'mcreate_dnssec_tools_enable'},
		&ui_yesno_radio("enable_dt", $config{'tmpl_dnssec_dt'} ? 1 : 0));

	# Key algorithm
	print &ui_table_row($text{'dt_zone_dne'},
		&ui_select("dne", "NSEC",
					   [ &list_dnssec_dne() ]));
}

my $conf = &get_config();
my @views = &find("view", $conf);
if (@views) {
	my ($defview) = grep { lc($_->{'values'}->[0]) eq
			    lc($config{'default_view'}) } @views;
	print &ui_table_row($text{'mcreate_view'},
		&ui_select("view", $defview ? $defview->{'index'} : undef,
			[ map { [ $_->{'index'}, $_->{'values'}->[0] ] }
			      grep { &can_edit_view($_) } @views ]), 3);
	}

# Records filename
print &ui_table_row($text{'mcreate_file'},
	&ui_opt_textbox("file", undef, 30, $text{'mcreate_auto'})." ".
	&file_chooser_button("file"), 3);

# Master server IP
print &ui_table_row($text{'master_server'},
	&ui_textbox("master", $config{'default_prins'} ||
			      &get_system_hostname(), 30)."\n".
	&ui_checkbox("master_ns", 1, $text{'master_ns'}, 1), 3);

# Create on slave servers?
my @servers = &list_slave_servers();
if (@servers && $access{'remote'}) {
	print &ui_table_row($text{'master_onslave'},
		&ui_radio("onslave", 1,
			[ [ 0, $text{'no'} ],
			  [ 1, $text{'master_onslaveyes'} ] ])."\n".
		&ui_textbox("mip", $config{'this_ip'} ||
			&to_ipaddress(&get_system_hostname()), 30), 3);

	print &ui_table_row($text{'master_slavefile'},
		&ui_radio("sfile_def", 2, 
			[ [ 1, $text{'slave_none'} ],
			  [ 2, $text{'slave_auto'} ],
			  [ 0, &ui_textbox("sfile", undef, 30) ] ]), 3);
	}

# Master email address
print &ui_table_row($text{'master_email'},
	&ui_textbox("email", $config{'tmpl_email'}, 40), 3);

# Use template?
print &ui_table_row($text{'master_tmpl'},
	&ui_yesno_radio("tmpl", $config{'tmpl_0'} ||
				$config{'tmpl_include'} ? 1 : 0));

# Template IP
print &ui_table_row($text{'master_ip'},
	&ui_textbox("ip", undef, 15));

# Add to reverses?
print &ui_table_row($text{'master_addrev'},
	&ui_yesno_radio("addrev", 1), 3);

# SOA options
my %zd;
&get_zone_defaults(\%zd);
print &ui_table_row($text{'master_refresh'},
	&ui_textbox("refresh", $zd{'refresh'}, 8)." ".
	&time_unit_choice("refunit", $zd{'refunit'}));

print &ui_table_row($text{'master_retry'},
	&ui_textbox("retry", $zd{'retry'}, 8)." ".
	&time_unit_choice("retunit", $zd{'retunit'}));

print &ui_table_row($text{'master_expiry'},
	&ui_textbox("expiry", $zd{'expiry'}, 8)." ".
	&time_unit_choice("expunit", $zd{'expunit'}));

print &ui_table_row($text{'master_minimum'},
	&ui_textbox("minimum", $zd{'minimum'}, 8)." ".
	&time_unit_choice("minunit", $zd{'minunit'}));

print &ui_table_end();
print &ui_form_end([ [ "create", $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

