#!/usr/local/bin/perl
# edit_switch.cgi
# Display client service switches

require './nis-lib.pl';
&ui_print_header(undef, $text{'switch_title'}, "");
@switch = &get_nsswitch_conf();

print "<form action=save_switch.cgi method=post>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'switch_service'}</b></td> ",
      "<td><b>$text{'switch_order'}</b></td> </tr>\n";

foreach $s (@switch) {
	local @o = split(/\s+/, $s->{'order'});
	$max = @o if (@o > $max);
	}

foreach $s (@switch) {
	local $sv = $s->{'service'};
	print "<tr $cb>\n";
	print "<td><b>",$text{"desc_$sv"} ? $text{"desc_$sv"} :
			$s->{'service'},"</b></td> <td>\n";
	if ($s->{'order'} =~ /\[/) {
		print "<input name=order_$sv size=60 value='$s->{'order'}'>\n";
		}
	else {
		local @o = split(/\s+/, $s->{'order'});
		local @sources = ("");
		if (defined(&switch_sources)) {
			push(@sources, &switch_sources());
			}
		else {
			push(@sources, split(/\s+/, $config{'sources'}));
			}
		print "<table width=100% cellpadding=0 cellspacing=0><tr>\n";
		for($i=1; $i<=$max+1; $i++) {
			print "<td><select name=order_${sv}_${i}>\n";
			foreach $sc (@sources) {
				if ($sc =~ /(\S+)=(\S+)/ && $1 eq $sv) {
					printf "<option value='%s' %s>%s</option>\n",
					    $2,
					    $o[$i-1] eq $2 ? 'selected' : '',
					    $text{"order_$2"};
					}
				elsif ($sc !~ /=/) {
					printf "<option value='%s' %s>%s</option>\n",
					    $sc,
					    $o[$i-1] eq $sc ? 'selected' : '',
					    $text{"order_$sc"};
					}
				}
			print "</select></td>";
			}
		print "</tr></table>\n";
		}
	push(@list, $sv);
	print "</td> </tr>\n";
	}
print "</table>\n";
printf "<input type=hidden name=list value='%s'>\n",
	join(" ", @list);
print "<input type=submit value='$text{'save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

