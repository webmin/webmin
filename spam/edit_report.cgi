#!/usr/local/bin/perl
# edit_report.cgi
# Display a form for editing the spam report text

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("report");
&ui_print_header($header_subtext, $text{'report_title'}, "");
$conf = &get_config();

print "$text{'report_desc'}<p>\n";
&start_form("save_report.cgi", $text{'report_header'});

if (&version_atleast(3.0)) {
	# New version can replace subject, from and to headers
	@rheader = &find("rewrite_header", $conf);
	foreach $h ("subject", "from", "to") {
		($hn) = grep { lc($_->{'words'}->[0]) eq $h } @rheader;
		print &ui_table_row($text{'report_r'.$h},
			&opt_field("rewrite_header_${h}",
				   $hn ? join(" ", @{$hn->{'words'}}[1..@{$hn->{'words'}}-1]) : undef, 15));
		}
	}
else {
	# Older versions can only replace subject header
	$rewrite = &find("rewrite_subject", $conf);
	print &ui_table_row($text{'report_rewrite'},
		&yes_no_field("rewrite_subject", $rewrite, 1));

	$subject = &find("subject_tag", $conf);
	print &ui_table_row($text{'report_subject'},
		&opt_field("subject_tag", $subject, 15, "*****SPAM*****"));
	$header = &find("report_header", $conf);
	# Include report in headers
	#print &ui_table_row($text{'report_rheader'},
	#	&yes_no_field("report_header", $header, 0));

	# Terse report mode
	$terse = &find("use_terse_report", $conf);
	print &ui_table_row($text{'report_useterse'},
		&yes_no_field("use_terse_report", $terse, 0));
	}


# Split status header?
$fold = &find("fold_headers", $conf);
print &ui_table_row($text{'report_fold'},
	&yes_no_field("fold_headers", $fold, 1));

# Include details of spam phrases
$detail = &find("detailed_phrase_score", $conf);
print &ui_table_row($text{'report_detail'},
	&yes_no_field("detailed_phrase_score", $detail, 0));

if (!&version_atleast(2.6)) {
	# Include stars header
	$stars = &find("spam_level_stars", $conf);
	print &ui_table_row($text{'report_stars'},
		&yes_no_field("spam_level_stars", $stars, 1));
	}

# Character for stars
# note: has to be replaced in save.cgi with add_header all Level _STARS(.)_ as of 2.6
$char = &find("spam_level_char", $conf);
print &ui_table_row($text{'report_char'},
	&opt_field("spam_level_char", $char, 2, "*"));

# Remove MIME blocks
$defang = &find("defang_mime", $conf);
print &ui_table_row($text{'report_defang'},
	&yes_no_field("defang_mime", $defang, 1));

if (&version_atleast(2.6)) {
	$safe = &find("report_safe", $conf);
	print &ui_table_row($text{'report_safe'},
		&option_field("report_safe", $safe, 1,
			      [ [ 0, $text{'no'} ],
				[ 1, $text{'yes'} ],
				[ 2, $text{'report_safe2'} ] ]));
	}

print &ui_table_hr();

# Extra report to attach to spam messages
@report = &find_value("report", $conf);
$clear = &find("clear_report_template", $conf);
print &ui_table_row($text{'report_report'},
	&ui_radio("clear_report", $clear ? 1 : 0,
		  [ [ 0, $text{'report_noclear'} ],
		    [ 1, $text{'report_clear'} ] ])."<br>\n".
	&ui_textarea("report", join("\n", @report), 5, 80));

# Extra report to attach to spam messages, for terse mode
# note terse report is deprecated in 2.6 and does nothing, will be removed in future
if (!&version_atleast(2.6)) {
	@report = &find_value("terse_report", $conf);
	$clear = &find("clear_terse_report_template", $conf);
	print &ui_table_row($text{'report_terse'},
		&ui_radio("clear_terse", $clear ? 1 : 0,
			  [ [ 0, $text{'report_noclear'} ],
				[ 1, $text{'report_clear'} ] ])."<br>\n".
		&ui_textarea("terse", join("\n", @report), 5, 80));
}

# Additional headers to add
if (&version_atleast(2.6)) {
	print &ui_table_hr();
	$table = &ui_columns_start([ $text{'report_addfor'},
				  $text{'report_addheader'},
				  $text{'report_addtext'} ]);
	$i = 0;
	foreach $a (&find_value("add_header", $conf), undef) {
		local ($for, $header, $text) = split(/\s+/, $a, 3);
		$table .= &ui_columns_row([
			&ui_select("addfor_$i", $for,
				   [ [ "", "&nbsp;" ],
				     map { [ $_, $text{'report_add'.$_} ] }
					 ( "spam", "ham", "all" ) ]),
			&ui_textbox("addheader_$i", $header, 30),
			&ui_textbox("addtext_$i", $text, 30)
				]);
		$i++;
		}
	$table .= &ui_columns_end();
	print &ui_table_row($text{'report_adds'}, $table);
	}


&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

