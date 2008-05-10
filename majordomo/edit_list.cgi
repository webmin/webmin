#!/usr/local/bin/perl
# edit_list.cgi
# Edit an existing mailing list

require './majordomo-lib.pl';
&ReadParse();
%access = &get_module_acl();
&can_edit_list(\%access, $in{'name'}) ||
	&error($text{'edit_ecannot'});
$desc = &text('edit_for', "<tt>".&html_escape($in{'name'})."</tt>");
&ui_print_header($desc, $text{'edit_title'}, "");

@links = ( "edit_members.cgi", "edit_info.cgi", "edit_subs.cgi",
	   "edit_mesg.cgi", "edit_access.cgi", "edit_head.cgi",
	   "edit_misc.cgi" );
foreach $a (&foreign_call($aliases_module, "list_aliases",
			  &get_aliases_file())) {
	if ($a->{'name'} =~ /-digestify$/i &&
	    $a->{'value'} =~ /\s$in{'name'}\s/i) {
		$isdigest++;
		}
	}
if ($isdigest) {
	push(@links, "edit_digest.cgi");
	}
map { s/edit_(\S+).cgi/images\/$1.gif/ } (@icons = @links);
map { s/edit_(\S+).cgi/$text{"$1_title"}/ } (@titles = @links);
@links = map { $_."?name=".&urlize($in{'name'}) } @links;
&icons_table(\@links, \@titles, \@icons);

print &ui_hr();
print "<table>\n";
print "<form action=delete_list.cgi>\n";
print "<input type=hidden name=name value=\"$in{'name'}\">\n";
print "<tr> <td><input type=submit value=\"$text{'edit_delete'}\"></td>\n";
print "<td>$text{'edit_deletemsg'}</td> </tr>\n";
print "</form>\n";
print "</table>\n";

&ui_print_footer("", $text{'index_return'});

