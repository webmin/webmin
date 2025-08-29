#!/usr/local/bin/perl
# search.cgi
# Find webmin actions

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
use Time::Local;
require './webminlog-lib.pl';
our (%text, %config, %gconfig, $webmin_logfile, %in, $in);
&foreign_require("acl", "acl-lib.pl");
&ReadParse();
if ($in{'search'}) {
	# Re-parse args from search param
	$ENV{'QUERY_STRING'} = $in{'search'};
	%in = ();
	&ReadParse(\%in, 'GET');
	}
&error_setup($text{'search_err'});

# Use sensible defaults
$in{'tall'} = 2 if (!defined($in{'tall'}));
$in{'uall'} = 1 if (!defined($in{'uall'}));
$in{'mall'} = 1 if (!defined($in{'mall'}));
$in{'fall'} = 1 if (!defined($in{'fall'}));
$in{'dall'} = 1 if (!defined($in{'dall'}));
$in{'wall'} = 1 if (!defined($in{'wall'}));

# Parse entered time ranges
my ($from, $to);
if ($in{'tall'} == 2) {
	# Today
	my @now = localtime(time());
	$from = timelocal(0, 0, 0, $now[3], $now[4], $now[5]);
	$to = timelocal(59, 59, 23, $now[3], $now[4], $now[5]);
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 3) {
	# Yesterday
	my @now = localtime(time()-24*60*60);
	$from = timelocal(0, 0, 0, $now[3], $now[4], $now[5]);
	$to = timelocal(59, 59, 23, $now[3], $now[4], $now[5]);
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 4) {
	# Over the last week
	my @week = localtime(time()-7*24*60*60);
	$from = timelocal(0, 0, 0, $week[3], $week[4], $week[5]);
	$to = time();
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 0) {
	# Some time range
	$from = &parse_time('from');
	$to = &parse_time('to');
	$to = $to ? $to + 24*60*60 - 1 : time();
	}
else {
	# All time
	$from = $to = 0;
	}

if ($in{'csv'}) {
	&PrintHeader(undef, "text/csv");
	}
else {
	&ui_print_header($in{'search_sub_title'} || undef, &html_escape($in{'search_title'} || $text{'search_title'}), "", undef, undef, $in{'no_return'});
	}

# Perform initial search in index
my @match;
my %index;
&build_log_index(\%index);
open(LOG, "<$webmin_logfile");
while(my ($id, $idx) = each %index) {
	if ($id =~ /^last/) {
	    next;
	}
	my ($pos, $time, $user, $module, $sid) = split(/\s+/, $idx);
	$time ||= 0;
	$module ||= "";
	$sid ||= "";
	if (($in{'uall'} == 1 ||
	     $in{'uall'} == 0 && $in{'user'} eq $user ||
	     $in{'uall'} == 3 && $in{'ouser'} eq $user ||
	     $in{'uall'} == 2 && $in{'nuser'} ne $user) &&
	    ($in{'mall'} || $in{'module'} eq $module) &&
	    (!$in{'sid'} || $in{'sid'} eq $sid ||
			    $in{'sid'} eq &acl::hash_session_id($sid)) &&
	    ($in{'tall'} || $from < $time && $to > $time)) {
		# Passed index check .. now look at actual log entry
		seek(LOG, $pos, 0);
		my $line = <LOG>;
		my $act = &parse_logline($line);
		next if (!$act);

		# Check Webmin server
		next if (!$in{'wall'} && $in{'webmin'} ne $act->{'webmin'});

		# Check modified files
		if ($gconfig{'logfiles'} && (!$in{'fall'} || !$in{'dall'})) {
			# Make sure the specified file was modified
			my $found = 0;
			foreach my $d (&list_diffs($act)) {
				my $filematch = $in{'fall'} ||
					$d->{'object'} &&
					$d->{'object'} eq $in{'file'};
				my $diffmatch = $in{'dall'} ||
					$d->{'diff'} =~ /\Q$in{'diff'}\E/i;
				if ($filematch && $diffmatch) {
					$found++;
					last;
					}
				}
			next if (!$found);
			}
		next if (!&can_user($act->{'user'}));
		next if (!&can_mod($act->{'module'}));

		# Check description
		if (defined($in{'desc'}) && $in{'desc'} =~ /\S/) {
			my $desc = &get_action_description($act, $in{'long'});
			$desc =~ s/<[^>]+>//g;
			next if ($desc !~ /\Q$in{'desc'}\E/i);
			}

		push(@match, $act);
		}
	}
close(LOG);

# Build search description
my $fromstr = &make_date($from, 1);
my $tostr = &make_date($to, 1);
my %minfo;
if (!$in{'mall'}) {
	%minfo = &get_module_info($in{'module'});
	}
