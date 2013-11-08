#!/usr/bin/perl
# Show last few log entries, nicely parsed, with search form

require './itsecur-lib.pl';
&can_use_error("report");
use POSIX;
&ReadParse();
print "Refresh: $config{'refresh'}\r\n"
	if ($config{'refresh'});
&header($text{'report_title'}, "");
print "<hr>\n";

if ($in{'reset'}) {
	# Clear all inputs
	%in = ( );
	}
elsif ($in{'save_name'}) {
	# Load up an old search
	$search = &get_search($in{'save_name'});
	if ($search) {
		$oldstart = $in{'start'};
		$oldend = $in{'end'};
		%in = %$search;
		$in{'start'} = $oldstart;
		$in{'end'} = $oldend;
		}
	}

# Show search form
print "<form action=list_report.cgi>\n";
print "<table width=100%>\n";
print "<tr>\n";
print "<td colspan=4><input type=submit value='$text{'report_search'}'></td>\n";
print "<td colspan=4 align=right><input type=submit name=reset value='$text{'report_reset'}'></td>\n";
print "</tr>\n";
$i = 0;
foreach $f (@search_fields) {
	print "<tr>\n" if ($i%2 == 0);
	print "<td><b>",$text{'report_'.$f},"</b></td>\n";
	print "<td><select name=${f}_mode>\n";
	if ($f eq "first" || $f eq "last") {
		foreach $m (0 .. 1) {
			printf "<option value=%d %s>%s</option>\n",
				$m, $in{"${f}_mode"} == $m ? "selected" : "",
				$text{'report_mode'.$m.$f} ||
				$text{'report_mode'.$m};
			}
		}
	else {
		foreach $m (0 .. 2) {
			printf "<option value=%d %s>%s</option>\n",
				$m, $in{"${f}_mode"} == $m ? "selected" : "",
				$text{'report_mode'.$m};
			}
		}
	print "</select></td>\n";
	if ($f eq "dst_iface") {
		print "<td>",&iface_input($f."_what", $in{$f."_what"}),"</td>\n";
		}
	elsif ($f eq "proto") {
		print "<td>",&protocol_input($f."_what", $in{$f."_what"}),"</td>\n";
		}
	elsif ($f eq "dst_port" || $f eq "src_port") {
		print "<td>",&service_input($f."_what", $in{$f."_what"}, 2, 0, 1);
		printf "<input name=%s_other size=6 value='%s'>\n",
			$f, $in{$f."_other"};
		print "</td>\n";
		}
	elsif ($f eq "src" || $f eq "dst") {
		print "<td>",&group_input($f."_what", $in{$f."_what"}, 2, 0);
		printf "<input name=%s_other size=10 value='%s'>\n",
			$f, $in{$f."_other"};
		print "</td>\n";
		}
	elsif ($f eq "first" || $f eq "last") {
		print "<td>";
		&date_input($in{$f."_day"}, $in{$f."_month"},
				  $in{$f."_year"}, $f);
		if ($f eq "first") {
			&hourmin_input($in{$f."_hour"} || "00",
				       $in{$f."_min"} || "00", $f);
			}
		else {
			&hourmin_input($in{$f."_hour"} || "23",
				       $in{$f."_min"} || "59", $f);
			}
		print "</td>";
		}
	elsif ($f eq "action") {
		print "<td>",&action_input($f."_what",
					   $in{$f."_what"}, 1),"</td>\n";
		}
	elsif ($f eq "rule") {
		printf "<td><input name=%s_what size=5 value='%s'></td>\n",
			$f, $in{$f."_what"};
		}
	else {
		printf "<td><input name=%s_what size=20 value='%s'></td>\n",
			$f, $in{$f."_what"};
		}
	print "<td>&nbsp;&nbsp;</td>\n";
	print "</tr>\n" if ($i++%2 == 1);
	}

# Show saved search
@searches = &list_searches();
if (@searches) {
	print "<tr> <td></td> </tr>\n";
	print "<tr> <td><b>$text{'report_usesaved'}</b></td>\n";
	print "<td colspan=3><select name=save_name>\n";
	printf "<option value='' %s>%s</option>\n",
		$in{'save_name'} eq "" ? "selected" : "", "&nbsp;";
	foreach $s ( @searches) {
		printf "<option value='%s' %s>%s</option>\n",
			$s->{'save_name'},
			$in{'save_name'} eq $s->{'save_name'} ? "selected" : "",
			$s->{'save_name'};
		}
	print "</select></td> </tr>\n";
	}

print "</table>\n";

print "</form>\n";
print "<hr>\n";

# Find those matching current search
@logs = &parse_all_logs();
$anylogs = @logs;
@logs = &filter_logs(\@logs, \%in, \@searchvars);
if ($in{'save_name'}) {
	push(@searchvars, "save_name=".&urlize($in{'save_name'}));
	}

