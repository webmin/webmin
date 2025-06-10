#!/usr/local/bin/perl
# Kill selected webmin processes that hold locks

require './webmin-lib.pl';
&error_setup($text{'kill_err'});
&ReadParse();

my @d = split(/\0/, $in{'d'});
@d || &error($text{'kill_enone'});

&ui_print_unbuffered_header(undef, $text{'kill_title'}, "");

my @locks = &list_active_locks();
my $sig = $in{'kill'} ? 'KILL' : 'TERM';
my %killed;
foreach my $pn (@d) {
	my ($pid, $n) = split(/\-/, $pn);
	print &text($in{'kill'} ? 'kill_pid' : 'term_pid', $pid),"<br>\n";
	my ($p) = grep { $_->{'pid'} == $pid } @locks;
	if (!$p) {
		print $text{'kill_gone'},"<p>\n";
		next;
		}
	my ($l) = grep { $_->{'num'} == $n } @{$p->{'locks'}};
	if (!$l) {
		print $text{'kill_gone2'},"<p>\n";
		next;
		}
	if ($killed{$pid}) {
		print &text('kill_already',
			"<tt>".&html_escape($lockfile)."</tt>"),"<p>\n";
		&unlink_file($lockfile);
		next;
		}
	my $done = kill($sig, $pid);
	my $lockfile = $l->{'lock'}.".lock";
	if ($done) {
		# Signal was sent, but did it really work?
		my $dead = 0;
		for(my $i=0; $i<5; $i++) {
			if (!kill(0, $pid)) {
				$dead = 1;
				last;
				}
			sleep(1);
			}
		my $args = $p->{'proc'}->{'args'};
		if ($dead) {
			print &text('kill_dead',
				"<tt>".&html_escape($args)."</tt>",
				"<tt>".&html_escape($lockfile)."</tt>"),"<p>\n";
			&unlink_file($lockfile);
			$killed{$pid}++;
			}
		else {
			print &text('kill_alive',
				"<tt>".&html_escape($args)."</tt>"),"<p>\n";
			}
		}
	else {
		print &text('kill_failed', $!,
			"<tt>".&html_escape($lockfile)."</tt>"),"<p>\n";
		&unlink_file($lockfile);
		}
	}

&ui_print_footer("edit_lock.cgi", $text{'lock_return'});
