#!/usr/local/bin/perl
# list_gen.cgi
# Display $generate entries

require './bind8-lib.pl';
&ReadParse();
$access{'gen'} || &error($text{'gen_ecannot'});
$zone = &get_zone_name($in{'index'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'recs_ecannot'});
$desc = &text('recs_header', &ip6int_to_net(&arpa_to_ip($dom)));
&ui_print_header($desc, $text{'gen_title'}, "");

@gens = grep { $_->{'generate'} } &read_zone_file($zone->{'file'}, $dom);
print "$text{'gen_desc'}<p>\n";
print "<form action=save_gen.cgi method=post>\n";
print "<input type=hidden name=index value='$in{'index'}'>\n";
print "<input type=hidden name=view value='$in{'view'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'gen_type'}</b></td> ",
      "<td><b>$text{'gen_range'}</b></td> ",
      "<td><b>$text{'gen_name'}</b></td> ",
      "<td><b>$text{'gen_value'}</b></td> ",
      "<td><b>$text{'gen_cmt'}</b></td> </tr>\n";
$i = 0;
if ($bind_version >= 9) {
	@types = ( 'PTR', 'CNAME', 'NS', 'A', 'AAAA', 'DNAME' );
	}
else {
	@types = ( 'PTR', 'CNAME', 'NS' );
	}
foreach $g (@gens, { }) {
	@gv = @{$g->{'generate'}};
	local @r = $gv[0] =~ /^(\d+)-(\d+)(\/(\d+))?$/ ? ( $1, $2, $4 ) : ( );
	print "<tr $cb>\n";
	print "<td><select name=type_$i>\n";
	foreach $t ('', @types) {
		printf "<option value='%s' %s>%s\n",
			$t, lc($gv[2]) eq lc($t) ? "selected" : "",
			$t ? $t : "&nbsp";
		}
	print "</select></td>\n";
	print "<td><input name=start_$i size=3 value='$r[0]'> -";
	print "<input name=stop_$i size=3 value='$r[1]'> $text{'gen_skip'}\n";
	print "<input name=skip_$i size=3 value='$r[2]'></td>\n";
	print "<td><input name=name_$i size=15 value='$gv[1]'></td>\n";
	print "<td><input name=value_$i size=15 value='$gv[3]'></td>\n";
	$cmt = join(" ", @gv[4..$#gv]);
	print "<td><input name=cmt_$i size=15 value='$g->{'comment'}'></td>\n";
	print "</tr>\n";
	$i++;
	}
print "</table>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td>\n";
print "<td align=right><input type=submit name=show ",
      "value='$text{'gen_show'}'></td>\n" if (@gens);
print "</tr></table></form>\n";

&ui_print_footer("edit_master.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'master_return'});

