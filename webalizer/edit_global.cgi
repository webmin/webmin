#!/usr/local/bin/perl
# edit_global.cgi
# Display options from a webalizer.conf file

require './webalizer-lib.pl';
&ReadParse();
$access{'view'} && &error($text{'edit_ecannot'});
if ($in{'file'}) {
	&can_edit_log($in{'file'}) || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'global_title2'}, "");
	print "<center>",&text('global_for', "<tt>$in{'file'}</tt>"),
	      "</center>\n";
	}
else {
	$access{'global'} || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'global_title'}, "");
	}
$conf = &get_config($in{'file'});

$cfile = &config_file_name($in{'file'}) if ($in{'file'});

print "<form action=save_global.cgi method=post>\n";
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<input type=hidden name=type value='$in{'type'}'>\n";
print "<input type=hidden name=custom value='$in{'custom'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'global_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$report = &find_value("ReportTitle", $conf);
print "<tr> <td><b>$text{'global_report'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=report_def value=1 %s> %s\n",
	$report ? "" : "checked", $text{'default'};
printf "<input type=radio name=report_def value=0 %s>\n",
	$report ? "checked" : "";
printf "<input name=report size=40 value='%s'></td> </tr>\n",
	&html_escape($report);

if ($in{'file'}) {
	$host = &find_value("HostName", $conf);
	print "<tr> <td><b>$text{'global_host'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=host_def value=1 %s> %s\n",
		$host ? "" : "checked", $text{'default'};
	printf "<input type=radio name=host_def value=0 %s>\n",
		$host ? "checked" : "";
	print "<input name=host size=30 value='$host'></td> </tr>\n";
	}

@page = &find_value("PageType", $conf);
print "<tr> <td><b>$text{'global_page'}</b></td> <td colspan=3>\n";
printf "<input name=page size=50 value='%s'></td> </tr>\n",
	join(" ", @page);

@index = &find_value("IndexAlias", $conf);
print "<tr> <td><b>$text{'global_index'}</b></td> <td colspan=3>\n";
printf "<input name=index size=50 value='%s'></td> </tr>\n",
	join(" ", @index);

$gmt = &find_value("GMTTime", $conf);
print "<tr> <td><b>$text{'global_gmt'}</b></td>\n";
printf "<td><input type=radio name=gmt value=1 %s> %s\n",
	$gmt =~ /^y/i ? "checked" : "", $text{'yes'};
printf "<input type=radio name=gmt value=0 %s> %s</td>\n",
	$gmt =~ /^y/i ? "" : "checked", $text{'no'};

$fold = &find_value("FoldSeqErr", $conf);
print "<td><b>$text{'global_fold'}</b></td>\n";
printf "<td><input type=radio name=fold value=1 %s> %s\n",
	$fold =~ /^y/i ? "checked" : "", $text{'yes'};
printf "<input type=radio name=fold value=0 %s> %s</td> </tr>\n",
	$fold =~ /^y/i ? "" : "checked", $text{'no'};

$visit = &find_value("VisitTimeout", $conf);
print "<tr> <td><b>$text{'global_visit'}</b></td>\n";
printf "<td><input type=radio name=visit_def value=1 %s> %s\n",
	$visit ? "" : "checked", $text{'default'};
printf "<input type=radio name=visit_def value=0 %s>\n",
	$visit ? "checked" : "";
printf "<input name=visit size=6 value='%s'> %s</td>\n",
	$visit, $text{'global_secs'};

$dns = &find_value("DNSChildren", $conf);
print "<td><b>$text{'global_dns'}</b></td>\n";
printf "<td><input type=radio name=dns_def value=1 %s> %s\n",
	$dns ? "" : "checked", $text{'global_none'};
printf "<input type=radio name=dns_def value=0 %s>\n",
	$dns ? "checked" : "";
printf "<input name=dns size=6 value='%s'></td> </tr>\n", $dns;

print "<tr> <td colspan=4><hr></td> </tr>\n";

$history = &find_value("HistoryName", $conf);
print "<tr> <td><b>$text{'global_history'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=history_def value=1 %s> %s\n",
	$history ? "" : "checked", $text{'default'};
printf "<input type=radio name=history_def value=0 %s>\n",
	$history ? "checked" : "";
printf "<input name=history size=40 value='%s'></td> </tr>\n",
	&html_escape($history);

$current = &find_value("IncrementalName", $conf);
print "<tr> <td><b>$text{'global_current'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=current_def value=1 %s> %s\n",
	$current ? "" : "checked", $text{'default'};
printf "<input type=radio name=current_def value=0 %s>\n",
	$current ? "checked" : "";
