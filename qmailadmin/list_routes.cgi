#!/usr/local/bin/perl
# list_routes.cgi
# Display a list of SMTP routes

require './qmail-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'routes_title'}, "");

@routes = &list_routes();
($defroute) = grep { !$_->{'from'} } @routes;
@routes = grep { $_ ne $defroute } @routes;
&route_form();

if ($in{'search'}) {
	# Restrict to search results
	@routes = grep { $_->{'from'} =~ /$in{'search'}/ } @routes;
	}
elsif ($config{'max_records'} && @routes > $config{'max_records'}) {
	# Show search form
	print $text{'routes_toomany'},"<br>\n";
	print "<form action=list_routes.cgi>\n";
	print "<input type=submit value='$text{'routes_go'}'>\n";
	print "<input name=search size=20></form>\n";
	undef(@routes);
	}

if (@routes) {
	# sort if needed
	if ($config{'sort_mode'} == 1) {
		@routes = sort { lc($a->{'from'}) cmp lc($b->{'from'}) }
			       @routes;
		}

	# render tables
        print &ui_form_start("delete_routes.cgi", "post");
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
	if ($config{'columns'} == 2) {
		$mid = int((@routes+1)/2);
		print "<table width=100%> <tr><td width=50% valign=top>\n";
		&routes_table(@routes[0..$mid-1]);
		print "</td><td width=50% valign=top>\n";
		if ($mid < @routes) { &routes_table(@routes[$mid..$#routes]); }
		print "</td></tr> </table><br>\n";
		}
	else {
		&routes_table(@routes);
		}
        print &select_all_link("d", 1),"\n";
        print &select_invert_link("d", 1),"<br>\n";
        print &ui_form_end([ [ "delete", $text{'routes_delete'} ] ]);
	}

print &ui_hr();
print "<form action=save_defroute.cgi>\n";
print "<input type=hidden name=idx value='$defroute->{'idx'}'>\n"
	if ($defroute);
print "<b>$text{'routes_defroute'}</b>\n";
printf "<input type=radio name=direct value=1 %s> %s\n",
	$defroute ? "" : "checked", $text{'routes_direct'};
printf "<input type=radio name=direct value=0 %s> %s\n",
	$defroute ? "checked" : "";
printf "<input name=defroute size=30 value='$defroute->{'to'}'>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

sub routes_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td width=5><br></td> <td><b>$text{'routes_from'}</b></td> ",
      "<td><b>$text{'routes_to'}</b></td> </tr>\n";
foreach $r (@_) {
	print "<tr $cb>\n";
	print "<td width=5>",&ui_checkbox("d", $r->{'from'}),"</td>\n";
	print "<td valign=top><a href=\"edit_route.cgi?idx=$r->{'idx'}\">",
	      &html_escape($r->{'from'}),"</a></td>\n";
	print "<td>",$r->{'port'} ? &html_escape("$r->{'to'}:$r->{'port'}") :
		     $r->{'to'} ? &html_escape($r->{'to'}) :
			  "<i>$text{'routes_direct'}</i>","</td> </tr>\n";
	}
print "</table>\n";
}

