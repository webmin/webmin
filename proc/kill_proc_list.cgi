#!/usr/local/bin/perl
# kill_proc_list.cgi
# Send a signal to a list of process

require './proc-lib.pl';
&ReadParse();
&switch_acl_uid();
foreach $s ('KILL', 'TERM', 'HUP', 'STOP', 'CONT') {
	$in{'signal'} = $s if ($in{$s});
	}

&ui_print_unbuffered_header(undef, $text{'proc_kill'}, "");

@pidlist = split(/\s+/, $in{'pidlist'});
@pinfo = &list_processes(@pidlist);
for($i=0; $i<@pinfo; $i++) {
	my $p = $pinfo[$i];
	$in{"args$i"} = $p->{'args'};
	print "$text{'pid'} <tt>".&html_escape($p->{'pid'})."</tt> ... \n";
	if (&can_edit_process($p->{'user'})) {
		if (&kill_logged($in{'signal'}, $p->{'pid'})) {
			print "SIG".&html_escape($in{'signal'})." $text{'kill_sent'}<br>\n";
			}
		else {
			print "$!<br>\n";
			}
		}
	else {
		print "$text{'kill_ecannot'}<br>\n";
		}
	}
&webmin_log("kill", undef, undef, \%in);
print "<p>\n";
&ui_print_footer("index_search.cgi?".&html_escape($in{'args'}),
		 $text{'search_return'});

