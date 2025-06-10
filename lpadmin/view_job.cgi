#!/usr/local/bin/perl
# view_job.cgi
# View an existing print job

require './lpadmin-lib.pl';
&ReadParse();

@jobs = &get_jobs($in{'name'});
foreach $j (@jobs) {
	$job = $j if ($j->{'id'} eq $in{'id'});
	}
($ju = $j->{'user'}) =~ s/\!.*$//;
&can_edit_jobs($in{'name'}, $ju) || &error($text{'view_ecannot'});
if ($job) {
	# print job exists.. dump it
	@pf = @{$job->{'printfile'}};
	$type = &backquote_command("file ".quotemeta($pf[0]), 1);
	if ($type =~ /postscript/i) {
		print "Content-type: application/postscript\n";
		}
	elsif ($type =~ /text/) {
		print "Content-type: text/plain\n";
		}
	else {
		print "Content-type: application/octet-stream\n";
		}
	foreach $pf (@pf) {
		@st = stat($pf);
		$total += $st[7];
		}
	print "Content-length: $total\n";
	print "\n";
	foreach $pf (@pf) {
		open(FILE, "<$pf");
		while(<FILE>) { print; }
		close(FILE);
		}
	}
else {
	&error(&text('view_egone', $in{'id'}));
	}