printf "<input name=current size=40 value='%s'></td> </tr>\n",
	&html_escape($current);

$cache = &find_value("DNSCache", $conf);
print "<tr> <td><b>$text{'global_cache'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=cache_def value=1 %s> %s\n",
	$cache ? "" : "checked", $text{'default'};
printf "<input type=radio name=cache_def value=0 %s>\n",
	$cache ? "checked" : "";
printf "<input name=cache size=40 value='%s'></td> </tr>\n",
	&html_escape($cache);

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'global_display'}</b></td>\n";
print "<td colspan=3><table>\n";
$i = 0;
foreach $g ('DailyGraph', 'DailyStats', 'HourlyGraph',
	    'HourlyStats', 'CountryGraph', 'GraphLegend') {
	$v = &find_value($g, $conf);
	print "<tr>\n" if ($i%2 == 0);
	printf "<td><input type=checkbox name=%s value=1 %s>%s</td>\n",
		$g, $v =~ /^n/i ? "" : "checked", $text{"global_$g"};
	print "</tr>\n" if ($i++%2 == 1);
	}
print "</table></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'global_tables'}</b></td>\n";
print "<td colspan=3><table width=100%>\n";
$i = 0;
foreach $t ('TopSites', 'TopKSites', 'TopURLs', 'TopKURLs', 'TopReferrers',
	    'TopAgents', 'TopCountries', 'TopEntry', 'TopExit',
	    'TopSearch', 'TopUsers') {
	$v = &find_value($t, $conf);
	print "<tr>\n" if ($i%2 == 0);
	printf "<td><b>%s</b></td>", $text{"global_$t"};
	printf "<td nowrap><input type=radio name=%s_def value=1 %s> %s\n",
		$t, $v eq "" ? "checked" : "", $text{'default'};
	printf "<input type=radio name=%s_def value=2 %s> %s\n",
		$t, $v eq "0" ? "checked" : "", $text{'global_none'};
	printf "<input type=radio name=%s_def value=0 %s>\n",
		$t, $v ? "checked" : "";
	printf "<input name=%s size=4 value='%s'></td>\n",
		$t, $v ? $v : "";
	print "</tr>\n" if ($i++%2 == 1);
	}
print "</table></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'global_all'}</b></td>\n";
print "<td colspan=3><table>\n";
$i = 0;
foreach $a ('AllSites', 'AllURLs', 'AllReferrers', 'AllAgents',
	    'AllSearchStr', 'AllUsers') {
	$v = &find_value($a, $conf);
	print "<tr>\n" if ($i%3 == 0);
	printf "<td><input type=checkbox name=%s value=1 %s>%s</td>\n",
		$a, $v =~ /^y/i ? "checked" : "", $text{"global_$a"};
	print "</tr>\n" if ($i++%3 == 2);
	}
print "</table></td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

foreach $hid ("HideURL", "HideSite", "HideReferrer",
	      "HideUser", "HideAgent") {
	@hidv = &find_value($hid, $conf);
	print "<tr> <td><b>",$text{'global_'.lc($hid)},"</b></td> <td colspan=3>\n";
	printf "<input name=%s size=60 value='%s'></td> </tr>\n",
		lc($hid), join(" ", @hidv);
	}

print "<tr> <td colspan=4><hr></td> </tr>\n";

foreach $ign ("IgnoreURL", "IgnoreSite", "IgnoreReferrer",
	      "IgnoreUser", "IgnoreAgent") {
	@ignv = &find_value($ign, $conf);
	print "<tr> <td><b>",$text{'global_'.lc($ign)},"</b></td> <td colspan=3>\n";
	printf "<input name=%s size=60 value='%s'></td> </tr>\n",
		lc($ign), join(" ", @ignv);
	}

print "<tr> <td colspan=4><hr></td> </tr>\n";

foreach $inc ("IncludeURL", "IncludeSite", "IncludeReferrer",
	      "IncludeUser", "IncludeAgent") {
	@incv = &find_value($inc, $conf);
	print "<tr> <td><b>",$text{'global_'.lc($inc)},"</b></td> <td colspan=3>\n";
	printf "<input name=%s size=60 value='%s'></td> </tr>\n",
		lc($inc), join(" ", @incv);
	}

print "</table></td></tr></table>\n";
push(@b, "<input type=submit value='$text{'save'}'>");
push(@b, "<input type=submit name=delete value='$text{'global_delete'}'>")
	if ($in{'file'} && -r $cfile);
&spaced_buttons(@b);
print "</form>\n";

&ui_print_footer("", $text{'index_return'});

