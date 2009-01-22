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
		print "<tr> <td><b>",$text{'report_r'.$h},
		      "</b></td> <td nowrap>";
		($hn) = grep { lc($_->{'words'}->[0]) eq $h } @rheader;
		&opt_field("rewrite_header_${h}",
			   $hn ? join(" ", @{$hn->{'words'}}[1..@{$hn->{'words'}}-1]) : undef, 15);
		}
	}
else {
	# Older versions can only replace subject header
	print "<tr> <td><b>$text{'report_rewrite'}</b></td> <td nowrap>";
	$rewrite = &find("rewrite_subject", $conf);
	&yes_no_field("rewrite_subject", $rewrite, 1);
	print "</td> </tr>\n";

	print "<tr> <td><b>$text{'report_subject'}</b></td> <td nowrap>";
	$subject = &find("subject_tag", $conf);
	&opt_field("subject_tag", $subject, 15, "*****SPAM*****");
	print "</td> </tr>\n";
	}

print "<tr> <td><b>$text{'report_rheader'}</b></td> <td nowrap>";
$header = &find("report_header", $conf);
&yes_no_field("report_header", $header, 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'report_useterse'}</b></td> <td nowrap>";
$terse = &find("use_terse_report", $conf);
&yes_no_field("use_terse_report", $terse, 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'report_fold'}</b></td> <td nowrap>";
$fold = &find("fold_headers", $conf);
&yes_no_field("fold_headers", $fold, 1);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'report_detail'}</b></td> <td nowrap>";
$detail = &find("detailed_phrase_score", $conf);
&yes_no_field("detailed_phrase_score", $detail, 0);
print "</td> </tr>\n";

if (!&version_atleast(3.0)) {
	print "<tr> <td><b>$text{'report_stars'}</b></td> <td nowrap>";
	$stars = &find("spam_level_stars", $conf);
	&yes_no_field("spam_level_stars", $stars, 1);
	print "</td> </tr>\n";
	}

print "<tr> <td><b>$text{'report_char'}</b></td> <td nowrap>";
$char = &find("spam_level_char", $conf);
&opt_field("spam_level_char", $char, 2, "*");
print "</td> </tr>\n";

print "<tr> <td><b>$text{'report_defang'}</b></td> <td nowrap>";
$defang = &find("defang_mime", $conf);
&yes_no_field("defang_mime", $defang, 1);
print "</td> </tr>\n";

if (&version_atleast(2.6)) {
	print "<tr> <td><b>$text{'report_safe'}</b></td> <td nowrap>";
	$safe = &find("report_safe", $conf);
	#&yes_no_field("report_safe", $safe, 0);
	&option_field("report_safe", $safe, 1,
		      [ [ 0, $text{'no'} ],
			[ 1, $text{'yes'} ],
			[ 2, $text{'report_safe2'} ] ]);
	print "</td> </tr>\n";
	}

if (&version_atleast(3)) {
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	print "<tr> <td colspan=2><b>$text{'report_adds'}</b></td> </tr>\n";
	print "<tr> <td colspan=2>\n";
	print &ui_columns_start([ $text{'report_addfor'},
				  $text{'report_addheader'},
				  $text{'report_addtext'} ]);
	$i = 0;
	foreach $a (&find_value("add_header", $conf), undef) {
		local ($for, $header, $text) = split(/\s+/, $a, 3);
		print &ui_columns_row([
			&ui_select("addfor_$i", $for,
				   [ [ "", "&nbsp;" ],
				     map { [ $_, $text{'report_add'.$_} ] }
					 ( "spam", "ham", "all" ) ]),
			&ui_textbox("addheader_$i", $header, 30),
			&ui_textbox("addtext_$i", $text, 50)
				]);
		$i++;
		}
	print &ui_columns_end();
	print "</td> </tr>\n";
	}

print "<tr> <td colspan=4><hr></td> </tr>\n";

@report = &find_value("report", $conf);
$clear = &find("clear_report_template", $conf);
print "<tr> <td colspan=2><b>$text{'report_report'}</b></td> </tr>\n";
printf "<tr> <td colspan=2><input type=radio name=clear_report value=0 %s> %s\n",
	$clear ? "" : "checked", $text{'report_noclear'};
printf "<input type=radio name=clear_report value=1 %s> %s<br>\n",
	$clear ? "checked" : "", $text{'report_clear'};
print "<textarea name=report rows=5 cols=80>",
      join("\n", @report),"</textarea></td> </tr>\n";

@report = &find_value("terse_report", $conf);
$clear = &find("clear_terse_report_template", $conf);
print "<tr> <td colspan=2><b>$text{'report_terse'}</b></td> </tr>\n";
printf "<tr> <td colspan=2><input type=radio name=clear_terse value=0 %s> %s\n",
	$clear ? "" : "checked", $text{'report_noclear'};
printf "<input type=radio name=clear_terse value=1 %s> %s<br>\n",
	$clear ? "checked" : "", $text{'report_clear'};
print "<textarea name=terse rows=5 cols=80>",
      join("\n", @report),"</textarea></td> </tr>\n";

print "</tr>\n";

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

