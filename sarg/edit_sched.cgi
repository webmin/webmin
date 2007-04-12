#!/usr/local/bin/perl
# Show schedule form

require './sarg-lib.pl';
&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
($job) = grep { $_->{'user'} eq 'root' &&
		$_->{'command'} eq $cron_cmd } @jobs;

$conf = &get_config();
$odir = &find_value("output_dir", $conf);
$sfile = &find_value("access_log", $conf);
&ui_print_header(undef, $text{'sched_title'}, "");

if (!$odir) {
	&ui_print_endpage(&text('sched_edir', "edit_log.cgi"));
	}
elsif (!$sfile) {
	&ui_print_endpage(&text('sched_esfile', "edit_log.cgi"));
	}

print &ui_form_start("save_sched.cgi", "post");
print &ui_table_start($text{'sched_header'}, "width=100%", 4);

print &ui_table_row($text{'sched_sched'},
		    &ui_radio("sched", $job ? 1 : 0,
			      [ [ 0, $text{'no'} ],
				[ 1, $text{'sched_yes'} ] ]), 3);

print &ui_table_row($text{'sched_dir'},
		    "<tt>$odir</tt>", 3);

print &ui_table_row($text{'sched_clear'}, &gen_clear_input(), 3);

print &ui_table_row($text{'sched_range'}, &gen_range_input(), 3);

print "<tr> <td colspan=4><table border width=100%>\n";
&cron::show_times_input($job || { 'special' => 'daily' });
print "</table></td></tr>\n";

print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} ] ], "100%");
&ui_print_footer("", $text{'index_return'});

