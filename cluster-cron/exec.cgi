#!/usr/local/bin/perl
# exec.cgi
# Run the cron job on all configured servers

require './cluster-cron-lib.pl';
&ReadParse();

&ui_print_unbuffered_header(undef, $text{'exec_title'}, "");

# Run on all servers and show output
@jobs = &list_cluster_jobs();
($job) = grep { $_->{'cluster_id'} eq $in{'id'} } @jobs;
$job || &error($text{'edit_emissing'});
print &text('exec_cmd', "<tt>$job->{'cluster_command'}</tt>"),"<p>\n";
@run = &run_cluster_job($job, \&callback);
if (!@run) {
	print "$text{'exec_nohosts'}<p>\n";
	}

$job->{'run'} = [ map { $_->{'host'} } @run ];	# for logging
&webmin_log("exec", "cron", $job->{'cluster_user'}, $job);

&ui_print_footer("edit.cgi?id=$in{'id'}", $cron::text{'edit_return'},
	"", $text{'index_return'});

# callback(ok, &server, message)
# Called back to print results for each host the job is run on
sub callback
{
my ($ok, $s, $msg) = @_;
my $d = ($s->{'host'} || &get_system_hostname()).
	($s->{'desc'} ? " ($s->{'desc'})" : "");
if (!$ok) {
	# Failed - show error
	print "<b>",&text('exec_failed', $d, &html_escape($msg)),"</b><p>\n";
	}
else {
	# Show output if any
	print "<b>",&text('exec_success', $d),"</b>\n";
	if ($ok) {
		print "<ul><pre>",&html_escape($msg),"</pre></ul><p>\n";
		}
	else {
		print "<br><ul><i>$cron::text{'exec_none'}</i></ul><p>\n";
		}
	}
}

