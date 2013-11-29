#!/usr/local/bin/perl
# edit_watch.cgi
# Display a new or existing watch

require './mon-lib.pl';
&ReadParse();
$conf = &get_mon_config();
$watch = $conf->[$in{'idx'}];

&ui_print_header(undef, $text{'watch_title'}, "");

print "<form action=save_watch.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'watch_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'watch_group'}</b></td>\n";
print "<td><select name=group>\n";
foreach $s (&find("hostgroup", $conf)) {
	printf "<option %s>%s</option>\n",
		$s eq $watch->{'values'}->[0] ? "selected" : "",
		$s->{'values'}->[0];
	$found++ if ($s eq $watch->{'values'}->[0]);
	}
print "<option selected>$watch->{'values'}->[0]</option>\n" if (!$found);
print "</select></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'watch_services'}</b></td>\n";
print "<td colspan=3> <table border width=100%>\n";
print "<tr $tb> <td><b>$text{'watch_service'}</b></td> ",
      "<td><b>$text{'watch_monitor'}</b></td> ",
      "<td><b>$text{'watch_interval'}</b></td> ",
      "<td><b>$text{'watch_periods'}</b></td> </tr>\n";
foreach $s (&find("service", $watch->{'members'})) {
	print "<tr $cb>\n";
	print "<td><a href='edit_service.cgi?idx=$in{'idx'}&",
	      "sidx=$s->{'index'}'>$s->{'value'}</a></td>\n";
	local $mon = &find_value("monitor", $s->{'members'});
	print "<td>$mon</td>\n";
	local $int = &find_value("interval", $s->{'members'});
	print "<td>$int</td>\n";
	local @pers = &find("period", $s->{'members'});
	local $pers = join("&nbsp;,&nbsp;", map { $_->{'value'} } @pers);
	print "<td>$pers</td>\n";
	print "</tr>\n";
	}
print "</table>\n";
print "<a href='edit_service.cgi?idx=$in{'idx'}&new=1'>",
      "$text{'watches_sadd'}</a>\n";
print "</td> </tr>\n";

print "</table></td></tr></table>\n";

print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("list_watches.cgi", $text{'watches_return'});