my $searchmsg = join(" ",
	$in{'uall'} == 0 ? &text('search_critu',
		 "<tt>".&html_escape($in{'user'})."</tt>") :
	$in{'uall'} == 3 ? &text('search_critu',
		 "<tt>".&html_escape($in{'ouser'})."</tt>") :
	$in{'uall'} == 2 ? &text('search_critnu',
		 "<tt>".&html_escape($in{'nuser'})."</tt>") : "",
	$in{'mall'} ? '' : &text('search_critm',
		 "<tt>".&html_escape($minfo{'desc'})."</tt>"),
	$in{'tall'} ? '' : 
	  $fromstr eq $tostr ? &text('search_critt2', $tostr) :
	    &text('search_critt', $fromstr, $tostr),
	$in{'desc'} ? &text('search_critd', &html_escape($in{'desc'}))
		    : "");

my %minfo_cache;
if ($in{'csv'}) {
	# Show search results as CSV
	my @cols;
	foreach my $act (sort { $b->{'time'} <=> $a->{'time'} } @match) {
		my $m = $act->{'module'};
		my $minfo = $m eq "global" ? 
				{ 'desc' => $text{'search_global'} } :
				$minfo_cache{$m};
		if (!$minfo) {
			my %minfo = &get_module_info($m);
			$minfo = $minfo_cache{$m} = \%minfo;
			}
		my $desc = &get_action_description($act, $in{'long'});
		$desc =~ s/<[^>]+>//g;
		@cols = ( $desc, 
			  $minfo->{'desc'},
			  $act->{'user'},
			  $act->{'ip'} );
		if ($config{'host_search'}) {
			push(@cols, $act->{'webmin'});
			}
		push(@cols, &make_date($act->{'time'},0 , "yyyy-mm-dd"));
		print join(",", map { "\"$_\"" } @cols),"\n";
		}
	}
elsif (@match) {
	# Show search results in table
	if ($in{'sid'}) {
		print "<b data-search-action='sid'>",&text('search_sid', "<tt>$match[0]->{'user'}</tt>",
				  "<tt>$in{'sid'}</tt>")," ..</b><p>\n";
		}
	elsif ($in{'uall'} == 1 && $in{'mall'} && $in{'tall'}) {
		print "<b data-search-action='critall'>$text{'search_critall'} ..</b><p>\n";
		}
	else {
		my %minfo = &get_module_info($in{'module'}) if (!$in{'mall'});
		print "<b data-search-action='crit'>$text{'search_crit'} $searchmsg ...</b><p>\n";
		}
	print &ui_columns_start(
		[ $text{'search_action'},
		  $text{'search_module'},
		  $text{'search_user'},
		  $text{'search_host'},
		  $config{'host_search'} ? ( $text{'search_webmin'} ) : ( ),
		  $text{'time_ago_col'},
		  $text{'search_datetime'} ], "100");
	foreach my $act (sort { $b->{'time'} <=> $a->{'time'} } @match) {
		my @tm = localtime($act->{'time'});
		my $m = $act->{'module'};
		my $d;
		my $minfo = $m eq "global" ? 
				{ 'desc' => $text{'search_global'} } :
				$minfo_cache{$m};
		if (!$minfo) {
			# first time seeing module ..
			my %minfo = &get_module_info($m);
			$minfo = $minfo_cache{$m} = \%minfo;
			}

		my @cols;
		my $desc = &get_action_description($act, $in{'long'});
		my $anno = &get_annotation($act);
		push(@cols, &ui_link("view.cgi?id=$act->{'id'}".
		      "&return=".&urlize($in{'return'} || "").
		      "&returndesc=".&urlize($in{'returndesc'} || "").
		      "&no_return=".&urlize($in{'no_return'} || "").
		      "&search_sub_title=".&urlize($in{'search_sub_title'} || "").
		      "&file=".($in{'fall'} ? "" : &urlize($in{'file'})).
		      "&search=".&urlize($in || ""),
		      &filter_javascript($desc)) );
		if ($anno) {
			$cols[$#cols] .= "&nbsp;<img src=images/star.gif>";
			}
		push(@cols, $minfo->{'desc'},
			    &html_escape($act->{'user'}),
			    &html_escape($act->{'ip'}));
		if ($config{'host_search'}) {
			push(@cols, $act->{'webmin'});
			}
		push(@cols, &make_date_relative($act->{'time'}));
		push(@cols, &make_date($act->{'time'}));
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	print &ui_link("search.cgi/webminlog.csv?$in&csv=1", $text{'search_csv'});
    print "<p>\n";
	}
else {
	# Tell the user that nothing matches
	print "<p><b>$text{'search_none2'}".(&trim($searchmsg) ? " @{[&trim($searchmsg, -1)]}" : "").".</b><p>\n";
	}

if (!$in{'csv'} && !$in{'no_return'}) {
	# Show page footer
	if ($in{'return'}) {
		&ui_print_footer($in{'return'}, $in{'returndesc'});
		}
	else {
		&ui_print_footer("", $text{'index_return'});
		}
	}

sub parse_time
{
my $d = $in{"$_[0]_d"};
my $m = $in{"$_[0]_m"};
my $y = $in{"$_[0]_y"};
return 0 if (!$d && !$y);
my $rv;
eval { $rv = timelocal(0, 0, 0, $d, $m-1, $y-1900) };
&error($text{'search_etime'}) if ($@);
return $rv;
}
