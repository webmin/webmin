#!/usr/local/bin/perl
# Show a form for editing or creating a log filter

require './syslog-ng-lib.pl';
&ReadParse();

# Show title and get the filter
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'filter_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'filter_title2'}, "");
	@filters = &find("filter", $conf);
	($filter) = grep { $_->{'value'} eq $in{'name'} } @filters;
	$filter || &error($text{'filter_egone'});
	}

# Form header
print &ui_form_start("save_filter.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'filter_header'}, undef, 2);

# Filter name
print &ui_table_row($text{'filter_name'},
		    &ui_textbox("name", $filter->{'value'}, 20));

# See if the conditions are simple (1 or more of facility, level, matches
# and program, and separated)
$simple = 1;
foreach $m (@{$filter->{'members'}}) {
	if (ref($m)) {
		if ($simple{$m->{'name'}}) {
			# Already done this type .. not simple any more
			$simple = 0;
		        }
		else {
			$simple{$m->{'name'}} = $m;
			}
		}
	elsif ($m eq "and") {
		# 'and' separator .. we can handle this
		}
	else {
		$simple = 0;
		}
	}

# Build table for simple mode
%simple = ( ) if (!$simple);
$stable = "<table>\n";

# Priority
$p = $simple{'priority'};
@pris = &list_priorities();
if ($p) {
	if ($p->{'values'}->[1] eq "..") {
		$i1 = &indexof(@pris, $p->{'values'}->[0]);
		$i2 = &indexof(@pris, $p->{'values'}->[2]);
		if ($i1 >= 0 && $i2 >= 0) {
			%gotpris = map { $pris[$_], 1 } ($i1 .. $i2);
			}
		}
	else {
		%gotpris = map { $_, 1 } grep { $_ ne "," } @{$p->{'values'}};
		}
	}
$stable .= "<tr> <td><b>".&ui_checkbox("priority", 1, $text{'filter_priority'},
				       $p ? 1 : 0)."</b></td>\n";
$stable .= "<td>";
foreach $p (@pris) {
	$stable .= &ui_checkbox("pri", $p, $p, $gotpris{$p})."\n";
	}
$stable .= "</td> </tr>\n";

# Facility
$p = $simple{'facility'};
@facs = &list_facilities();
if ($p) {
	%gotfacs = map { $_, 1 } grep { $_ ne "," } @{$p->{'values'}};
	}
$stable .= "<tr> <td valign=top><b>".
  &ui_checkbox("facility", 1, $text{'filter_facility'}, $p ? 1 : 0).
  "</b></td>\n";
$stable .= "<td><table>";
$i = 0;
foreach $f (@facs) {
	$stable .= "<tr>\n" if ($i % 8 == 0);
	$stable .= "<td>".&ui_checkbox("fac", $f, $f, $gotfacs{$f})."</td>\n";
	$stable .= "<tr>\n" if ($i % 8 == 7);
	$i++;
	}
$stable .= "</table></td> </tr>\n";

# Program
$p = $simple{'program'};
$stable .= "<tr> <td><b>".&ui_checkbox("program", 1, $text{'filter_program'},
				       $p ? 1 : 0)."</b></td>\n";
$stable .= "<td>".&ui_textbox("prog", $p ? $p->{'value'} : undef, 30).
	   "</td> </tr>\n";

# Match RE
$p = $simple{'match'};
$stable .= "<tr> <td><b>".&ui_checkbox("match", 1, $text{'filter_match'},
				       $p ? 1 : 0)."</b></td>\n";
$stable .= "<td>".&ui_textbox("re", $p ? $p->{'value'} : undef, 50).
	   "</td> </tr>\n";

# Sending hostname
$p = $simple{'host'};
$stable .= "<tr> <td><b>".&ui_checkbox("host", 1, $text{'filter_host'},
				       $p ? 1 : 0)."</b></td>\n";
$stable .= "<td>".&ui_textbox("hn", $p ? $p->{'value'} : undef, 30).
	   "</td> </tr>\n";

# Sending IP
$p = $simple{'netmask'};
if ($p) {
      ($net, $mask) = split(/\//, $p->{'value'});
      }
$stable .= "<tr> <td><b>".&ui_checkbox("netmask", 1, $text{'filter_netmask'},
				       $p ? 1 : 0)."</b></td>\n";
$stable .= "<td>".&ui_textbox("net", $net, 15)."/".
		  &ui_textbox("mask", $mask, 15)."</td> </tr>\n";

$stable .= "</table>\n";

# Build text area for complex mode
local @w;
foreach $m (@{$filter->{'members'}}) {
	if (ref($m)) {
		local ($line) = &directive_lines($m);
		$line =~ s/\s*;\s*$//;
		push(@w, $line);
		}
	else {
		push(@w, $m);
		}
	}
$ctable = &ui_textarea("bool", join(" ", @w), 5, 80);

# Show the two modes
print "<tr> <td colspan=2>\n";
print &ui_oneradio("mode", 0, "<b>$text{'filter_mode0'}</b>", $simple),"<br>\n";
print $stable,"<br>\n";
print &ui_oneradio("mode", 1, "<b>$text{'filter_mode1'}</b>",!$simple),"<br>\n";
print $ctable,"<br>\n";
print "</td> </tr>\n";

# Form footer and buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_filters.cgi", $text{'filters_return'});
