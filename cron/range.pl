#!/usr/local/bin/perl
# Only runs the specified cron job if within the date range
# XXX support in usermin

use Time::Local;

# Parse args
($start, $end, @cmd) = @ARGV;
$start && $end && scalar(@cmd) || die "usage: range.pl dd-mm-yyyy dd-mm-yyyy command ...";
$stime = &parse_date($start);
$stime || die "Invalid start date $start";
$etime = &parse_date($end);
$etime || die "Invalid ending date $end";

# Check time range (inclusive)
$now = time();
if ($now < $stime || $now >= $etime+24*60*60) {
	exit(0);
	}

# Run the rest
exec("/bin/sh", "-c", join(" ", @cmd));

sub parse_date
{
($d, $m, $y) = split(/\-/, $_[0]);
$y =~ /^\d+$/ && $m =~ /^\d+$/ && $d =~ /^\d+$/ || return undef;
return eval { timelocal(0, 0, 0, $d, $m-1, $y-1900) };
}

