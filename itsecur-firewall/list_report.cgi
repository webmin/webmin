#!/usr/bin/perl
# Show last few log entries, nicely parsed, with search form

require './itsecur-lib.pl';
&can_use_error("report");
use POSIX;
&ReadParse();
print "Refresh: $config{'refresh'}\r\n"
	if ($config{'refresh'});
&header($text{'report_title'}, "");

print &ui_hr();

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
print &ui_form_start("list_report.cgi", "post");
print &ui_table_start(undef,"width=100%",2);

print &ui_columns_row([&ui_submit($text{'report_search'}),
                        &ui_submit($text{'report_reset'},"reset")],
                        ["colspan=4 width=50%", "colspan=4 width=50%"]);

my $i = 0;
my @cols_row;
my @sel;
my $tx = "";
foreach $f (@search_fields) {
    @cols_row = () if ($i%2 == 0);
    push(@cols_row, $text{'report_'.$f});
    @sel = ();
	if ($f eq "first" || $f eq "last") {
		foreach $m (0 .. 1) {
            push(@sel, [ $m, ( $text{'report_mode'.$m.$f} || 
                            $text{'report_mode'.$m} ),
                            ($in{"${f}_mode"} == $m ? "selected" : "")]);
		}
    }
	else {
		foreach $m (0 .. 2) {
            push(@sel, [ $m, $text{'report_mode'.$m}, ($in{"${f}_mode"} == $m ? "selected" : "")]);
		}
    }
    push(@cols_row, &ui_select(${f}."_mode", undef, \@sel, 1) );

	if ($f eq "dst_iface") {
        push(@cols_row, &iface_input($f."_what", $in{$f."_what"}) );
		}
	elsif ($f eq "proto") {
        push(@cols_row, &protocol_input($f."_what", $in{$f."_what"}) );
		}
	elsif ($f eq "dst_port" || $f eq "src_port") {
        push(@cols_row, &ui_textbox($f."_other", $in{$f."_other"}, 6) ); 
		}
	elsif ($f eq "src" || $f eq "dst") {
        push(@cols_row, &group_input($f."_what", $in{$f."_what"}, 2, 0).
                        &ui_textbox($f."_other", $in{$f."_other"}, 10) );
		}
	elsif ($f eq "first" || $f eq "last") {
		$tx = "";
		$tx .= &date_input($in{$f."_day"}, $in{$f."_month"},
				  $in{$f."_year"}, $f);
		if ($f eq "first") {
			$tx .= &hourmin_input($in{$f."_hour"} || "00",
				       $in{$f."_min"} || "00", $f);
			}
		else {
			$tx .= &hourmin_input($in{$f."_hour"} || "23",
				       $in{$f."_min"} || "59", $f);
			}
        push(@cols_row, $tx);
		}
	elsif ($f eq "action") {
		push(@cols_row, &action_input($f."_what",
					   $in{$f."_what"}, 1) );
		}
	elsif ($f eq "rule") {
        push(@cols_row, &ui_textbox($f."_what", $in{$f."_what"}, 5) );
		}
	else {
        push(@cols_row, &ui_textbox($f."_what", $in{$f."_what"}, 20) );
		}
    push(@cols_row, "&nbsp;&nbsp;" );
    print &ui_columns_row(\@cols_row) if ($i++%2 == 1); 
	}

# Show saved search
my @searches = &list_searches();
if (@searches) {
    @sel = ();
    print &ui_columns_row(["&nbsp;"],["colspan=8"]);
    push(@sel, ["", "&nbsp;", ($in{'save_name'} eq "" ? "selected" : "")]);
	foreach $s (@searches) {
        push(@sel,[$s->{'save_name'}, $s->{'save_name'}, ($in{'save_name'} eq $s->{'save_name'} ? "selected" : "") ]);
		}
    print &ui_columns_row([$text{'report_usesaved'}, &ui_select("save_name", undef, \@sel, 1)], ["", "colspan=7"] );
	}

print &ui_table_end();
print &ui_form_end(undef,undef,1);

