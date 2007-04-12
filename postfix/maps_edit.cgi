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
# Edit maps

require './postfix-lib.pl';
&ReadParse();

&ui_print_header(undef, $text{'canonical_edit_title'}, "");


my $which;

if ($in{'which'} eq $text{'edit_canonical_maps'}) { $which = 1; }
elsif ($in{'which'} eq $text{'edit_recipient_canonical_maps'}) { $which = 2; }
elsif ($in{'which'} eq $text{'edit_sender_canonical_maps'}) { $which = 3; }
else { &error($text{'internal_error'}); }



# double-table displaying all mappings

my $mappingsaliases = &get_aliases();

print "Click on any alias to edit its properties:\n<br>\n";
print "<table width=100%> <tr><td width=50% valign=top>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'aliases_name'}</b></td> ",
      "<td><b>$text{'aliases_value'}</b></td> </tr>\n";

my $split_index = int(($#{$aliases})/2);
my $i = -1;

foreach $alias (@{$aliases})
{
    print "<tr $cb>\n";
    print "<td><a href=\"edit_alias.cgi?num=$alias->{'number'}\">$alias->{'name'}</a></td>\n";
    print "<td>$alias->{'value'}</td>\n</tr>\n";
    $i++;
    if ($i == $split_index)
    {
	print "</table></td><td width=50% valign=top>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'aliases_name'}</b></td> ",
	"<td><b>$text{'aliases_value'}</b></td> </tr>\n";
    }
}

print "</tr></td></table>\n";
print "</table>\n";


# new alias form

print "<table cellpadding=5 width=100%><tr><td>\n";
print "<form action=edit_alias.cgi>\n";
print "<input type=submit value=\"$text{'new_alias'}\">\n";
print "</td> <td width=\"99%\">$text{'new_aliasmsg'}\n";
print "</td></tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});


print "$which <hr>\n";
print "<br>\n";

