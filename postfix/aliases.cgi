#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
# 
# Manages aliases for Postfix
#
# << Here are all options seen in Postfix sample-aliases.cf >>


require './postfix-lib.pl';

$access{'aliases'} || &error($text{'aliases_ecannot'});
&ui_print_header(undef, $text{'aliases_title'}, "", "aliases");



# alias general options

print "<form action=save_opts_aliases.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'aliasopts_title'}</b></td></tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr>\n";
&option_freefield("alias_maps", 60);
print "</tr>\n";

print "<tr>\n";
&option_freefield("alias_database", 60);
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "$text{'aliases_warning'}<p><br>\n";
print "<input type=submit value=\"$text{'opts_save'}\"></form>\n";
print "<hr>\n";
print "<br>\n";




# double-table displaying all aliases

my @afiles = &get_aliases_files(&get_current_value("alias_maps"));
my @aliases = &list_aliases(\@afiles);
if ($config{'sort_mode'} == 1) {
	@aliases = sort { lc($a->{'name'}) cmp lc($b->{'name'}) }
			@aliases;
	}

print $text{'aliases_click'}, "\n<br>\n";

# find a good place to split
$lines = 0;
for($i=0; $i<@aliases; $i++) {
	$aline[$i] = $lines;
	$al = scalar(@{$aliases[$i]->{'values'}});
	$lines += ($al ? $al : 1);
	}
$midline = int(($lines+1) / 2);
for($mid=0; $mid<@aliases && $aline[$mid] < $midline; $mid++) { }

# render tables
print &ui_form_start("delete_aliases.cgi", "post");
@links = ( &select_all_link("d", 1),
	   &select_invert_link("d", 1) );
print &ui_links_row(\@links);
if ($config{'columns'} == 2) {
	print "<table width=100%> <tr><td width=50% valign=top>\n";
	&aliases_table(@aliases[0..$mid-1]);
	print "</td><td width=50% valign=top>\n";
	if ($mid < @aliases) { &aliases_table(@aliases[$mid..$#aliases]); }
	print "</td></tr> </table><br>\n";
	}
else {
	&aliases_table(@aliases);
	}
print &ui_links_row(\@links);
print &ui_form_end([ [ "delete", $text{'aliases_delete'} ] ]);

# new alias form
print "<table cellpadding=5 width=100%><tr><td>\n";
print "<form action=edit_alias.cgi>\n";
print "<input type=hidden name=new value=1>\n";
print "<input type=submit value=\"$text{'new_alias'}\">\n";
print "</td> <td width=\"99%\">$text{'new_aliasmsg'}\n";
print "</td></tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

sub aliases_table
{
local @tds = ( "width=5", "valign=top", "valign=top" );
print &ui_columns_start([ "",
			  $text{'aliases_addr'},
			  $text{'aliases_to'},
			  $config{'show_cmts'} ? ( $text{'mapping_cmt'} )
					       : ( ) ], 100, 0, \@tds);
foreach $a (@_) {
	local @cols;
	push(@cols, "<a href=\"edit_alias.cgi?num=$a->{'num'}\">".
	      ($a->{'enabled'} ? "" : "<i>").&html_escape($a->{'name'}).
	      ($a->{'enabled'} ? "" : "</i>")."</a>");
	local $vstr;
	foreach $v (@{$a->{'values'}}) {
		($anum, $astr) = &alias_type($v);
		$vstr .= &text("aliases_type$anum",
			    "<tt>".&html_escape($astr)."</tt>")."<br>\n";
		}
	$vstr ||= "<i>$text{'aliases_none'}</i>\n";
	push(@cols, $vstr);
	push(@cols, &html_escape($a->{'cmt'})) if ($config{'show_cmts'});
	print &ui_checked_columns_row(\@cols, \@tds, "d", $a->{'name'});
	}
print &ui_columns_end();
}

