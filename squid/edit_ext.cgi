#!/usr/local/bin/perl
# edit_ext.cgi
# Display a form for creating or editing an external ACL type

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
$conf = &get_config();

if ($in{'new'}) {
	&ui_print_header(undef, $text{'ext_title1'}, "", undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'ext_title2'}, "", undef, 0, 0, 0, &restart_button());
	$ext = $conf->[$in{'index'}];
	$ea = &parse_external($ext);
	}

print "<form action=save_ext.cgi method=post>\n";
print "<input type=hidden name=index value='$in{'index'}'>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";

print "<table border>\n";
print "<tr $tb> <td><b>$text{'ext_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'ext_name'}</b></td>\n";
printf "<td><input name=name size=20 value='%s'></td> </tr>\n",
	$ea->{'name'};

print "<tr> <td><b>$text{'ext_format'}</b></td>\n";
printf "<td><input name=format size=60 value='%s'></td> </tr>\n",
	&html_escape($ea->{'format'});

$o = $ea->{'opts'};
foreach $on ('ttl', 'negative_ttl', 'concurrency', 'cache') {
	print "<tr> <td><b>",$text{'ext_'.$on},"</b></td>\n";
	printf "<td><input type=radio name=%s_def value=1 %s> %s\n",
		$on, defined($o->{$on}) ? "" : "checked", $text{'default'};
	printf "<input type=radio name=%s_def value=0 %s>\n",
		$on, defined($o->{$on}) ? "checked" : "";
	printf "<input name=%s size=6 value='%s'> %s</td> </tr>\n",
		$on, $o->{$on}, $text{'ext_'.$on.'_u'};
	}

print "<tr> <td><b>$text{'ext_program'}</b></td>\n";
printf "<td><input name=program size=60 value='%s'></td> </tr>\n",
	&html_escape(join(" ", $ea->{'program'}, @{$ea->{'args'}}));

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'save'}'>\n";
print "<input type=submit name=delete value='$text{'delete'}'>\n"
	if (!$in{'new'});
print "</form>\n";

&ui_print_footer("edit_acl.cgi?mode=external", $text{'acl_return'});

