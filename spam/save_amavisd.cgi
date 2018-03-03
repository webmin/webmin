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
# Save inputs


# Check inputs
&check_amavis_value($in{'sa_tag2_level_deflt'}, 1) ||
	&error($text{'amavis_ehit'});
&check_amavis_value($in{'sa_kill_level_deflt'}, 1) ||
	&error($text{'amavis_ekill'});
&check_amavis_value($in{'sa_quarantine_cutoff_level'}, 1) ||
	&error($text{'amavis_ecut'});
&check_amavis_value($in{'sa_spam_report_header'}, 1) ||
	&error($text{'amavis_eheader'});
&check_amavis_value($in{'sa_mail_body_size_limit'}, 1) ||
	&error($text{'amavis_esize'});
&check_amavis_value($in{'sa_local_tests_only'}, 1) ||
	&error($text{'amavis_elocal'});

# Save inputs
&save_amavis_directive($conf, 'sa_tag2_level_deflt', $in{'sa_tag2_level_deflt'});
&save_amavis_directive($conf, "sa_kill_level_deflt", $in{'sa_kill_level_deflt'});
&save_amavis_directive($conf, "sa_quarantine_cutoff_level", $in{'sa_quarantine_cutoff_level'});
&save_amavis_directive($conf, "sa_spam_modifies_subj", $in{'sa_spam_modifies_subj'});
&save_amavis_directive($conf, "sa_spam_subject_tag", $in{'sa_spam_subject_tag'});
&save_amavis_directive($conf, "sa_spam_report_header", $in{'sa_spam_report_header'});
&save_amavis_directive($conf, "sa_mail_body_size_limit", $in{'sa_mail_body_size_limit'});
&save_amavis_directive($conf, "sa_local_tests_only", $in{'sa_local_tests_only'});

&flush_file_lines();
&unlock_file($config{'amavisdconf'});
&webmin_log("spam-amavis", undef, undef, \%in);


&redirect($redirect_url);
