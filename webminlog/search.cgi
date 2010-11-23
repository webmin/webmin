#!/usr/local/bin/perl
# search.cgi
# Find webmin actions

require './webminlog-lib.pl';
require 'timelocal.pl';
&foreign_require("acl", "acl-lib.pl");
&ReadParse();
&error_setup($text{'search_err'});

# Use sensible defaults
$in{'tall'} = 2 if (!defined($in{'tall'}));
$in{'uall'} = 1 if (!defined($in{'uall'}));
$in{'mall'} = 1 if (!defined($in{'mall'}));
$in{'fall'} = 1 if (!defined($in{'fall'}));
$in{'dall'} = 1 if (!defined($in{'dall'}));
$in{'wall'} = 1 if (!defined($in{'wall'}));

# Parse entered time ranges
if ($in{'tall'} == 2) {
	# Today
	@now = localtime(time());
	$from = timelocal(0, 0, 0, $now[3], $now[4], $now[5]);
	$to = timelocal(59, 59, 23, $now[3], $now[4], $now[5]);
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 3) {
	# Yesterday
	@now = localtime(time()-24*60*60);
	$from = timelocal(0, 0, 0, $now[3], $now[4], $now[5]);
	$to = timelocal(59, 59, 23, $now[3], $now[4], $now[5]);
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 4) {
	# Over the last week
	@week = localtime(time()-7*24*60*60);
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

if ($in{'csv'}) {
	print "Content-type: text/csv\n\n";
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	}

# Perform initial search in index
&build_log_index(\%index);
open(LOG, $webmin_logfile);
while(($id, $idx) = each %index) {
	local ($pos, $time, $user, $module, $sid) = split(/\s+/, $idx);
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
		$line = <LOG>;
		$act = &parse_logline($line);

		# Check Webmin server
		next if (!$in{'wall'} && $in{'webmin'} ne $act->{'webmin'});

		# Check modified files
		if ($gconfig{'logfiles'} && (!$in{'fall'} || !$in{'dall'})) {
			# Make sure the specified file was modified
			local $found = 0;
			foreach $d (&list_diffs($act)) {
				local $filematch = $in{'fall'} ||
					$d->{'object'} &&
					$d->{'object'} eq $in{'file'};
				local $diffmatch = $in{'dall'} ||
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
		push(@match, $act);
		}
	}
close(LOG);

# Build search description
@from = localtime($from);
@to = localtime($to);
$fromstr = sprintf "%2.2d/%s/%4.4d",
	$from[3], $text{"smonth_".($from[4]+1)}, $from[5]+1900;
$tostr = sprintf "%2.2d/%s/%4.4d",
	$to[3], $text{"smonth_".($to[4]+1)}, $to[5]+1900;
if (!$in{'mall'}) {
	%minfo = &get_module_info($in{'module'});
	}
$searchmsg = join(" ",
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
	    &text('search_critt', $fromstr, $tostr));

if ($in{'csv'}) {
	# Show search results as CSV
	foreach $act (sort { $b->{'time'} <=> $a->{'time'} } @match) {
		$minfo = $m eq "global" ? 
				{ 'desc' => $text{'search_global'} } :
				$minfo_cache{$m};
		if (!$minfo) {
			local %minfo = &get_module_info($m);
			$minfo = $minfo_cache{$m} = \%minfo;
			}
		local $desc = &get_action_description($act, 0);
		$desc =~ s/<[^>]+>//g;
		@cols = ( $desc, 
			  $minfo->{'desc'},
			  $act->{'user'},
			  $act->{'ip'} );
		if ($config{'host_search'}) {
			push(@cols, $act->{'webmin'});
			}
		push(@cols, &make_date($act->{'time'}));
		print join(",", map { "\"$_\"" } @cols),"\n";
		}
	}
elsif (@match) {
	# Show search results in table
	if ($in{'sid'}) {
		print "<b>",&text('search_sid', "<tt>$match[0]->{'user'}</tt>",
				  "<tt>$in{'sid'}</tt>")," ..</b><p>\n";
		}
	elsif ($in{'uall'} == 1 && $in{'mall'} && $in{'tall'}) {
		print "<b>$text{'search_critall'} ..</b><p>\n";
		}
	else {
		@from = localtime($from); @to = localtime($to);
		$fromstr = sprintf "%2.2d/%s/%4.4d",
			$from[3], $text{"smonth_".($from[4]+1)}, $from[5]+1900;
		$tostr = sprintf "%2.2d/%s/%4.4d",
			$to[3], $text{"smonth_".($to[4]+1)}, $to[5]+1900;
		%minfo = &get_module_info($in{'module'}) if (!$in{'mall'});
		print "<b>$text{'search_crit'} $searchmsg ...</b><p>\n";
		}
	print &ui_columns_start(
		[ $text{'search_action'},
		  $text{'search_module'},
		  $text{'search_user'},
		  $text{'search_host'},
		  $config{'host_search'} ? ( $text{'search_webmin'} ) : ( ),
		  $text{'search_date'},
		  $text{'search_time'} ], "100");
	foreach $act (sort { $b->{'time'} <=> $a->{'time'} } @match) {
		local @tm = localtime($act->{'time'});
		local $m = $act->{'module'};
		local $d;
		$minfo = $m eq "global" ? 
				{ 'desc' => $text{'search_global'} } :
				$minfo_cache{$m};
		if (!$minfo) {
			# first time seeing module ..
			local %minfo = &get_module_info($m);
			$minfo = $minfo_cache{$m} = \%minfo;
			}

		local @cols;
		local $desc = &get_action_description($act, 0);
		local $anno = &get_annotation($act);
		push(@cols, "<a href='view.cgi?id=$act->{'id'}".
		      "&return=".&urlize($in{'return'}).
		      "&returndesc=".&urlize($in{'returndesc'}).
		      "&search=".&urlize($in).
		      "'>$desc</a>");
		if ($anno) {
			$cols[$#cols] .= "&nbsp;<img src=images/star.gif>";
			}
		push(@cols, $minfo->{'desc'}, $act->{'user'}, $act->{'ip'});
		if ($config{'host_search'}) {
			push(@cols, $act->{'webmin'});
			}
		push(@cols, split(/\s+/, &make_date($act->{'time'})));
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	print "<a href='search.cgi/webminlog.csv?$in&csv=1'>$text{'search_csv'}</a><p>\n";
	}
else {
	# Tell the user that nothing matches
	print "<p><b>$text{'search_none2'} $searchmsg.</b><p>\n";
	}

if (!$in{'csv'}) {
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
local $d = $in{"$_[0]_d"};
local $m = $in{"$_[0]_m"};
local $y = $in{"$_[0]_y"};
return 0 if (!$d && !$y);
local $rv;
eval { $rv = timelocal(0, 0, 0, $d, $m, $y-1900) };
&error($text{'search_etime'}) if ($@);
return $rv;
}
