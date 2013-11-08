#!/usr/local/bin/perl
# edit_pool.cgi
# A form for editing or creating a delay pool

require './squid-lib.pl';
&ReadParse();
$access{'delay'} || &error($text{'delay_ecannot'});
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'pool_title1'}, "", "edit_pool", 0, 0, 0,
		&restart_button());
	}
else {
	&ui_print_header(undef, $text{'pool_title2'}, "", "edit_pool", 0, 0, 0,
		&restart_button());
	@pools = &find_config("delay_class", $conf);
	($pool) = grep { $_->{'values'}->[0] == $in{'idx'} } @pools;
	@params = &find_config("delay_parameters", $conf);
	($param) = grep { $_->{'values'}->[0] == $in{'idx'} } @params;
	@access = &find_config("delay_access", $conf);
	@access = grep { $_->{'values'}->[0] == $in{'idx'} } @access;
	}

print "<form action=save_pool.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'pool_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'pool_num'}</b></td>\n";
if ($in{'new'}) {
	$pools = &find_value("delay_pools", $conf);
	print "<td>",$pools+1,"</td>\n";
	}
else {
	print "<td>$in{'idx'}</td>\n";
	}
print "</tr>\n";

$cls = $pool->{'values'}->[1] || 1;
print "<tr> <td><b>$text{'pool_class'}</b></td>\n";
print "<td><select name=class>\n";
foreach $c (1 .. ($squid_version >= 3 ? 5 : 3)) {
	printf "<option value=%s %s>%s - %s</option>\n",
		$c, $cls == $c ? "selected" : "",
		$c, $text{"delay_class_$c"};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'pool_agg'}</b></td>\n";
print "<td colspan=3>",&limit_field("agg",
	$cls == 5 ? undef : $param->{'values'}->[1]),"</td>\n";

print "<tr> <td><b>$text{'pool_ind'}</b></td>\n";
print "<td colspan=3>",&limit_field("ind",
	$param->{'values'}->[$cls == 2 ? 2 : 3]),"</td>\n";

print "<tr> <td><b>$text{'pool_net'}</b></td>\n";
print "<td colspan=3>",&limit_field("net",
	$cls == 3 || $cls == 4 ? $param->{'values'}->[2] : undef),"</td>\n";

if ($squid_version >= 3) {
	print "<tr> <td><b>$text{'pool_user'}</b></td>\n";
	print "<td colspan=3>",&limit_field("user",
		$cls == 4 ? $param->{'values'}->[4] : undef),"</td>\n";

	print "<tr> <td><b>$text{'pool_tag'}</b></td>\n";
	print "<td colspan=3>",&limit_field("tag",
		$cls == 5 ? $param->{'values'}->[1] : undef),"</td>\n";

	}

print "</table></td></tr></table>\n";

if (!$in{'new'}) {
	print "<p><table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'pool_aclheader'}</b></td> </tr>\n";
	print "<tr $cb> <td>\n";

	if (@access) {
		print "<table border width=100%>\n";
		print "<tr $tb><td width=10%><b>$text{'eacl_act'}</b></td>\n";
		print "<td><b>$text{'eacl_acls1'}</b></td>\n";
		print "<td width=5%><b>$text{'eacl_move'}</b></td> </tr>\n";
		$hc = 0;
		foreach $h (@access) {
			@v = @{$h->{'values'}};
			if ($v[1] eq "allow") {
				$v[1] = $text{'eacl_allow'};
			} else {
				$v[1] = $text{'eacl_deny'};
			}
			print "<tr $cb>\n";
			print "<td><a href=\"pool_access.cgi?index=",
			      "$h->{'index'}&idx=$in{'idx'}\">$v[1]</a></td>\n";
			print "<td>",&html_escape(join(' ', @v[2..$#v])),
			      "</td>\n";
			print "<td>\n";
			if ($hc != @access-1) {
				print "<a href=\"move_pool.cgi?$hc+1+",
				      "$in{'idx'}\"><img src=images/down.gif ",
				      "border=0></a>";
				}
			else { print "<img src=images/gap.gif>"; }
			if ($hc != 0) {
				print "<a href=\"move_pool.cgi?$hc+-1+",
				      "$in{'idx'}\"><img src=images/up.gif ",
				      "border=0></a>";
				}
			print "</td></tr>\n";
			$hc++;
			}
		print "</table>\n";
		}
	else {
		print "<b>$text{'pool_noacl'}</b><p>\n";
		}
	print "<a href='pool_access.cgi?new=1&idx=$in{'idx'}'>",
	      "$text{'pool_add'}</a>\n";

	print "</td></tr></table>\n";
	}
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

&ui_print_footer("edit_delay.cgi", $text{'delay_return'},
	"", $text{'index_return'});

# limit_field(name, value)
sub limit_field
{
local ($v1, $v2) = $_[1] =~ /^([0-9\-]+)\/([0-9\-]+)$/ ? ($1, $2) : ( -1, -1 );
local $unl = $v1 == -1 && $v2 == -1;
local $rv;
$rv .= sprintf "<input type=radio name=%s_def value=1 %s> %s\n",
		$_[0], $unl ? "checked" : "", $text{'delay_unlimited'};
$rv .= sprintf "<input type=radio name=%s_def value=0 %s>\n",
		$_[0], $unl ? "" : "checked";
$rv .= &unit_field("$_[0]_1", $unl ? "" : $v1).
	$text{'pool_limit1'}."&nbsp;&nbsp;";
$rv .= &unit_field("$_[0]_2", $unl ? "" : $v2).$text{'pool_limit2'};
return $rv;
}

# unit_field(name, value)
sub unit_field
{
local ($rv, $i, $u);
local @ud = ( .125, 1, 125, 1000, 125000, 1000000 );
if ($_[1] > 0) {
	for($u=@ud-1; $u>=1; $u--) {
		last if (!($_[1]%$ud[$u]));
		}
	}
else {
	$u = 1;
	}
$rv .= sprintf "<input name=%s_n size=8 value='%s'>\n",
		$_[0], $_[1] > 0 ? $_[1]/$ud[$u] : $_[1];
$rv .= "<select name=$_[0]_u>\n";
for($i=0; $i<@ud; $i++) {
	$rv .= sprintf "<option value=%s %s>%s</option>\n",
		$i, $i == $u ? "selected" : "", $text{'pool_unit'.$i};
	}
$rv .= "</select>\n";
return $rv;
}


