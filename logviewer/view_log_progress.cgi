#!/usr/local/bin/perl
# view_log_progress.cgi
# Returns progressive output for some system log

require './logviewer-lib.pl';
&ReadParse();
&foreign_require("proc", "proc-lib.pl");

# System log to follow
my @systemctl_cmds = &get_systemctl_cmds(1);
my ($log) = grep { $_->{'id'} eq $in{'idx'} } @systemctl_cmds;
my $cmd = $log->{'cmd'};

# Disable output buffering
print "Content-Type: text/plain\n\n";
$| = 1;

# Access check
if (!$cmd || $cmd !~ /^journalctl/ ||
    !(&can_edit_log($log) && $access{'syslog'})) {
    print $text{'save_ecannot3'};
    exit;
    }

# No lines for real time logs
$cmd =~ s/\s+\-n\s+\d+//;

# Show real time logs
$cmd .= " -f";

# Add filter to the command if present
my $filter = $in{'filter'} ? quotemeta($in{'filter'}) : "";
if ($filter) {
    $cmd .= " -g $filter";
    }

# Open a pipe to the journalctl command
my $pid = open(my $fh, '-|', "$cmd") ||
    print &text('save_ecannot4', $cmd).": $!";

# Read and output the log
while (my $line = <$fh>) {
    print $line;
    }

# Clean up when done
close($fh);
