#!/usr/local/bin/perl
# list_aliases.cgi
# Displays a list of all aliases
# XXX .qmail-default and .qmail-foo-default alias support

require './qmail-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'aliases_title'}, "");

@aliases = &list_aliases();
&alias_form();

if ($in{'search'}) {
	# Restrict to search results
	@aliases = grep { $_ =~ /$in{'search'}/ } @aliases;
	}
elsif ($config{'max_records'} && @aliases > $config{'max_records'}) {
	# Show search form
	print $text{'aliases_toomany'},"<br>\n";
	print "<form action=list_aliases.cgi>\n";
	print "<input type=submit value='$text{'aliases_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@aliases);
	}

if (@aliases) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@aliases = sort { lc($a) cmp lc($b) } @aliases;
		}
	@aliases = map { &get_alias($_) } @aliases;

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
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
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
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
        print &ui_form_end([ [ "delete", $text{'aliases_delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

sub aliases_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td width=5><br></td> <td><b>$text{'aliases_addr'}</b></td> ",
      "<td><b>$text{'aliases_to'}</b></td> </tr>\n";
foreach $a (@_) {
	local $n = $a->{'name'};
	$n =~ s/:/\./g;
	print "<tr $cb>\n";
	print "<td width=5>",&ui_checkbox("d", $a->{'name'}),"</td>\n";
	print "<td valign=top><a href=\"edit_alias.cgi?name=$a->{'name'}\">",
	      &html_escape($n),"</a></td>\n";
	print "<td>\n";
	foreach $v (@{$a->{'values'}}) {
		($anum, $astr) = &alias_type($v);
		print &text("aliases_type$anum",
			    "<tt>".&html_escape($astr)."</tt>"),"<br>\n";
		}
	if (!@{$a->{'values'}}) {
		print "<i>$text{'aliases_none'}</i>\n";
		}
	print "</td> </tr>\n";
	}
print "</table>\n";
}