print &ui_hr();

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
            print &ui_link($prog."start=0",
                        "<img src=images/lleft.gif border=0 align=middle alt='First page'>" );
            print &ui_link($prog."start=".($s - $config{'perpage'}),
                        "<img src=/images/left.gif border=0 align=middle alt='Previous page'>" );
        }
		print "<font size=+1>".&text('report_pos', $s+1, $e+1, scalar(@logs))."</font>\n";
		if ($e < @logs-1) {
            print &ui_link($prog."start=".($s + $config{'perpage'}),
                        "<img src=/images/right.gif border=0 align=middle alt='Next page'>" );
            print &ui_link($prog."start=".(int((@logs-1)/$config{'perpage'})*$config{'perpage'}),
                        "<img src=images/rright.gif border=0 align=middle alt='Last page'>" );
			}
		print "</center>\n";
		}
	else {
		# Can show them all
		$s = 0;
		$e = @logs - 1;
		}

    print &ui_columns_start([$text{'report_action'},
                            $text{'report_rule2'},
                            $text{'report_date'},
                            $text{'report_time'},
                            $text{'report_src'},
                            $text{'report_dst'},
                            $text{'report_dst_iface'},
                            $text{'report_proto'},
                            $text{'report_src_port'},
                            $text{'report_dst_port'}]);
	for($i=$s; $i<=$e; $i++) {
		$l = $logs[$i];
        @cols_row = ();
        push(@cols_row, $text{'rule_'.$l->{'action'}});
        push(@cols_row, ( $l->{'rule'} || "&nbsp;") );
		my @tm = localtime($l->{'time'});
        push(@cols_row, strftime("%d/%m/%Y", @tm) );
        push(@cols_row, strftime("%H:%M:%S", @tm) );
        push(@cols_row, $l->{'src'} );
        push(@cols_row, $l->{'dst'} );
        push(@cols_row, ( $l->{'dst_iface'} || "&nbsp;" ) );
        push(@cols_row, ( $l->{'proto'} || "&nbsp;" ) );
        push(@cols_row, ( $l->{'src_port'} || "&nbsp;" ) );
        push(@cols_row, ( $l->{'dst_port'} || "&nbsp;" ) );
		print &ui_columns_row(\@cols_row);
		}
	print &ui_columns_end();
	}
elsif ($anylogs) {
	print "<b>$text{'report_none'}</b><p>\n";
	}
else {
	print "<b>$text{'report_none2'}</b><p>\n";
	}


print &ui_hr();
my $hastable = 0;
if (@logs && &can_edit("report")) {
	# Show export button
    print &ui_table_start(undef,"width=100%",2);
    $hastable = 1;
    print &ui_form_start("list_welf.cgi", "post");
	foreach $i (keys %in) {
        print &ui_hidden($i, &html_escape($in{$i}) );
		}
    print &ui_columns_row([&ui_submit($text{'report_welf'}), $text{'report_welfdesc'}], ["valign=middle","valign=middle"] );
    print &ui_form_end(undef,undef,1);
	$anyrows++;
	}

if (@searchvars && &can_edit("report")) {
	# Show button to save this search
    print &ui_table_start(undef,"width=100%",2) if ( $hastable == 0 );
    print &ui_form_start("save_search.cgi", "post");
	foreach $i (keys %in) {
        print &ui_hidden($i, &html_escape($in{$i}) );
		}
    print &ui_columns_row([&ui_submit($text{'report_save'}),
                            $text{'report_savedesc'}."<br>".
                            "<b>".$text{'report_savename'}."</b>&nbsp;".
                            &ui_textbox("save_name", $in{'save_name'}, 30) ],
                            ["valign=middle","valign=middle"] ); 
    print &ui_form_end(undef,undef,1);
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

print &ui_table_end() if ( $hastable == 1 );

print &ui_hr() if ($anyrows);
&footer("", $text{'index_return'});

# date_input(day, month, year, prefix)
sub date_input
{
my $rv = "";
$rv .= &ui_textbox($_[3]."_day", $_[0], 2);
$rv .= "/";

my @sel;
foreach my $m (1..12) {
    push(@sel, [$m, $text{"smonth_$m"}, ($_[1] eq $m ? 'selected' : '') ] );
	}
$rv .= &ui_select($_[3]."_month", undef, \@sel, 1);
$rv .= "/";
$rv .= &ui_textbox($_[3]."_year", $_[2], 4);
$rv .= &date_chooser_button("$_[3]_day", "$_[3]_month", "$_[3]_year");
return $rv;
}

# hourmin_input(hour, min, prefix)
sub hourmin_input
{
my $rv = "";
$rv .= &ui_textbox($_[2]."_hour", $_[0], 2);
$rv .= ":";
$rv .= &ui_textbox($_[2]."_min", $_[1], 2);
return $rv;
}
