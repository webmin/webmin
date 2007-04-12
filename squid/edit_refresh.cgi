#!/usr/local/bin/perl
# A form for editing or creating a refresh pattern rule

require './squid-lib.pl';
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ReadParse();
$conf = &get_config();

if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'refresh_create'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'refresh_edit'}, "",
		undef, 0, 0, 0, &restart_button());
	@v = @{$conf->[$in{'index'}]->{'values'}};
	}

print "<form action=save_refresh.cgi>\n";
if (@v) {
	print "<input type=hidden name=index value='$in{'index'}'>\n";
	}
print "<table border>\n";
print "<tr $tb> <td><b>$text{'refresh_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

# Show regular expression inputs
if ($v[0] eq "-i") {
	$caseless = shift(@v);
	}
print "<tr> <td><b>$text{'refresh_re'}</b></td> <td colspan=3>\n";
printf "<input name=re size=30 value='%s'></td> </tr>\n", $v[0];

print "<tr> <td></td> <td colspan=3>\n";
printf "<input type=checkbox name=caseless value=1 %s> %s</td> </tr>\n",
	$caseless ? "checked" : "", $text{'refresh_caseless'};

# Show min, max and percentage
print "<tr> <td><b>$text{'refresh_min'}</b></td>\n";
printf "<td><input name=min size=6 value='%s'> %s</td>\n",
	$v[1], $text{'ec_mins'};

print "<td><b>$text{'refresh_max'}</b></td>\n";
printf "<td><input name=max size=6 value='%s'> %s</td> </tr>\n",
	$v[3], $text{'ec_mins'};

$v[2] =~ s/\%$//;
print "<tr> <td><b>$text{'refresh_pc'}</b></td>\n";
printf "<td><input name=pc size=6 value='%s'> %%</td> </tr>\n",
	$v[2];

# Show options
%opts = map { $_, 1 } @v[4..$#v];
@known = ( "override-expire", "override-lastmod",
	   "reload-into-ims", "ignore-reload" );
print "<tr> <td valign=top><b>$text{'refresh_options'}</b></td> <td colspan=3>\n";
foreach $k (@known) {
	printf "<input type=checkbox name=options value=%s %s> %s<br>\n",
		$k, $opts{$k} ? "checked" : "", $text{'refresh_'.$k};
	delete($opts{$k});
	}
foreach $u (keys %opts) {
	print "<input type=hidden name=options value=$k>\n";
	}
print "</td> </tr>\n";

print "</table></td></tr></table>\n";
print "<input type=submit value='$text{'buttsave'}'>\n";
if (@v) {
	print "<input type=submit value='$text{'buttdel'}' name=delete>\n";
	}
print "</form>\n";

&ui_print_footer("list_refresh.cgi", $text{'refresh_return'},
	"", $text{'index_return'});

