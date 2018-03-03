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
#$in{'whereami'} =~ /^[A-z0-9\-\.]+$/ ||
#	&error($text{'global_ewhereami'});
#$in{'whoami'} =~ /^\S+$/ ||
#	&error($text{'global_ewhoami'});
#$in{'whoami_owner'} =~ /^\S+$/ ||
#	&error($text{'global_eowner'});
#-x $in{'sendmail_command'} ||
#	&error(&text('global_esendmail', "<tt>$in{'sendmail_command'}</tt>"));

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
