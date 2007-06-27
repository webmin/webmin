#!/usr/local/bin/perl
# Show a form for running one backup job

require './bacula-backup-lib.pl';
&ui_print_header(undef,  $text{'backup_title'}, "", "backup");

print &ui_form_start("backup.cgi", "post");
print &ui_table_start($text{'backup_header'}, undef, 2);

# Job to run
@jobs = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
	     grep { !&is_oc_object($_) } &get_bacula_jobs();
print &ui_table_row($text{'backup_job'},
    &ui_select("job", undef,
	       [ map { [ $_->{'name'}, &text('backup_jd', $_->{'name'}, $_->{'fileset'}, $_->{'client'}) ] } @jobs ]));

# Wait for completion?
print &ui_table_row($text{'backup_wait'},
		    &ui_yesno_radio("wait", $config{'wait'}));

print &ui_table_end();
print &ui_form_end([ [ "backup", $text{'backup_ok'} ] ]);

&ui_print_footer("", $text{'index_return'});
