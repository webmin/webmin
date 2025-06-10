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
	print &text('amavis_econfig',
		"<tt>$amavis_cf</tt>",
		"../config.cgi?$module_name"),"<p>\n";
	&ui_print_footer($redirect_url, $text{'index_return'});
	exit
	}

$conf = &get_amavis_config();

print &text('amavisd_desc'),"<p>\n";

# tabbed interface for config and quaratine
@tabs=(['config', $text{'amavis_tab_config'}], [ 'quarantine', $text{'amavis_tab_quarantine'} ]);
print &ui_tabs_start(\@tabs, 'mode','config');

# Find the existing config
print &ui_tabs_start_tab("mode", "config");
&start_form("save_amavisd.cgi", $text{'score_header'});

# spam tag2 level, when is classiefied as spam
$hits = &amavis_find('sa_tag2_level_deflt', $conf);
print &ui_table_row($text{'amavis_hits'},
	&opt_field('sa_tag2_level_deflt', $hits, 5, "undef"));

# amavis quarantine spam level
$hits = &amavis_find('sa_kill_level_deflt', $conf);
print &ui_table_row($text{'amavis_quarantine_level'},
	&opt_field('sa_kill_level_deflt', $hits, 5, "undef"));

# amavis no DSN spam level
$hits = &amavis_find('sa_dsn_cutoff_level', $conf);
print &ui_table_row($text{'amavis_dsn_level'},
	&opt_field('sa_dsn_cutoff_level', $hits, 5, "undef"));

# amavis delete spam level
$hits = &amavis_find('sa_quarantine_cutoff_level', $conf);
print &ui_table_row($text{'amavis_delete_level'},
	&opt_field('sa_quarantine_cutoff_level', $hits, 5, "undef"));

print &ui_table_hr();
# should amavis rewrite subject
$rewrite = &amavis_find('sa_spam_modifies_subj', $conf);
print &ui_table_row($text{'amavis_rewrite'},
	&yes_no_field('sa_spam_modifies_subj', $rewrite, "undef"));

# do how to modify subject 
$hits = &amavis_find('sa_spam_subject_tag', $conf);
print &ui_table_row($text{'amavis_rsubject'},
	&opt_field('sa_spam_subject_tag', $hits, 9, "undef"));

# insert X-Spam header 
$hits = &amavis_find('sa_spam_report_header', $conf);
print &ui_table_row($text{'amavis_report_header'},
	&yes_no_field('sa_spam_report_header', $hits, 0));

# character to use for spam level 
$hits = &amavis_find('sa_spam_level_char', $conf);
print &ui_table_row($text{'amavis_level_char'},
	&opt_field('sa_spam_level_char', $hits, 2, "*"));

# network checks enabled?
$rewrite = &amavis_find('sa_local_tests_only', $conf);
print &ui_table_row($text{'amavis_local_only'},
	&yes_no_field('sa_local_tests_only', $rewrite, 0));

# do not check mail larger then
$hits = &amavis_find('sa_mail_body_size_limit', $conf);
print &ui_table_row($text{'amavis_size_limit'},
	&opt_field('sa_mail_body_size_limit', $hits, 9, "undef"));


&end_form(undef, $text{'amavis_ok'});
print &ui_tabs_end_tab("mode", "config");

# list quarantine
print &ui_tabs_start_tab("mode", "quarantine");
print &ui_table_start($text{'amavis_tab_quarantine'}, "width=100%", 2);

# get amavids.conf values
$dir=&amavis_find_value('QUARANTINEDIR', $conf);
$to=&amavis_find_value('spam_quarantine_to', $conf);
$method=&amavis_find_value('spam_quarantine_method', $conf);
$admin=&amavis_find_value('spam_admin', $conf);
$admin=&amavis_find_value('daemon_user', $conf)."@".&amavis_find_value('myhostname', $conf) if (!$admin);

print &ui_table_span($text{'amavis_quarantine_desc'}."<p>");

print &ui_table_row($text{'amavis_spam_admin'}, $admin);

if (!$to && $method =~ /^local:/) {
	print &ui_table_span("<br><b>".&text('amavis_quarantine_off', $config{'amavisdconf'})."</b>");
	print &ui_table_hr();
	print &ui_table_span("<b>".$text{'amavis_nostat'}."</b>");
} else {
    if ($to =~ /@/) {
	# spam is forwarded to mail adress
	print &ui_table_row($text{'amavis_quarantine_mail'}, $to);
	print &ui_table_hr();
	print &ui_table_span("<b>".$text{'amavis_nostat'}."</b>");
    } else {
	if ($method =~ s/^bsmtp://) {
	    # spam is quarantined in bsmtp format
	    $method =~ s/\%.*$/*/;
	    print &ui_table_row($text{'amavis_quarantine_bsmtp'}, $dir."/".$method);
	} else {
	    # spam is qurantined local
	    $method =~ s/^local:(.*?)\%.*$/\1*/;
	    print &ui_table_row($text{'amavis_quarantine_local'}, $dir."/".$method);
	}
	# display spamstat ...
	print &ui_table_hr();
	print &ui_table_row($text{'amavis_quarantine_total'},&backquote_command("ls $dir/$method| wc -l"));
	print &ui_table_row($text{'amavis_quarantine_today'},&backquote_command("find $dir/$method -ctime -1| wc -l"));
	print &ui_table_row($text{'amavis_quarantine_week'},&backquote_command("find $dir/$method -ctime -7| wc -l"));
	print &ui_table_row($text{'amavis_quarantine_month'},&backquote_command("find $dir/$method -ctime -30| wc -l"));
    }
}

print &ui_table_end();
print &ui_tabs_end_tab("mode", "quarantine");

#end tabbed interface
print &ui_tabs_end(1);

&ui_print_footer($redirect_url, $text{'index_return'});