# Show matching log entries
if (@logs) {
	if (@searchvars) {
		$prog = "list_report.cgi?".join("&", @searchvars)."&";
		}
	else {
		$prog = "list_report.cgi?";
		}
	if (@logs > $config{'perpage'}) {
		# Need to show arrows
		print "<center>\n";
		$s = int($in{'start'});
		$e = $in{'start'} + $config{'perpage'} - 1;
		$e = @logs-1 if ($e >= @logs);
		if ($s) {
			printf "<a href='%sstart=%d'>%s</a>\n",
			    $prog, 0,
			    "<img src=images/lleft.gif border=0 align=middle alt='First page'>";
			printf "<a href='%sstart=%d'>%s</a>\n",
			    $prog, $s - $config{'perpage'},
			    "<img src=/images/left.gif border=0 align=middle alt='Previous page'>";
			}
		print "<font size=+1>",&text('report_pos', $s+1, $e+1,
					     scalar(@logs)),"</font>\n";
		if ($e < @logs-1) {
			printf "<a href='%sstart=%d'>%s</a>\n",
			    $prog, $s + $config{'perpage'},
			    "<img src=/images/right.gif border=0 align=middle alt='Next page'>";
			printf "<a href='%sstart=%d'>%s</a>\n",
			    $prog, int((@logs-1)/$config{'perpage'})*$config{'perpage'},
			    "<img src=images/rright.gif border=0 align=middle alt='Last page'>";
			}
		print "</center>\n";
		}
	else {
		# Can show them all
		$s = 0;
		$e = @logs - 1;
		}

	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'report_action'}</b></td> ",
	      "<td><b>$text{'report_rule2'}</b></td> ",
	      "<td><b>$text{'report_date'}</b></td> ",
	      "<td><b>$text{'report_time'}</b></td> ",
	      "<td><b>$text{'report_src'}</b></td> ",
	      "<td><b>$text{'report_dst'}</b></td> ",
	      "<td><b>$text{'report_dst_iface'}</b></td> ",
	      "<td><b>$text{'report_proto'}</b></td> ",
	      "<td><b>$text{'report_src_port'}</b></td> ",
	      "<td><b>$text{'report_dst_port'}</b></td> ",
	      "</tr>\n";
	for($i=$s; $i<=$e; $i++) {
		$l = $logs[$i];
		print "<tr $cb>\n";
		print "<td>",$text{'rule_'.$l->{'action'}},"</td>\n";
		print "<td>",$l->{'rule'} || "<br>","</td>\n";
		local @tm = localtime($l->{'time'});
		print "<td>",strftime("%d/%m/%Y", @tm),"</td>\n";
		print "<td>",strftime("%H:%M:%S", @tm),"</td>\n";
		print "<td>",$l->{'src'},"</td>\n";
		print "<td>",$l->{'dst'},"</td>\n";
		print "<td>",$l->{'dst_iface'} || "<br>","</td>\n";
		print "<td>",$l->{'proto'} || "<br>","</td>\n";
		print "<td>",$l->{'src_port'} || "<br>","</td>\n";
		print "<td>",$l->{'dst_port'} || "<br>","</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	}
elsif ($anylogs) {
	print "<b>$text{'report_none'}</b><p>\n";
	}
else {
	print "<b>$text{'report_none2'}</b><p>\n";
	}


print "<hr>\n";
print "<table width=100%>\n";

if (@logs && &can_edit("report")) {
	# Show export button
	print "<form action=list_welf.cgi>\n";
	foreach $i (keys %in) {
		print "<input type=hidden name=$i value='",
		      &html_escape($in{$i}),"'>\n";
		}
	print "<tr> <td valign=top><input type=submit value='$text{'report_welf'}'></td>\n";
	print "<td>$text{'report_welfdesc'}</td>\n";
	print "</tr></form>\n";
	$anyrows++;
	}

if (@searchvars && &can_edit("report")) {
	# Show button to save this search
	print "<form action=save_search.cgi>\n";
	foreach $i (keys %in) {
		print "<input type=hidden name=$i value='",
		      &html_escape($in{$i}),"'>\n";
		}
	print "<tr> <td valign=top><input type=submit value='$text{'report_save'}'></td>\n";
	print "<td>$text{'report_savedesc'}<br>\n";
	print "<b>$text{'report_savename'}</b>\n";
	printf "<input name=save_name size=30 value='%s'>\n",
		$in{'save_name'};
	print "</td>\n";
	print "</tr></form>\n";
	$anyrows++;
	}

# Show button to select an old search
#@searches = &list_searches();
#if (@searches) {
#	print "<form action=list_report.cgi>\n";
#	print "<tr> <td valign=top><input type=submit value='$text{'report_load'}'></td>\n";
#	print "<td>$text{'report_loaddesc'}<br>\n";
#	print "<b>$text{'report_savename'}</b>\n";
#	print "<select name=save_name>\n";
#	foreach $s (@searches) {
#		printf "<option %s>%s\n",
#			$s->{'save_name'} eq $in{'save_name'} ? "selected" : "",
#			&html_escape($s->{'save_name'});
#		}
#	print "</select>\n";
#	print "</td>\n";
#	print "</tr></form>\n";
#	$anyrows++;
#	}

print "</table>\n";

print "<hr>\n" if ($anyrows);
&footer("", $text{'index_return'});

# date_input(day, month, year, prefix)
sub date_input
{
print "<input name=$_[3]_day size=2 value='$_[0]'>";
print "/<select name=$_[3]_month>\n";
local $m;
foreach $m (1..12) {
	printf "<option value=%d %s>%s</option>\n",
		$m, $_[1] eq $m ? 'selected' : '', $text{"smonth_$m"};
	}
print "</select>";
print "/<input name=$_[3]_year size=4 value='$_[2]'>";
print &date_chooser_button("$_[3]_day", "$_[3]_month", "$_[3]_year");
print "\n";
}

# hourmin_input(hour, min, prefix)
sub hourmin_input
{
print "<input name=$_[2]_hour size=2 value='$_[0]'>";
print ":";
print "<input name=$_[2]_min size=2 value='$_[1]'>";
print "\n";
}
