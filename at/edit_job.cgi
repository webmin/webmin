#!/usr/local/bin/perl
# edit_job.cgi
# Display a command for deletion
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './at-lib.pl';
&ReadParse();
my @jobs = &list_atjobs();
my ($job) = grep { $_->{'id'} eq $in{'id'} } @jobs;
$job || &error($text{'edit_ejob'});
&can_edit_user(\%access, $job->{'user'}) || &error($text{'edit_ecannot'});

&ui_print_header(undef, $text{'edit_title'}, "");

print &ui_form_start("delete_job.cgi");
print &ui_hidden("id", $in{'id'});
print &ui_table_start($text{'edit_header'}, "width=100%", 4);

# Run as user
my @uinfo = getpwnam($job->{'user'});
$uinfo[6] =~ s/,.*$//g;
print &ui_table_row($text{'index_user'},
	&html_escape($job->{'user'}).
	($uinfo[6] ? " (".&html_escape($uinfo[6]).")" : ""), 3);

# When to run
print &ui_table_row($text{'index_exec'}, &make_date($job->{'date'}));

# When created
print &ui_table_row($text{'index_created'}, &make_date($job->{'created'}));

if ($in{'full'}) {
	# Full command
	print &ui_table_row($text{'edit_cmd'},
		"<pre>".&html_escape(
		    join("\n", &wrap_lines($job->{'cmd'}, 80)))."</pre>", 3);
	}
else {
	# Just the short command
	print &ui_table_row($text{'edit_shortcmd'},
		"<pre>".&html_escape(
		    join("\n", &wrap_lines($job->{'realcmd'}, 80)))."</pre>".
		&ui_link("edit_job.cgi?full=1&id=".&urlize($in{'id'}), $text{'edit_showfull'}), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ "run", $text{'edit_run'} ],
		     [ undef, $text{'edit_delete'} ] ]);

print "</table></td></tr></table></form>\n";
&ui_print_footer("", $text{'index_return'});

