#!/usr/local/bin/perl
# save_global.cgi
# Save options to a webalizer.conf file

require './webalizer-lib.pl';
&error_setup($text{'global_err'});
$access{'view'} && &error($text{'edit_ecannot'});
&ReadParse();
!$in{'file'} || &can_edit_log($in{'file'}) || &error($text{'edit_ecannot'});
$in{'file'} || $access{'global'} || &error($text{'edit_ecannot'});

$cfile = &config_file_name($in{'file'}) if ($in{'file'});
if ($in{'delete'}) {
	# Just delete the configuration for this logfile
	&unlink_logged($cfile);
	&redirect("");
	exit;
	}

&lock_file($cfile || $config{'webalizer_conf'});
$conf = &get_config($in{'file'});

# Validate and store inputs
if ($in{'report_def'}) {
	&save_directive($conf, "ReportTitle");
	}
else {
	$in{'report'} =~ /\S/ || &error($text{'global_ereport'});
	&save_directive($conf, "ReportTitle", $in{'report'});
	}

if ($in{'host_def'}) {
	&save_directive($conf, "HostName");
	}
elsif (defined($in{'host'})) {
	$in{'host'} =~ /^\S+$/ || &error($text{'global_ehost'});
	&save_directive($conf, "HostName", $in{'host'});
	}

@pages = split(/\s+/, $in{'page'});
&save_directive($conf, "PageType", @pages);

@index = split(/\s+/, $in{'index'});
&save_directive($conf, "IndexAlias", @index);

if ($in{'gmt'}) {
	&save_directive($conf, "GMTTime", "yes");
	}
else {
	&save_directive($conf, "GMTTime");
	}

if ($in{'fold'}) {
	&save_directive($conf, "FoldSeqErr", "yes");
	}
else {
	&save_directive($conf, "FoldSeqErr");
	}

if ($in{'visit_def'}) {
	&save_directive($conf, "VisitTimeout");
	}
else {
	$in{'visit'} =~ /^\d+$/ || &error($text{'global_evisit'});
	&save_directive($conf, "VisitTimeout", $in{'visit'});
	}

if ($in{'dns_def'}) {
	&save_directive($conf, "DNSChildren");
	}
else {
	$in{'dns'} =~ /^\d+$/ || &error($text{'global_edns'});
	&save_directive($conf, "DNSChildren", $in{'dns'});
	}

if ($in{'history_def'}) {
	&save_directive($conf, "HistoryName");
	}
else {
	$in{'history'} =~ /^\S+$/ || &error($text{'global_ehistory'});
	&save_directive($conf, "HistoryName", $in{'history'});
	}

if ($in{'current_def'}) {
	&save_directive($conf, "IncrementalName");
	}
else {
	$in{'current'} =~ /^\S+$/ || &error($text{'global_ecurrent'});
	&save_directive($conf, "IncrementalName", $in{'current'});
	}

if ($in{'cache_def'}) {
	&save_directive($conf, "DNSCache");
	}
else {
	$in{'cache'} =~ /^\S+$/ || &error($text{'global_ecache'});
	&save_directive($conf, "DNSCache", $in{'cache'});
	}

foreach $g ('DailyGraph', 'DailyStats', 'HourlyGraph',
	    'HourlyStats', 'CountryGraph', 'GraphLegend') {
	if ($in{$g}) {
		&save_directive($conf, $g);
		}
	else {
		&save_directive($conf, $g, "no");
		}
	}

foreach $t ('TopSites', 'TopKSites', 'TopURLs', 'TopKURLs', 'TopReferrers',
	    'TopAgents', 'TopCountries', 'TopEntry', 'TopExit',
	    'TopSearch', 'TopUsers') {
	if ($in{"${t}_def"} == 1) {
		&save_directive($conf, $t);
		}
	elsif ($in{"${t}_def"} == 2) {
		&save_directive($conf, $t, "0");
		}
	else {
		$in{$t} =~ /^\d+$/ || &error(&text('global_etable',
						   $text{"global_$t"}));
		&save_directive($conf, $t, $in{$t});
		}
	}

foreach $a ('AllSites', 'AllURLs', 'AllReferrers', 'AllAgents',
	    'AllSearchStr', 'AllUsers') {
	if ($in{$a}) {
		&save_directive($conf, $a, "yes");
		}
	else {
		&save_directive($conf, $a);
		}
	}

foreach $hid ("HideURL", "HideSite", "HideReferrer",
	      "HideUser", "HideAgent") {
	@hidv = split(/\s+/, $in{lc($hid)});
	&save_directive($conf, $hid, @hidv);
	}

foreach $ign ("IgnoreURL", "IgnoreSite", "IgnoreReferrer",
	      "IgnoreUser", "IgnoreAgent") {
	@ignv = split(/\s+/, $in{lc($ign)});
	&save_directive($conf, $ign, @ignv);
	}

foreach $inc ("IncludeURL", "IncludeSite", "IncludeReferrer",
	      "IncludeUser", "IncludeAgent") {
	@incv = split(/\s+/, $in{lc($inc)});
	&save_directive($conf, $inc, @incv);
	}

&flush_file_lines();
&unlock_file($cfile || $config{'webalizer_conf'});
&webmin_log("modify", "global", $in{'file'});
&redirect($in{'file'} ? "edit_log.cgi?file=".&urlize($in{'file'}).
		        "&type=$in{'type'}&custom=$in{'custom'}" : "");

