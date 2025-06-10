#!/usr/local/bin/perl
# save_amavis.cgi
# Save message amavis options

require './spam-lib.pl';
require './spam-amavis-lib.pl';
&error_setup($text{'score_err'});
&ReadParse();
&can_use_check("amavisd");
$conf = &get_amavis_config();
&lock_file($config{'amavisdconf'});

# check for default values
local $tag2=$in{'sa_tag2_level_deflt'};
$tag2="undef" if ($in{'sa_tag2_level_deflt_def'}==1);
local $kill=$in{'sa_kill_level_deflt'};
$kill="undef" if ($in{'sa_kill_level_deflt_def'}==1);
local $dsn=$in{'sa_dsn_cutoff_level'};
$dsn="undef" if ($in{'sa_dsn_cutoff_level_def'}==1);
local $cut=$in{'sa_quarantine_cutoff_level'};
$cut="undef" if ($in{'sa_quarantine_cutoff_level_def'}==1);
local $subj=$in{'sa_spam_modifies_subj'};
$subj=0 if ($in{'a_spam_modifies_subj'}==-1);
local $subtag=$in{'sa_spam_subject_tag'};
$subtag="undef" if ($in{'sa_spam_subject_tag_def'}==1);
local $head=$in{'sa_spam_report_header'};
$head=0 if ($in{'sa_spam_report_header'}==-1);
local $char=$in{'sa_spam_level_char'};
$char="*" if ($in{'sa_spam_level_char_def'}==1);
local $size=$in{'sa_mail_body_size_limit'};
$size="undef" if ($in{'sa_mail_body_size_limit_def'}==1);
local $local=$in{'sa_local_tests_only'};
$local=0 if ($in{'sa_local_tests_only'}==-1);


# Check inputs
&check_amavis_value($tag2, 1) ||
	&error($text{'amavis_ehit'});
&check_amavis_value($kill, 1) ||
	&error($text{'amavis_ekill'});
&check_amavis_value($dsn, 1) ||
	&error($text{'amavis_edsn'});
&check_amavis_value($cut, 1) ||
	&error($text{'amavis_ecut'});
&check_amavis_value($subj, 1) ||
	&error($text{'amavis_esubject'});
&check_amavis_value($head, 1) ||
	&error($text{'amavis_eheader'});
&check_amavis_value($size, 1) ||
	&error($text{'amavis_esize'});
&check_amavis_value($size, 1) ||
	&error($text{'amavis_elocal'});
&error($text{'amavis_echar'}) if (length($char) != 1);

# Save inputs
&save_amavis_directive($conf, 'sa_tag2_level_deflt', $tag2);
&save_amavis_directive($conf, "sa_kill_level_deflt", $kill);
&save_amavis_directive($conf, "sa_dsn_cutoff_level", $dsn);
&save_amavis_directive($conf, "sa_quarantine_cutoff_level", $cut);
&save_amavis_directive($conf, "sa_spam_modifies_subj", $subj);
&save_amavis_directive($conf, "sa_spam_subject_tag", $subtag);
&save_amavis_directive($conf, "sa_spam_report_header", $head);
&save_amavis_directive($conf, "sa_spam_level_char", $char);
&save_amavis_directive($conf, "sa_mail_body_size_limit", $size);
&save_amavis_directive($conf, "sa_local_tests_only", $local);

&flush_file_lines();
&unlock_file($config{'amavisdconf'});
&webmin_log("spam-amavis", undef, undef, \%in);


&redirect($redirect_url);
