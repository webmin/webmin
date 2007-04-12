#!/usr/local/bin/perl
# edit_proc.cgi
# Display information about a process

require './proc-lib.pl';
&ui_print_header(undef, $text{'edit_title'}, "", "edit_proc");
%pinfo = &process_info($ARGV[0]);
&can_edit_process($pinfo{'user'}) || &error($text{'edit_ecannot'});
if (!%pinfo) {
	print "<b>$text{'edit_gone'}</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_title'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td width=20% nowrap><b>$text{'command'}</b></td>\n";
print "     <td colspan=3><font size=+1>",
      &html_escape($pinfo{args}),"</font></td> </tr>\n";
print "<tr> <td width=20% nowrap><b>$text{'pid'}</b></td><td>$pinfo{pid}</td>\n";
print "<td width=20% nowrap><b>$text{'parent'}</b></td>\n";
if ($pinfo{ppid}) {
	local %ppinfo = &process_info($pinfo{ppid});
	print "<td><a href=\"edit_proc.cgi?$ppinfo{pid}\">",
		&cut_string($ppinfo{'args'}, 30),"</a></td>";
	}
else { print "<td>$text{'edit_none'}</td>"; }
print " </tr>\n";
print "<tr> <td width=20% nowrap><b>$text{'owner'}</b></td> ",
      "<td>$pinfo{'user'}</td>\n";
print "<td width=20% nowrap><b>$text{'cpu'}</b></td> ",
      "<td>$pinfo{'cpu'}</td> </tr>\n";
print "<tr> <td width=20% nowrap><b>$text{'size'}</b></td> ",
      "<td>$pinfo{'size'}</td>\n";
print "<td width=20% nowrap><b>$text{'runtime'}</b></td> ",
      "<td>$pinfo{'time'}</td> </tr>\n";
print "<tr> <td>",&hlink("<b>$text{'nice'}</b>","nice"),"</td>\n";
print "<form action=renice_proc.cgi>\n";
print "<input type=hidden name=pid value=$ARGV[0]>\n";
print "<td colspan=3>\n";
if (&indexof($pinfo{nice}, @nice_range) < 0) {
	print $pinfo{nice};
	}
else {
	print "<select name=nice>\n";
	for($i=0; $i<@nice_range; $i++) {
		printf "<option value=%d %s>%d%s\n",
			$nice_range[$i],
			$pinfo{nice} == $nice_range[$i] ? "selected" : "",
			$nice_range[$i],
			$i==0 ? " ($text{'edit_prihigh'})" :
			$i==@nice_range-1 ? " ($text{'edit_prilow'})" :
			$nice_range[$i]==0 ? " ($text{'edit_pridef'})" : "";
		}
	print "</select> <input type=submit value='$text{'edit_change'}'>\n";
	}
print "</td> </form></tr>\n";
$i = 0;
foreach $k (keys %pinfo) {
	if ($k =~ /^_/) {
		if ($i%2 == 0) { print "<tr>\n"; }
		printf "<td width=20%% nowrap><b>%s</b></td>\n",
			$info_arg_map{$k};
		print "<td>$pinfo{$k}</td>\n";
		if ($i%2 == 1) { print "<tr>\n"; }
		$i++;
		}
	}
print "</table></td></tr></table><p>\n";

print "<table width=100%><tr>\n";
if ($access{'simple'}) {
	# Just display buttons for common signals
	print "<form action=kill_proc.cgi>\n";
	print "<input type=hidden name=pid value=$pinfo{pid}><td nowrap>\n";
	foreach $s ('KILL', 'TERM', 'HUP', 'STOP', 'CONT') {
		printf "<input type=submit value=\"%s\" name=%s>\n",
			$text{"kill_".lc($s)}, $s;
		}
	print "</td></form>\n";
	}
else {
	# Allow the sending of any signal
	print "<form action=kill_proc.cgi>\n";
	print "<td nowrap><input type=hidden name=pid value='$pinfo{'pid'}'>\n";
	print "<input type=submit value=\"$text{'edit_kill'}\">\n";
	print "<select name=signal>\n";
	foreach $s (&supported_signals()) {
		printf "<option value=\"$s\" %s> $s\n",
			$s eq "HUP" ? "selected" : "";
		}
	print "</select>";

	print "&nbsp;" x 4;
	print "<input type=submit name=TERM value='$text{'edit_sigterm'}'>\n";
	print "<input type=submit name=KILL value='$text{'edit_sigkill'}'>\n";
	print "&nbsp;" x 4;
	print "<input type=submit name=STOP value='$text{'edit_sigstop'}'>\n";
	print "<input type=submit name=CONT value='$text{'edit_sigcont'}'>\n";
	print "</td></form>\n";
	}

if ($has_trace_command) {
	# Show button to trace syscalls
	print "<form action=trace.cgi>\n";
	print "<input type=hidden name=pid value=$pinfo{'pid'}>\n";
	print "<td align=right width=10><input type=submit value='$text{'edit_trace'}'>\n";
	print "</td></form>\n";
	}

if ($has_lsof_command) {
	# Show button to display currently open files
	print "<form action=open_files.cgi>\n";
	print "<input type=hidden name=pid value=$pinfo{'pid'}>\n";
	print "<td align=right width=10><input type=submit value='$text{'edit_open'}'>\n";
	print "</td></form>\n";
	}

print "</tr></table><p>\n";

@sub = grep { $_->{'ppid'} == $pinfo{pid} } &list_processes();
if (@sub) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_sub'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";
	@sub = sort { $a->{'pid'} <=> $b->{'pid'} } @sub;
	foreach $s (@sub) {
		local $p = $s->{'pid'};
		print "<tr> <td><a href=\"edit_proc.cgi?$p\">$p</a></td>\n";
		print "<td>",&cut_string($s->{args}, 80),"</td> </tr>\n";
		}
	print "</table></td></tr></table><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

