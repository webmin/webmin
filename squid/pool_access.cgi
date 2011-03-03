#!/usr/local/bin/perl
# pool_access.cgi
# A form for editing or creating delay pool ACL

require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
$conf = &get_config();

if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'apool_header'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'apool_header1'}, "",
		undef, 0, 0, 0, &restart_button());
	@delay = @{$conf->[$in{'index'}]->{'values'}};
	}

print "<form action=pool_access_save.cgi>\n";
if (@delay) {
	print "<input type=hidden name=index value=$in{'index'}>\n";
	}
print "<input type=hidden name=idx value=$in{'idx'}>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'apool_pr'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'ahttp_a'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=action value=allow %s> $text{'ahttp_a1'}\n",
	$delay[1] eq "allow" ? "checked" : "";
printf "<input type=radio name=action value=deny %s> $text{'ahttp_d'}</td> </tr>\n",
	$delay[1] eq "allow" ? "" : "checked";

for($i=2; $i<@delay; $i++) { $match{$delay[$i]}++; }
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
if (@delay) {
	print "<input type=submit value='$text{'buttdel'}' name=delete>\n";
	}
print "</form>\n";

&ui_print_footer("edit_pool.cgi?idx=$in{'idx'}", $text{'pool_return'},
	"", $text{'index_return'});

