#!/usr/local/bin/perl
# edit_sched.cgi
# Configure scheduled checking of services

require './status-lib.pl';
$access{'sched'} || &error($text{'sched_ecannot'});
&ui_print_header(undef, $text{'sched_title'}, "");

print &ui_form_start("save_sched.cgi", "post");
print &ui_table_start($text{'sched_header'}, "width=100%", 4);

# Enabled?
print &ui_table_row($text{'sched_mode'},
	&ui_yesno_radio("mode", int($config{'sched_mode'})));

# One email per problem?
print &ui_table_row($text{'sched_single'},
	&ui_yesno_radio("single", int($config{'sched_single'})));

# Checking interval and offset
print &ui_table_row($text{'sched_int'},
	&ui_textbox("int", $config{'sched_int'} || 5, 2)."\n".
	&ui_select("period", $config{'sched_period'},
		   [ map { [ $_, $text{"sched_period_".$_} ] } (0..3) ])."\n".
	$text{'sched_offset'}." ".
	&ui_textbox("offset", $config{'sched_offset'}, 2),
	3);

# Hours of the day
@hours = split(/\s+/, $config{'sched_hours'});
@hours = ( 0 .. 23 ) if (!@hours);
for($j=0; $j<24; $j+=6) {
	$hsel .= &ui_select("hours", \@hours,
			    [ map { [ $_, sprintf("%2.2d:00", $_) ] }
				  ($j .. $j+5) ], 6, 1);
	}
print &ui_table_row($text{'sched_hours'}, $hsel);

@days = split(/\s+/, $config{'sched_days'});
@days = ( 0 .. 6 ) if (!@days);
print &ui_table_row($text{'sched_days'},
	&ui_select("days", \@days,
	           [ map { [ $_, $text{'day_'.$_} ] } (0 .. 6) ], 7, 1));

# Send email when up / down / going down
print &ui_table_row($text{'sched_warn'},
	&ui_radio("warn", int($config{'sched_warn'}),
		  [ [ 1, $text{'sched_warn1'} ],
		    [ 0, $text{'sched_warn0'} ],
		    [ 2, $text{'sched_warn2'} ] ]), 3);

# Send email to
print &ui_table_row($text{'sched_email'},
	&ui_opt_textbox("email", $config{'sched_email'}, 30,
			$text{'sched_none'}, $text{'sched_email'}), 3);

# From: address
print &ui_table_row($text{'sched_from'},
	&ui_opt_textbox("from", $config{'sched_from'}, 30,
		        "$text{'default'} (webmin)"), 3);

# SMTP server
print &ui_table_row($text{'sched_smtp'},
	&ui_opt_textbox("smtp", $config{'sched_smtp'}, 30,
			$text{'sched_smtp_prog'},
			$text{'sched_smtp_server'}), 3);

if ($config{'pager_cmd'}) {
	# Pager number
	print &ui_table_row($text{'sched_pager'},
		&ui_opt_textbox("pager", $config{'sched_pager'}, 30,
				$text{'sched_pnone'}), 3);
	}

# SMS carrier and number
print &ui_table_row($text{'sched_sms'},
	&ui_radio("sms_def", $config{'sched_carrier'} ? 0 : 1,
		  [ [ 1, $text{'sched_smsno'} ],
		    [ 0, $text{'sched_smscarrier'} ] ])."\n".
	&ui_select("carrier", $config{'sched_carrier'},
	   [ map { [ $_->{'id'}, $_->{'desc'} ] }
		 sort { lc($a->{'desc'}) cmp lc($b->{'desc'}) }
		      &list_sms_carriers() ])."\n".
	$text{'sched_smsnumber'}." ".
	&ui_textbox("sms", $config{'sched_sms'}, 15), 3);

# Pager / SMS message subject
$smode = $config{'sched_subject'} eq '' ? 0 :
	 $config{'sched_subject'} eq '*' ? 1 : 2;
print &ui_table_row($text{'sched_subject'},
	&ui_radio_table("smode", $smode,
		[ [ 0, $text{'sched_subject0'} ],
		  [ 1, $text{'sched_subject1'} ],
		  [ 2, $text{'sched_subject2'},
			&ui_textbox("subject", $smode == 2 ? $config{'sched_subject'} : "", 40) ] ]), 3);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

