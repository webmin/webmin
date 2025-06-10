#!/usr/local/bin/perl
# list_virts.cgi
# Display a list of virtual domain mappings

require './qmail-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'virts_title'}, "");

@virts = &list_virts();
print &text('virts_desc', "list_aliases.cgi"),"<p>\n";
&virt_form();

if ($in{'search'}) {
	# Restrict to search results
	@virts = grep { $_->{'from'} =~ /$in{'search'}/ } @virts;
	}
elsif ($config{'max_records'} && @virts > $config{'max_records'}) {
	# Show search form
	print $text{'virts_toomany'},"<br>\n";
	print "<form action=list_virts.cgi>\n";
	print "<input type=submit value='$text{'virts_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@virts);
	}

if (@virts) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@virts = sort { lc($a->{'from'}) cmp lc($b->{'from'}) }
			       @virts;
		}

	# render tables
        print &ui_form_start("delete_virts.cgi", "post");
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
	if ($config{'columns'} == 2) {
		$mid = int((@virts+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&virts_table(@virts[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @virts) { &virts_table(@virts[$mid..$#virts]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&virts_table(@virts);
		}
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
        print &ui_form_end([ [ "delete", $text{'virts_delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

sub virts_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td width=5><br></td> <td><b>$text{'virts_from'}</b></td> ",
      "<td><b>$text{'virts_prepend'}</b></td> </tr>\n";
foreach $v (@_) {
	print "<tr $cb>\n";
	print "<td width=5>",&ui_checkbox("d", $v->{'from'}),"</td>\n";
	print "<td valign=top><a href=\"edit_virt.cgi?idx=$v->{'idx'}\">",
	      ($v->{'from'} ? &html_escape($v->{'from'})
			    : "<i>$text{'virts_all'}</i>"),"</a></td>\n";
	print "<td>",($v->{'prepend'} ? &html_escape($v->{'prepend'}) :
	      "<i>$text{'virts_none'}</i>"),"</td> </tr>\n";
	}
print "</table>\n";
}

