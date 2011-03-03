#!/usr/local/bin/perl
# A form for editing or creating a header access control rule

require './squid-lib.pl';
$access{'headeracc'} || &error($text{'header_ecannot'});
&ReadParse();
$conf = &get_config();

if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'header_create_'.$in{'type'}} ||
				$text{'header_create'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'header_edit_'.$in{'type'}} ||
				$text{'header_edit'}, "",
		undef, 0, 0, 0, &restart_button());
	@v = @{$conf->[$in{'index'}]->{'values'}};
	}

print "<form action=save_headeracc.cgi>\n";
if (@v) {
	print "<input type=hidden name=index value='$in{'index'}'>\n";
	}
print &ui_hidden("type", $in{'type'});
print "<table border>\n";
print "<tr $tb> <td><b>$text{'header_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'header_name'}</b></td> <td colspan=3>\n";
printf "<input name=name size=30 value='%s'></td> </tr>\n", $v[0];

print "<tr> <td><b>$text{'ahttp_a'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=action value=allow %s> $text{'ahttp_a1'}\n",
	$v[1] eq "allow" ? "checked" : "";
printf "<input type=radio name=action value=deny %s> $text{'ahttp_d'}</td> </tr>\n",
	$v[1] eq "allow" ? "" : "checked";

for($i=2; $i<@v; $i++) { $match{$v[$i]}++; }
@acls = grep { !$done{$_->{'values'}->[0]}++ } &find_config("acl", $conf);
unshift(@acls, { 'values' => [ 'all' ] }) if ($squid_version >= 3);
$r = @acls; $r = 10 if ($r > 10);

print "<tr> <td valign=top><b>$text{'ahttp_ma'}</b></td>\n";
print "<td valign=top><select name=yes multiple size=$r width=100>\n";
foreach $a (@acls) {
	printf "<option %s>%s\n",
		$match{$a->{'values'}->[0]} ? "selected" : "",
		$a->{'values'}->[0];
	}
print "</select></td>\n";

print "<td valign=top><b>$text{'ahttp_dma'}</b></td>\n";
print "<td valign=top><select name=no multiple size=$r width=100>\n";
foreach $a (@acls) {
	printf "<option %s>%s\n",
		$match{"!$a->{'values'}->[0]"} ? "selected" : "",
		$a->{'values'}->[0];
	}
print "</select></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'>\n";
if (@v) {
	print "<input type=submit value='$text{'buttdel'}' name=delete>\n";
	}
print "</form>\n";

&ui_print_footer("list_headeracc.cgi", $text{'header_return'},
	"", $text{'index_return'});

