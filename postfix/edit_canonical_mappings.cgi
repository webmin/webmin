#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
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

print &ui_hr();
print "<br>\n";

