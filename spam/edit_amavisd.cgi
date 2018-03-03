#!/usr/local/bin/perl
# Allow changing of the rule for delivering spam

require './spam-lib.pl';
require './spam-amavis-lib.pl';
&ReadParse();
&can_use_check("amavisd");
&ui_print_header(undef, $text{'amavisd_title'}, "");
	
my $amavis_cf=$config{'amavisdconf'};
$amavis_cf=$text{'index_unknown'} if (!$amavis_cf);
if (!-r $amavis_cf ) {
	# Config not found
	print &text('index_aconfig',
		"<tt>$amavis_cf</tt>",
		"../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer($redirect_url, $text{'index_return'});
	exit
	}

$conf = &get_amavis_config();

print &text('amavisd_desc'),"<p>\n";

# Find the existing config
&start_form("save_amavisd.cgi", $text{'score_header'});

# spam tag2 level, when is classiefied as spam
$hits = &amavis_find('sa_tag2_level_deflt', $conf);
print &ui_table_row($text{'score_hits'},
	&opt_field('sa_tag2_level_deflt', $hits, 7, "6.5"));

# amavis quarantine spam level
$hits = &amavis_find('sa_kill_level_deflt', $conf);
print &ui_table_row($text{'amavis_quarantine_level'},
	&opt_field('sa_kill_level_deflt', $hits, 7, "6.5"));

# amavis delete spam level
$hits = &amavis_find('sa_quarantine_cutoff_level', $conf);
print &ui_table_row($text{'amavis_delete_level'},
	&opt_field('sa_quarantine_cutoff_level', $hits, 5, "undef"));

print &ui_table_hr();
# should amavis rewrite subject
$rewrite = &amavis_find('sa_spam_modifies_subj', $conf);
print &ui_table_row($text{'report_rewrite'},
	&yes_no_field('sa_spam_modifies_subj', $rewrite, 0));

# do how to modify subject 
$hits = &amavis_find('sa_spam_subject_tag', $conf);
print &ui_table_row($text{'report_rsubject'},
	&opt_field('sa_spam_subject_tag', $hits, 9, "undef"));

# insert X-Spam header 
$hits = &amavis_find('sa_spam_report_header', $conf);
print &ui_table_row($text{'amavis_add_header'},
	&yes_no_field('sa_spam_report_header', $hits, 0));

# do not check mail larger then
$hits = &amavis_find('sa_mail_body_size_limit', $conf);
print &ui_table_row($text{'amavis_size_limit'},
	&opt_field('sa_mail_body_size_limit', $hits, 9, "undef"));

# network checks enabled?
$rewrite = &amavis_find('sa_local_tests_only', $conf);
print &ui_table_row($text{'amavis_local_tests_only'},
	&yes_no_field('sa_local_tests_only', $rewrite, 0));



&end_form(undef, $text{'amavisd_ok'});

&ui_print_footer($redirect_url, $text{'index_return'});

