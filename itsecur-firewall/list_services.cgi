#!/usr/bin/perl
# list_services.cgi
# Displays a list of standard and custom services

require './itsecur-lib.pl';
&can_use_error("services");
&header($text{'services_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

@services = &list_services();
$edit = &can_edit("services");
print "<a href='edit_service.cgi?new=1'>$text{'services_add'}</a><br>\n"
	if ($edit);
print "<table border>\n";
print "<tr $tb> <td><b>$text{'service_name'}</b></td> ",
      "<td><b>$text{'service_ports'}</b></td> </tr>\n";
if (!$services[0]->{'standard'}) {
	print "<tr $tb> <td colspan=3><b>$text{'services_header1'}</b></td> </tr>\n";
	}
foreach $s (@services) {
	if ($s->{'standard'} && !$doneheader) {
		print "<tr $tb> <td colspan=3><b>$text{'services_header2'}</b></td> </tr>\n";
		$doneheader++;
		}
	print "<tr $cb>\n";
	if ($s->{'standard'}) {
		print "<td>$s->{'name'}</td>\n";
		}
	else {
		print "<td><a href='edit_service.cgi?idx=$s->{'index'}'>",
		      "$s->{'name'}</a></td>\n";
		}
	print "<td>";
	for($i=0; $i<@{$s->{'protos'}}; $i++) {
		print &protocol_name($s->{'protos'}->[$i], $s->{'ports'}->[$i]);
		print "\n";
		}
	for($i=0; $i<@{$s->{'others'}}; $i++) {
		print "<b>$s->{'others'}->[$i]</b>\n";
		}
	print "</td>\n";
	print "</tr>\n";
	}
print "</table>\n";
print "<a href='edit_service.cgi?new=1'>$text{'services_add'}</a><p>\n"
	if ($edit);

print "<hr>\n";
&footer("", $text{'index_return'});
