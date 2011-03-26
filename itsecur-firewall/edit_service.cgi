#!/usr/bin/perl
# edit_service.cgi
# Show a form for editing or creating a user-defined

require './itsecur-lib.pl';
&can_use_error("services");
&ReadParse();
if ($in{'new'}) {
	&header($text{'service_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	}
else {
	&header($text{'service_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	@services = &list_services();
	#$service = $services[$in{'idx'}];
		if (defined($in{'idx'})) {
		$service = $services[$in{'idx'}];
		}
	else {
		($service) = grep { $_->{'name'} eq $in{'name'} } @services;
		$in{'idx'} = $services->{'index'};
		}	
	}
print "<hr>\n";

print "<form action=save_service.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'service_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show service name input
print "<tr> <td><b>$text{'service_name'}</b></td>\n";
printf "<td><input name=name size=20 value='%s'></td> </tr>\n",
	$service->{'name'};

# Show protocols and ports
print "<tr> <td valign=top><b>$text{'service_ports'}</b></td>\n";
print "<td><table border>\n";
print "<tr $tb> <td><b>$text{'service_proto'}</b></td> ",
      "<td><b>$text{'service_port'}</b></td> </tr>\n";
for($i=0; $i<@{$service->{'protos'}}+6; $i++) {
	print "<tr>\n";
	print "<td>",&protocol_input(
		"proto_$i", $service->{'protos'}->[$i]),"</td>\n";
	printf "<td><input name=port_%d size=20 value='%s'></td>\n",
		$i, $service->{'ports'}->[$i];
	print "</tr>\n";
	}
print "</table></td> </tr>\n";

# Show member services
print "<tr> <td valign=top><b>$text{'service_members'}</b></td>\n";
print "<td>",&service_input("others",
		join(",", @{$service->{'others'}}), 0, 1),"</td> </tr>\n";

print "</table></td></tr></table>\n";
if ($in{'new'}) {
	print "<input type=submit value='$text{'create'}'>\n";
	}
else {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
print "</form>\n";
&can_edit_disable("services");

print "<hr>\n";
&footer("list_services.cgi", $text{'services_return'});


