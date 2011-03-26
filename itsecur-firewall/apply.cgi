#!/usr/bin/perl
# apply.cgi
# Apply the firewall configuration

require './itsecur-lib.pl';
&can_edit_error("apply");
&ReadParse();
&header($text{'apply_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<p>$text{'apply_doing'}<br>\n";
&enable_routing();
$err = &apply_rules();
if ($err) {
	print &text('apply_failed', $err),"<p>\n";
	}
else {
	print "$text{'apply_done'}<p>\n";
	}

print "<hr>\n";
if ($in{'return'}) {
	&footer($ENV{'HTTP_REFERER'}, $text{'apply_return'});
	}
else {
	&footer("", $text{'index_return'});
	}
&remote_webmin_log("apply");
