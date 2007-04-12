#!/usr/local/bin/perl
# cron.pl
# Run a command on multiple servers at once

$no_acl_check++;
require './cluster-copy-lib.pl';

$copy = &get_copy($ARGV[0]);
$copy || die "Copy ID $ARGV[0] does not exist!";
$ENV{'SERVER_ROOT'} = $root_directory;	# hack to make 'this server' work
$status = "succeeded";
&run_cluster_job($copy, \&callback);

if ($copy->{'email'}) {
	# Email off status message
	&foreign_require("mailboxes", "mailboxes-lib.pl");

	# Construct and send the email
	local $from = $config{'from'} || &mailboxes::get_from_address();
	local @files = split(/\t+/, $copy->{'files'});
	local $subject = &text('email_subject_'.$status, join(", ", @files));
	&mailboxes::send_text_mail($from, $copy->{'email'}, undef, $subject,
				   $results);
	}

# callback(error, &server, message, dirs, command-output)
sub callback
{
local $d = $_[1]->{'desc'} || $_[1]->{'host'};
if (!$_[0]) {
	# Failed - show error
	$results .= &text('exec_on', $d, $_[2])."\n\n";
	$status = "failed";
	}
else {
	if ($_[6]) {
		# Show pre command output
		$results .= &text('exec_before', $d)."\n";
		$results .= $_[6];
		$results .= "\n";
		}
	if (@{$_[4]}) {
		# Show created directories
		$results .= &text('exec_made', $d)."\n";
		foreach $f (@{$_[4]}) {
			$results .= "    $f\n";
			}
		$results .= "\n";
		}
	if (!@{$_[2]}) {
		# Nothing copied
		$results .= &text('exec_nothing', $d)."\n";
		}
	else {
		# Show output if any
		$results .= &text('exec_success', $d)."\n";
		foreach $f (@{$_[2]}) {
			$results .= "    $f\n";
			}
		$results .= "\n";
		}
	if (@{$_[3]}) {
		# Show error files
		$results .= &text('exec_not', $d)."\n";
		foreach $f (@{$_[3]}) {
			$results .= "    $f->[0] : $f->[1]\n";
			}
		$results .= "\n";
		}
	if ($_[5]) {
		# Show post command output
		$results .= &text('exec_cmd', $d)."\n";
		$results .= $_[5];
		$results .= "\n";
		}
	}
}

