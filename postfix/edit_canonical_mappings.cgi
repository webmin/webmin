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
# Edit a mapping

require './postfix-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'edit_mapping_title'}, "");


my $num;

if (!exists($in{'num'}))
{
    $num = &init_new_mapping(&get_current_value("sender_canonical_maps"));
}
else
{
    $num = $in{'num'};
}


my $mappingsaliases = &get_aliases();
my %alias;

foreach $trans (@{$aliases})
{
    if ($trans->{'number'} == $num) { %alias = %{$trans}; }
}    

print "<form action=save_alias.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_alias_title'}</b></td></tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr>\n";
print "<td><b>$text{'aliases_name'}</b></td> <td nowrap>\n";
print "<input type=hidden name=\"num\" value=\"$num\">";
print "<input name=\"name\" size=40 value=\"$alias{'name'}\"> </td>\n";
print "</tr>\n";

print "<tr>\n";
print "<td><b>$text{'aliases_value'}</b></td> <td nowrap>\n";
print "<input name=\"value\" size=40 value=\"$alias{'value'}\"> </td>\n";
print "</tr>\n";

print "</table></td></tr></table><p>\n";
print "<input type=submit value=\"$text{'alias_save'}\">\n";
print "<input type=submit name=delete value=\"$text{'delete_alias'}\"></form>\n";

print "<hr>\n";
print "<br>\n";

