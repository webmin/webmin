#!/usr/local/bin/perl
# edit_score.cgi
# Display a form for editing spam scoring options

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("score");
&ui_print_header($header_subtext, $text{'score_title'}, "");
$conf = &get_config();
@plugins = &list_spamassassin_plugins();

print "$text{'score_desc'}<p>\n";
&start_form("save_score.cgi", $text{'score_header'});

# Required score before considering spam
$hits_param = &version_atleast(3.0) ? "required_score" : "required_hits";
$hits = &find($hits_param, $conf);
$score_other="<br><small><tt>$text{'amavis_warn'}</tt><small>" if ($warn_procmail != 1);
print &ui_table_row($text{'score_hits'}.$score_other,
	&opt_field($hits_param, $hits, 5, "5"));

# Auto-whitelist factor
$auto = &find("auto_whitelist_factor", $conf);
print &ui_table_row($text{'score_auto'},
	&opt_field("auto_whitelist_factor", $auto, 5, "0.5"));

# Enable bayesian learning
$bayes = &find("use_bayes", $conf);
print &ui_table_row($text{'score_bayes'},
	&yes_no_field("use_bayes", $bayes, 1));

# MX check tries
$mx = &find("check_mx_attempts", $conf);
print &ui_table_row($text{'score_mx'},
	&opt_field("check_mx_attempts", $mx, 4, "2"));

# Delay between MX checks
$mxdelay = &find("check_mx_delay", $conf);
print &ui_table_row($text{'score_mxdelay'},
	&opt_field("check_mx_delay", $mxdelay, 4, "2"));

# Check RBLs?
$rbl = &find("skip_rbl_checks", $conf);
print &ui_table_row($text{'score_rbl'},
	&yes_no_field("skip_rbl_checks", $rbl, 0));

# RBL timeout
$timeout = &find("rbl_timeout", $conf);
print &ui_table_row($text{'score_timeout'},
	&opt_field("rbl_timeout", $timeout, 5, "30"));

# Received headers to check
$received = &find("num_check_received", $conf);
print &ui_table_row($text{'score_received'},
	&opt_field("num_check_received", $received, 5, 2));

# Trusted networks
@trusted = &find_value("trusted_networks", $conf);
print &ui_table_row($text{'score_trusted'},
	&ui_textarea("trusted_networks", join("\n", @trusted), 5, 70));

if (&indexof("Mail::SpamAssassin::Plugin::TextCat", @plugins) >= 0) {
	print &ui_table_hr();

	# Acceptable languages
	@langs = &find_value("ok_languages", $conf);
	%langs = map { $_, 1 } split(/\s+/, join(" ", @langs));
	$lmode = !@langs ? 2 : $langs{'all'} ? 1 : 0;
	delete($langs{'all'});
	print &ui_table_row($text{'score_langs'},
		&ui_radio("langs_def", $lmode,
			  [ [ 2, $text{'default'}.
				 " (".$text{'score_langsall'}.")" ],
			    [ 1, $text{'score_langsall'} ],
			    [ 0, $text{'score_langssel'} ] ])."<br>\n".
		&ui_select("langs", [ keys %langs ],
			   [ &list_spamassassin_languages() ], 10, 1, 1));

	# Acceptable locales
	@locales = &find_value("ok_locales", $conf);
	%locales = map { $_, 1 } split(/\s+/, join(" ", @locales));
	$lmode = !@locales ? 2 : $locales{'all'} ? 1 : 0;
	delete($locales{'all'});
	print &ui_table_row($text{'score_locales'},
		&ui_radio("locales_def", $lmode,
			  [ [ 2, $text{'default'}.
				 " (".$text{'score_localesall'}.")" ],
			    [ 1, $text{'score_localesall'} ],
			    [ 0, $text{'score_localessel'} ] ])."<br>\n".
		&ui_select("locales", [ keys %locales ],
			   [ &list_spamassassin_locales() ], 5, 1, 1));
	}

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

