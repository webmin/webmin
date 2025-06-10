#!/usr/local/bin/perl
# conf_zonedef.cgi
# Display defaults for master zones
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'zonedef_ecannot'});
&ui_print_header(undef, $text{'zonedef_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Start of defaults for new zones form
print &ui_form_start("save_zonedef.cgi", "post");
print &ui_table_start($text{'zonedef_msg'}, "width=100%", 4);
my %zd;
&get_zone_defaults(\%zd);

# Default refresh time
print &ui_table_row($text{'master_refresh'},
	&ui_textbox("refresh", $zd{'refresh'}, 10)." ".
	&time_unit_choice("refunit", $zd{'refunit'}));

# Default retry time
print &ui_table_row($text{'master_retry'},
	&ui_textbox("retry", $zd{'retry'}, 10)." ".
	&time_unit_choice("retunit", $zd{'retunit'}));

# Default expiry time
print &ui_table_row($text{'master_expiry'},
	&ui_textbox("expiry", $zd{'expiry'}, 10)." ".
	&time_unit_choice("expunit", $zd{'expunit'}));

# Default minimum time (what is this really?)
print &ui_table_row($text{'master_minimum'},
	&ui_textbox("minimum", $zd{'minimum'}, 10)." ".
	&time_unit_choice("minunit", $zd{'minunit'}));

# Records for new zones, as a table
my @table = ( );
for(my $i=0; $i<2 || $config{"tmpl_".($i-1)}; $i++) {
	my @c = split(/\s+/, $config{"tmpl_$i"}, 3);
	push(@table, [ &ui_textbox("name_$i", $c[0], 15),
		       &ui_select("type_$i", $c[1],
			[ map { [ $_, $text{"type_".$_} ] }
			    ('A', 'CNAME', 'MX', 'NS', 'TXT', 'HINFO') ]),
		       &ui_opt_textbox("value_$i", $c[2], 15,
				       $text{'master_user'}),
		     ]);
	}
print &ui_table_row($text{'master_tmplrecs'},
	&ui_columns_table([ $text{'master_name'}, $text{'master_type'},
			    $text{'master_value'} ],
			  undef, \@table, undef, 1), 3);

# Additional include file
print &ui_table_row($text{'master_include'},
	&ui_opt_textbox("include", $config{'tmpl_include'}, 40,
			$text{'master_noinclude'})." ".
	&file_chooser_button("include"), 3);

# Default email address
print &ui_table_row($text{'zonedef_email'},
	&ui_textbox("email", $config{'tmpl_email'}, 40), 3);

# Default nameservers
print &ui_table_row($text{'zonedef_prins'},
	&ui_opt_textbox("prins", $config{'default_prins'}, 30,
	    &text('zonedef_this', "<tt>".&get_system_hostname()."</tt>")), 3);

# Setup DNSSEC by default?
if (&supports_dnssec()) {
	print &ui_table_hr();

	# Enabled?
	print &ui_table_row($text{'zonedef_dnssec'},
		&ui_yesno_radio("dnssec", $config{'tmpl_dnssec'}), 3);

	if (&have_dnssec_tools_support()) {
		# Automate using DNSSEC-Tools
		print &ui_table_row($text{'zonedef_dnssec_dt'},
			&ui_yesno_radio("dnssec_dt", $config{'tmpl_dnssec_dt'}), 3);

		# Default DNE
		print &ui_table_row($text{'zonedef_dne'},
			&ui_select("dnssec_dne", $config{'tmpl_dnssec_dne'} || "NSEC",
			[ &list_dnssec_dne() ]), 3);
	}

	# Default algorithm
	print &ui_table_row($text{'zonedef_alg'},
		&ui_select("alg", $config{'tmpl_dnssecalg'} || "RSASHA1",
			   [ &list_dnssec_algorithms() ]), 3);

	# Default size
	my $sizedef = $config{'tmpl_dnssecsizedef'};
	$sizedef = 1 if ($sizedef eq '');
	print &ui_table_row($text{'zonedef_size'},
		&ui_radio("size_def", $sizedef,
			[ [ 1, $text{'zonekey_ave'}."<br>" ],
			  [ 2, $text{'zonekey_strong'}."<br>"],
			  [ 0, $text{'zonekey_other'} ] ]).
		" ".&ui_textbox("size", $config{'tmpl_dnssecsize'}, 6), 3);

	# Number of keys
	print &ui_table_row($text{'zonedef_single'},
		&ui_radio("single", $config{'tmpl_dnssecsingle'} ? 1 : 0,
			  [ [ 0, $text{'zonedef_two'} ],
			    [ 1, $text{'zonedef_one'} ] ]));
	}

print &ui_table_end();

# Start of table for global BIND options
my $conf = &get_config();
my $options = &find("options", $conf);
my $mems = $options->{'members'};
my %check;
foreach my $c (&find("check-names", $mems)) {
	$check{$c->{'values'}->[0]} = $c->{'values'}->[1];
	}
print &ui_table_start($text{'zonedef_msg2'}, "width=100%", 4);

print &addr_match_input($text{'zonedef_transfer'}, "allow-transfer", $mems);
print &addr_match_input($text{'zonedef_query'}, "allow-query", $mems);
print &addr_match_input($text{'master_notify2'}, "also-notify", $mems);

print &ignore_warn_fail($text{'zonedef_cmaster'}, 'master', $check{'master'});
print &ignore_warn_fail($text{'zonedef_cslave'}, 'slave', $check{'slave'});

print &ignore_warn_fail($text{'zonedef_cresponse'}, 'response',
			$check{'response'});
print &choice_input($text{'zonedef_notify'}, "notify", $mems,
		    $text{'yes'}, "yes", $text{'no'}, "no",
		    $text{'explicit'}, "explicit",
		    $text{'default'}, undef);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

# ignore_warn_fail(text, name, value)
sub ignore_warn_fail
{
return &ui_table_row($_[0],
	&ui_radio($_[1], $_[2], [ [ 'ignore', $text{'ignore'} ],
			          [ 'warn', $text{'warn'} ],
			          [ 'fail', $text{'fail'} ],
			          [ '', $text{'default'} ] ]));
}

