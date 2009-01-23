#!/usr/local/bin/perl
# edit_user.cgi
# Display other misc user-level options

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("user");
&ui_print_header($header_subtext, $text{'user_title'}, "");
$conf = &get_config();

print "$text{'user_desc'}<p>\n";
&start_form("save_user.cgi", $text{'user_header'});

# Do DNS lookups?
$dns = lc(&find_value("dns_available", $conf));
$dns = "test" if (!$dns && $config{'defaults'});
@dnsopts = ( [ 1, $text{'yes'} ],
	     [ 0, $text{'no'} ],
	     !$config{'defaults'} ? ( [ -1, $text{'default'}.
				       " (".$text{'user_dnstest'}.")" ] ) : ( ),
	     [ 2, $text{'user_dnslist'} ] );
print &ui_table_row($text{'user_dns'},
	&ui_radio("dns", $dns eq 'yes' ? 1 :
			 $dns eq 'no' ? 0 :
			 !$dns ? -1 :
		 	 $dns =~ /^test/ ? 2 : 3, \@dnsopts).
	&ui_textbox("dnslist", $dns =~ /^test:\s*(.*)/ ? $1 : "", 30));


# Use razor?
$razor = &find("razor_timeout", $conf);
print &ui_table_row($text{'user_razor'},
	&opt_field("razor_timeout", $razor, 5, 10));

print &ui_table_hr();

# DCC command
$dcc = &find("dcc_path", $conf);
print &ui_table_row($text{'user_dcc'},
	&opt_field("dcc_path", $dcc, 40, $text{'user_inpath'}, 1)." ".
	&file_chooser_button("dcc_path", 0));

# Maximum body size for DCC
$bodymax = &find("dcc_body_max", $conf);
print &ui_table_row($text{'user_bodymax'},
	&opt_field("dcc_body_max", $bodymax, 6, 999999));

# DCC command timeout
$timeout = &find("dcc_timeout", $conf);
print &ui_table_row($text{'user_timeout'},
	&opt_field("dcc_timeout", $timeout, 5, 10));

# DCC fuzl?
$fuz1max = &find("dcc_fuz1_max", $conf);
print &ui_table_row($text{'user_fuz1max'},
	&opt_field("dcc_fuz1_max", $fuz1max, 6, 999999));

$fuz2max = &find("dcc_fuz2_max", $conf);
print &ui_table_row($text{'user_fuz2max'},
	&opt_field("dcc_fuz2_max", $fuz2max, 6, 999999));

if (!&version_atleast(3)) {
	# Add DCC header?
	$dheader = &find("dcc_add_header", $conf);
	print &ui_table_row($text{'user_dheader'},
		&yes_no_field("dcc_add_header", $dheader, 0));
	}

print &ui_table_hr();

# Pyzor command
$pyzor = &find("pyzor_path", $conf);
print &ui_table_row($text{'user_pyzor'},
	&opt_field("pyzor_path", $pyzor, 40, $text{'user_inpath'}, 1)." ".
	&file_chooser_button("pyzor_path", 0));

# Maximum Pyzor body size
$pbodymax = &find("pyzor_body_max", $conf);
print &ui_table_row($text{'user_pbodymax'},
	&opt_field("pyzor_body_max", $pbodymax, 6, 999999));

# Pyzor command timeout
$ptimeout = &find("pyzor_timeout", $conf);
print &ui_table_row($text{'user_ptimeout'},
	&opt_field("pyzor_timeout", $ptimeout, 5, 10));

# Add Pyzor header?
$pheader = &find("pyzor_add_header", $conf);
print &ui_table_row($text{'user_pheader'},
	&yes_no_field("pyzor_add_header", $pheader, 0));

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});


