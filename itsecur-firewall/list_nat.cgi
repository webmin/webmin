#!/usr/bin/perl
# list_nat.cgi
# Show NAT enable form

require './itsecur-lib.pl';
&can_use_error("nat");
&header($text{'nat_title'}, "",
	undef, undef, undef, undef, &apply_button());

print &ui_hr();

print &ui_form_start("save_nat.cgi","post");
print &ui_table_start($text{'nat_header'},undef,2);

my ($iface, @nets) = &get_nat();
my @maps = grep { ref($_) } @nets;
my @nets = grep { !ref($_) } @nets;

print &ui_table_row($text{'nat_desc'},
                &ui_radio("nat", ( $iface ? 1 : 0 ), [
                    [0,$text{'nat_disabled'}."<br>"],[1,$text{'nat_enabled'}]
                ]).&iface_input("iface", $iface) );


my $style = "style='margin:0;padding:0;'";
my $tx = "";
$tx .= "<table $style><tr><td $style class='ui_form_value' valign=top>";
$tx .= "<table $style>";
my $i = 0;
foreach $n ((grep { $_ !~ /^\!/ } @nets), undef, undef, undef) {
	$tx .= "<tr><td $style valign=top>".&group_input("net_$i", $n, 1)."</td></tr>";
	$i++;
	}
$tx .= "</table></td>";

$tx .= "<td class='ui_form_label' valign=top>&nbsp;&nbsp;&nbsp;&nbsp;<b>$text{'nat_excl'}</b></td>";
$tx .= "<td class='ui_form_value' $style valign=top><table $style>";
$i = 0;
foreach $n ((grep { $_ =~ /^\!/ } @nets), undef, undef, undef) {
	$tx .= "<tr><td $style valign=top>".&group_input("excl_$i", $n =~ /^\!(.*)/ ? $1 : undef, 1)."</td></tr>";
	$i++;
	}
$tx .= "</table></td>";
$tx .= "</td></tr></table>";

print &ui_table_row($text{'nat_nets'}, $tx, undef, ["valign=top","valign=top"]);

$tx = "<table $style>";
$tx .= "<tr><td $style valign=top><b>$text{'nat_ext'}</b></td>".
      "<td $style valign=top>&nbsp;&nbsp;<b>$text{'nat_int'}</b></td>".
      "<td $style valign=top>&nbsp;&nbsp;&nbsp;&nbsp;<b>$text{'nat_virt'}</b></td></tr>";
$i = 0;
foreach $m (@maps, [ ], [ ], [ ]) {
	$tx .= "<tr>";	
	$tx .= "<td class='ui_form_value' $style>".&ui_textbox("ext_".$i, $m->[0], 20)."</td>",
	$tx .= "<td class='ui_form_value' $style>&nbsp;&nbsp;".&group_input("int_$i", $m->[1], 1)."</td>";
	$tx .= "<td class='ui_form_value' $style>&nbsp;&nbsp;&nbsp;&nbsp;".&iface_input("virt_$i", $m->[2], 1, 1, 1)."</td>";		
	$tx .= "</tr>";
	$i++;
	}
$tx .= "</table>";

print &ui_table_row($text{'nat_maps'}."</b><br>".$text{'nat_mapsdesc'}."<b>", $tx, undef, ["valign=top","valign=top"]);

print &ui_table_end();
print "<p>";
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);
&can_edit_disable("nat");

print &ui_hr();
&footer("", $text{'index_return'});
