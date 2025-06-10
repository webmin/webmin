#!/usr/local/bin/perl
# exec.cgi
# Run the cron job on all configured servers

require './cluster-copy-lib.pl';
&ReadParse();
&ui_print_unbuffered_header(undef, $text{'exec_title'}, "");

# Run on all servers and show output
$copy = &get_copy($in{'id'});
@files = split(/\t+/, $copy->{'files'});
$under = $copy->{'dest'} eq "/" ? "" :
		&text('exec_under', "<tt>$copy->{'dest'}</tt>");
if (@files > 3) {
	print &text('exec_files1', scalar(@files), $under),"<p>\n";
	}
else {
	print &text('exec_files2',
		    join(", ", map { "<tt>$_</tt>" } @files), $under),"<p>\n";
	}
@run = &run_cluster_job($copy, \&callback);
if (!@run) {
	print "$text{'exec_nohosts'}<p>\n";
	}

&webmin_log("exec", "copy", undef, $copy);

&ui_print_footer("edit.cgi?id=$in{'id'}", $text{'edit_return'},
	"", $text{'index_return'});

# callback(error, &server, message, dirs, command-output, before-output)
sub callback
{
local $d = $_[1]->{'desc'} || $_[1]->{'host'};
if (!$_[0]) {
	# Failed - show error
	print "<b>",&text('exec_failed', $d, $_[2]),"</b><p>\n";
	}
else {
	if ($_[6]) {
		# Show before command output
		print "<b>",&text('exec_before', $d),"</b><br>\n";
		print "<tt>",join("<br>", &mailboxes::wrap_lines($_[6], 80)),
		      "</tt><p>\n";
		}
	if (@{$_[4]}) {
		# Show created directories
		print "<b>",&text('exec_made', $d),"</b><br><ul>\n";
		foreach $f (@{$_[4]}) {
			print "<tt>$f</tt><br>\n";
			}
		print "</ul><p>\n";
		}
	if (!@{$_[2]}) {
		# Nothing copied
		print "<b>",&text('exec_nothing', $d),"</b><p>\n";
		}
	else {
		# Show copied files
		print "<b>",&text('exec_success', $d),"</b><br><ul>\n";
		foreach $f (@{$_[2]}) {
			print "<tt>$f</tt><br>\n";
			}
		print "</ul><p>\n";
		}
	if (@{$_[3]}) {
		# Show failed files
		print "<b>",&text('exec_not', $d),"</b><br><ul>\n";
		foreach $f (@{$_[3]}) {
			print "<tt>$f->[0]</tt> : $f->[1]<br>\n";
			}
		print "</ul><p>\n";
		}
	if ($_[5]) {
		# Show after command output
		print "<b>",&text('exec_cmd', $d),"</b><br>\n";
		print "<tt>",join("<br>", &mailboxes::wrap_lines($_[5], 80)),
		      "</tt><p>\n";
		}
	}
}

