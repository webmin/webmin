#!/usr/local/bin/perl
# view_log_progress.cgi
# Returns progressive output for some system log

require './logviewer-lib.pl';
&ReadParse();
&foreign_require("proc", "proc-lib.pl");

# Send headers
print "Content-Type: text/plain\n\n";

# Follow and reverse are mutually exclusive
my @systemctl_cmds;
{
	local $config{'reverse'} = 0;
	@systemctl_cmds = &get_systemctl_cmds(1);
}

# System log to follow
my ($log) = grep { $_->{'id'} eq $in{'idx'} } @systemctl_cmds;
if (!&can_edit_log($log) ||
	!$log->{'cmd'} ||
	$log->{'cmd'} !~ /^journalctl/) {
	print $text{'save_ecannot3'};
	exit;
	}

# Disable output buffering
$| = 1;

# No lines for real time logs
$log->{'cmd'} =~ s/\s+\-\-lines\s+\d+//;

# Show real time logs
$log->{'cmd'} .= " --follow";

# Add filter to the command if present
my $filter = $in{'filter'} ? quotemeta($in{'filter'}) : "";
if ($filter) {
	$log->{'cmd'} .= " --grep $filter";
	}

# Open a pipe to the journalctl command
my $pid = open(my $fh, '-|', $log->{'cmd'}) ||
	print &text('save_ecannot4', $log->{'cmd'}).": $!";

# Read and output the log
while (my $line = <$fh>) {
	print $line;
	}

# Clean up when done
close($fh);
