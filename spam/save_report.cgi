#!/usr/local/bin/perl
# save_report.cgi
# Save report generation options

require './spam-lib.pl';
&error_setup($text{'report_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("report");
&execute_before("report");
&lock_spam_files();
$conf = &get_config();

&save_directives($conf, 'clear_report_template',
		$in{'clear_report'} ? [ "" ] : [ ], 1);
$in{'report'} =~ s/\r//g;
@report = split(/\n/, $in{'report'});
&save_directives($conf, 'report', \@report, 1);

&save_directives($conf, 'clear_terse_report_template',
		$in{'clear_terse'} ? [ "" ] : [ ], 1);
$in{'terse'} =~ s/\r//g;
@terse = split(/\n/, $in{'terse'});
&save_directives($conf, 'terse_report', \@terse, 1);

if (&version_atleast(3.0)) {
	foreach $h ("subject", "from", "to") {
		if (!$in{"rewrite_header_${h}_def"}) {
			push(@rheader, { 'name' => 'rewrite_header',
			    'value' => $h." ".$in{"rewrite_header_${h}"} });
			}
		}
	&save_directives($conf, "rewrite_header", \@rheader);
	}
else {
	&parse_yes_no($conf, "rewrite_subject");
	&parse_opt($conf, "subject_tag", undef);
	#&parse_yes_no($conf, "report_header");
	&parse_yes_no($conf, "use_terse_report");
	&parse_yes_no($conf, "spam_level_stars");
	&parse_opt($conf, "spam_level_char", \&char_check);
	}
&parse_yes_no($conf, "fold_headers");
&parse_yes_no($conf, "detailed_phrase_score");
&parse_yes_no($conf, "defang_mime");
&parse_option($conf, "report_safe") if (defined($in{'report_safe'}));

if (&version_atleast(2.6)) {
	for($i=0; defined($addfor = $in{"addfor_$i"}); $i++) {
		next if (!$addfor);
		$addheader = $in{"addheader_$i"};
		$addtext = $in{"addtext_$i"};
		$addheader =~ /^\S+$/ ||
			&error(&text('report_eaddheader', $i+1));
		push(@adds, "$addfor $addheader $addtext");
		}
	if (!in{"spam_level_char_def"} && &char_check($in{"spam_level_char"})) {
		push(@adds, "all Level _STARS(".$in{ "spam_level_char"} .")_" );
		}
	&save_directives($conf, "add_header", \@adds, 1);
	}

&flush_file_lines();
&unlock_spam_files();
&webmin_log("report");
&execute_after("report");
&redirect($redirect_url);

sub char_check
{
$_[0] =~ /^\S$/ || &error($text{'report_echar'});
}

