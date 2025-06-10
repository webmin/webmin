#!/usr/local/bin/perl
# edit_global.cgi
# Display options from a webalizer.conf file

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %config, %gconfig, %access, $module_name, %in, $remote_user);
require './webalizer-lib.pl';
&ReadParse();
$access{'view'} && &error($text{'edit_ecannot'});

if ($in{'file'}) {
	&can_edit_log($in{'file'}) || &error($text{'edit_ecannot'});
	&ui_print_header(&text('global_for', "<tt>$in{'file'}</tt>"),
			 $text{'global_title2'}, "");
	}
else {
	$access{'global'} || &error($text{'edit_ecannot'});
	&ui_print_header(undef, $text{'global_title'}, "");
	}
my $conf = &get_config($in{'file'});
my $cfile = &config_file_name($in{'file'}) if ($in{'file'});

print &ui_form_start("save_global.cgi", "post");
print &ui_hidden("file", $in{'file'});
print &ui_hidden("type", $in{'type'});
print &ui_hidden("custom", $in{'custom'});
print &ui_table_start($text{'global_header'}, "width=100%", 2);

# Report name
my $report = &find_value("ReportTitle", $conf);
print &ui_table_row($text{'global_report'},
	&ui_opt_textbox("report", $report, 40, $text{'default'}));

if ($in{'file'}) {
	# Hostname for report
	my $host = &find_value("HostName", $conf);
	print &ui_table_row($text{'global_host'},
		&ui_opt_textbox("host", $host, 30, $text{'default'}));
	}

my @page = &find_value("PageType", $conf);
print &ui_table_row($text{'global_page'},
	&ui_textbox("page", join(" ", @page), 60));

my @index = &find_value("IndexAlias", $conf);
print &ui_table_row($text{'global_index'},
	&ui_textbox("index", join(" ", @index), 60));

my $gmt = &find_value("GMTTime", $conf);
print &ui_table_row($text{'global_gmt'},
	&ui_yesno_radio("gmt", $gmt && $gmt =~ /^y/i ? 1 : 0));

my $fold = &find_value("FoldSeqErr", $conf);
print &ui_table_row($text{'global_fold'},
	&ui_yesno_radio("fold", $fold && $fold =~ /^y/i ? 1 : 0));

my $visit = &find_value("VisitTimeout", $conf);
print &ui_table_row($text{'global_visit'},
	&ui_opt_textbox("visit", $visit, 6, $text{'default'})." ".
	$text{'global_secs'});

my $dns = &find_value("DNSChildren", $conf);
print &ui_table_row($text{'global_dns'},
	&ui_opt_textbox("dns", $dns, 6, $text{'global_none'}));

print &ui_table_hr();

my $history = &find_value("HistoryName", $conf);
print &ui_table_row($text{'global_history'},
	&ui_opt_textbox("history", $history, 60, $text{'default'}), 3);

my $current = &find_value("IncrementalName", $conf);
print &ui_table_row($text{'global_current'},
	&ui_opt_textbox("current", $current, 60, $text{'default'}), 3);

my $cache = &find_value("DNSCache", $conf);
print &ui_table_row($text{'global_cache'},
	&ui_opt_textbox("cache", $cache, 60, $text{'default'}), 3);

print &ui_table_hr();

my @grid;
foreach my $g ('DailyGraph', 'DailyStats', 'HourlyGraph',
	       'HourlyStats', 'CountryGraph', 'GraphLegend') {
	my $v = &find_value($g, $conf);
	push(@grid, &ui_checkbox($g, 1, $text{"global_$g"},
				 $v && $v =~ /^n/i ? 0 : 1));
	}
print &ui_table_row($text{'global_display'}, &ui_grid_table(\@grid, 4));

@grid = ( );
foreach my $t ('TopSites', 'TopKSites', 'TopURLs', 'TopKURLs', 'TopReferrers',
	       'TopAgents', 'TopCountries', 'TopEntry', 'TopExit',
	       'TopSearch', 'TopUsers') {
	my $v = &find_value($t, $conf);
	push(@grid, "<b>".$text{'global_'.$t}."</b>");
	push(@grid, &ui_radio($t."_def",
			      !defined($v) || $v eq "" ? 1 : $v eq "0" ? 2 : 0,
			      [ [ 1, $text{'default'} ],
				[ 2, $text{'global_none'} ],
				[ 0, &ui_textbox($t, $v ? $v : "", 4) ] ]));
	}
print &ui_table_row($text{'global_tables'}, &ui_grid_table(\@grid, 4));

@grid = ( );
foreach my $a ('AllSites', 'AllURLs', 'AllReferrers', 'AllAgents',
	       'AllSearchStr', 'AllUsers') {
	my $v = &find_value($a, $conf);
	push(@grid, &ui_checkbox($a, 1, $text{"global_$a"},
				 $v && $v =~ /^y/i ? 1 : 0));
	}
print &ui_table_row($text{'global_all'}, &ui_grid_table(\@grid, 4));

print &ui_table_hr();

foreach my $hid ("HideURL", "HideSite", "HideReferrer",
	         "HideUser", "HideAgent") {
	my @hidv = &find_value($hid, $conf);
	print &ui_table_row($text{'global_'.lc($hid)},
		&ui_textbox(lc($hid), join(" ", @hidv), 60));
	}

print &ui_table_hr();

foreach my $ign ("IgnoreURL", "IgnoreSite", "IgnoreReferrer",
	         "IgnoreUser", "IgnoreAgent") {
	my @ignv = &find_value($ign, $conf);
	print &ui_table_row($text{'global_'.lc($ign)},
		&ui_textbox(lc($ign), join(" ", @ignv), 60));
	}

print &ui_table_hr();

foreach my $inc ("IncludeURL", "IncludeSite", "IncludeReferrer",
	         "IncludeUser", "IncludeAgent") {
	my @incv = &find_value($inc, $conf);
	print &ui_table_row($text{'global_'.lc($inc)},
                &ui_textbox(lc($inc), join(" ", @incv), 60));
	}

print &ui_table_end();
my @b;
push(@b, [ undef, $text{'save'} ]);
push(@b, [ 'delete', $text{'global_delete'} ]) if ($in{'file'} && -r $cfile);
print &ui_form_end(\@b);

&ui_print_footer("", $text{'index_return'});

