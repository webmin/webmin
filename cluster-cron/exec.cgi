#!/usr/local/bin/perl
# exec.cgi
# Run the cron job on all configured servers

require './cluster-cron-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'exec_title'}, "");

# Run on all servers and show output
@jobs = &list_cluster_jobs();
($job) = grep { $_->{'cluster_id'} eq $in{'id'} } @jobs;
print &text('exec_cmd', "<tt>$job->{'cluster_command'}</tt>"),"<p>\n";
@run = &run_cluster_job($job, \&callback);
if (!@run) {
	print "$text{'exec_nohosts'}<p>\n";
	}

$job->{'run'} = [ map { $_->{'host'} } @run ];	# for logging
&webmin_log("exec", "cron", $job->{'cluster_user'}, $job);

&ui_print_footer("edit.cgi?id=$in{'id'}", $cron::text{'edit_return'},
	"", $text{'index_return'});

# callback(error, &server, message)
sub callback
{
local $d = ($_[1]->{'host'} || &get_system_hostname()).
	   ($_[1]->{'desc'} ? " ($_[1]->{'desc'})" : "");
if (!$_[0]) {
	# Failed - show error
	print "<b>",&text('exec_failed', $d, $_[2]),"</b><p>\n";
	}
else {
	# Show output if any
	print "<b>",&text('exec_success', $d),"</b>\n";
	if ($_[2]) {
		print "<ul><pre>$_[2]</pre></ul><p>\n";
		}
	else {
		print "<br><ul><i>$cron::text{'exec_none'}</i></ul><p>\n";
		}
	}
}

