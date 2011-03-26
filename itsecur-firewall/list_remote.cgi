#!/usr/bin/perl
# Show a form for setting up remote logging

require './itsecur-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&can_edit_error("remote");
&header($text{'remote_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<form action=save_remote.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'remote_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

@servers = &servers::list_servers();
($server) = grep { $_->{'host'} eq $config{'remote_log'} } @servers;

# Show target host
print "<tr> <td><b>$text{'remote_host'}</b></td> <td>\n";
printf "<input type=radio name=host_def value=1 %s> %s\n",
	$server ? "" : "checked", $text{'no'};
printf "<input type=radio name=host_def value=0 %s> %s\n",
	$server ? "checked" : "", $text{'remote_to'};
printf "<input name=host size=20 value='%s'> %s\n",
	$server ? $server->{'host'} : "", $text{'remote_port'};
printf "<input name=port size=10 value='%s'></td> </tr>\n",
	$server ? $server->{'port'} : 10000;

# Show login and password
print "<tr> <td><b>$text{'remote_user'}</b></td> <td>\n";
printf "<input name=user size=20 value='%s'></td> </tr>\n",
	$server ? $server->{'user'} : "";

print "<tr> <td><b>$text{'remote_pass'}</b></td> <td>\n";
printf "<input name=pass type=password size=20 value='%s'></td> </tr>\n",
	$server ? $server->{'pass'} : "";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

print "<hr>\n";
&footer("", $text{'index_return'});

