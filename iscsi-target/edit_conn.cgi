#!/usr/local/bin/perl
# Show global connection-related options

use strict;
use warnings;
require './iscsi-target-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'conn_title'}, "");

print &ui_form_start("save_conn.cgi", "post");
print &ui_table_start($text{'conn_header'}, undef, 2);

# Max sessions per target
my $s = &find_value($conf, "MaxSessions");
print &ui_table_row($text{'conn_sessions'},
	&ui_opt_textbox("sessions", $s, 5,
			$text{'conn_sessions1'}, $text{'conn_sessions0'}));

# Allow initiator to send data with command?
my $i = &find_value($conf, "InitialR2T");
print &ui_table_row($text{'conn_initial'},
	&ui_yesno_radio("initial", lc($i) eq "no" ? 0 : 1));

# Allow initiator to send data immediately?
$i = &find_value($conf, "ImmediateData");
print &ui_table_row($text{'conn_immediate'},
	&ui_yesno_radio("immediate", lc($i) eq "yes" ? 1 : 0));

# Various data lengths
foreach my $fv ([ "MaxRecvDataSegmentLength", "maxrecv" ],
		[ "MaxXmitDataSegmentLength", "maxxmit" ],
		[ "MaxBurstLength", "maxburst" ],
		[ "FirstBurstLength", "firstburst" ]) {
	my $s = &find_value($conf, $fv->[0]);
	print &ui_table_row($text{'conn_'.$fv->[1]},
		&ui_opt_textbox($fv->[1], $s || undef, 5, $text{'default'})." ".
		$text{'conn_bytes'});
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
