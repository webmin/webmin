#!/usr/local/bin/perl
# edit_push.cgi
# Display a list of hosts to which configurations are copied

require './cfengine-lib.pl';
&ui_print_header(undef, $text{'push_title'}, "", "push");

if (!&has_command($config{'cfrun'})) {
	print &text('push_ecmd', "<tt>$config{'cfrun'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

($hosts, $opts) = &get_cfrun_hosts();
print "<form action=save_push.cgi>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'push_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'push_domain'}</b></td>\n";
printf "<td><input name=domain size=30 value='%s'></td> </tr>\n",
	$opts->{'domain'};

print "<tr> <td><b>$text{'push_users'}</b></td>\n";
printf "<td><input name=access size=50 value='%s'> %s</td> </tr>\n",
	join(" ", split(/,/, $opts->{'access'})),
	&user_chooser_button("access", 1);

print "</table><table border>\n";
print "<tr> <td><b>$text{'push_host'}</b></td> ",
      "<td><b>$text{'push_opts'}</b></td> </tr>\n";
$i = 0;
foreach $h (@$hosts, [ ], [ ]) {
	print "<tr>\n";
	printf "<td><input name=host_$i size=30 value='%s'></td>\n", $h->[0];
	printf "<td><input name=opts_$i size=30 value='%s'></td>\n", $h->[1];
	print "</tr>\n";
	$i++;
	}
print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'></form>\n";

if (@$hosts) {
	print &ui_hr();
	print "<form action=push.cgi>\n";
	print "<table width=100%><tr>\n";
	print "<td><input type=submit value='$text{'push_push'}'></td>\n";
	print "<td>",&text('push_pushdesc',
			   "<tt>$config{'cfrun'}</tt>"),"</td>\n";
	print "</tr></table></form>\n";
	}

&ui_print_footer("", $text{'index_return'});

