#!/usr/local/bin/perl
# edit_log.cgi
# Display logging options

require './wuftpd-lib.pl';
&ui_print_header(undef, $text{'log_title'}, "", "log");

$conf = &get_ftpaccess();
foreach $l (&find_value('log', $conf)) {
	$log{$l->[0]} = $l;
	}

print "<form action=save_log.cgi>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'log_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

# Display log commands option
map { $commands{$_}++ } split(/,/, $log{'commands'}->[1]);
print "<tr> <td><b>$text{'log_commands'}</b></td> <td>\n";
foreach $c ('anonymous', 'guest', 'real') {
	printf "<input type=checkbox name=commands value=$c %s> %s\n",
		$commands{$c} ? 'checked' : '', $text{"log_$c"};
	}
print "</td> </tr>\n";

# Display log transfers option
map { $transfers{$_}++ } split(/,/, $log{'transfers'}->[1]);
print "<tr> <td valign=top><b>$text{'log_trans'}</b></td> <td>\n";
foreach $c ('anonymous', 'guest', 'real') {
	printf "<input type=checkbox name=transfers value=$c %s> %s\n",
		$transfers{$c} ? 'checked' : '', $text{"log_$c"};
	}
print "</td> </tr> <tr> <td></td> <td>\n";
print "<b>$text{'log_dir'}</b>\n";
$d = $log{'transfers'}->[2];
printf "<input type=radio name=direction value=inbound %s> %s\n",
	$d eq 'inbound' ? 'checked' : '', $text{'log_inbound'};
printf "<input type=radio name=direction value=outbound %s> %s\n",
	$d eq 'outbound' ? 'checked' : '', $text{'log_outbound'};
printf "<input type=radio name=direction value=inbound,outbound %s> %s\n",
	$d =~ /inbound/ && $d =~ /outbound/ ? 'checked' : '', $text{'log_both'};
print "</td> </tr>\n";

# Display log syslog option
print "<tr> <td><b>$text{'log_to'}</b></td> <td>\n";
printf "<input type=radio name=syslog value=1 %s> %s\n",
	$log{'syslog'} ? 'checked' : '', $text{'log_syslog'};
printf "<input type=radio name=syslog value=0 %s> %s\n",
	$log{'syslog'} || $log{'syslog+xferlog'} ? '' : 'checked',
	$text{'log_xferlog'};
printf "<input type=radio name=syslog value=2 %s> %s</td> </tr>\n",
	$log{'syslog+xferlog'} ? 'checked' : '', $text{'log_sysxfer'};

# Display log security option
map { $security{$_}++ } split(/,/, $log{'security'}->[1]);
print "<tr> <td><b>$text{'log_security'}</b></td> <td>\n";
foreach $c ('anonymous', 'guest', 'real') {
	printf "<input type=checkbox name=security value=$c %s> %s\n",
		$security{$c} ? 'checked' : '', $text{"log_$c"};
	}
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

