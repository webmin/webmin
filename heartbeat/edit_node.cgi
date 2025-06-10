#!/usr/local/bin/perl
# edit_node.cgi
# Edit a node in the haresources file

require './heartbeat-lib.pl';
&ReadParse();
&foreign_require("init", "init-lib.pl");

if ($in{'new'}) {
	&ui_print_header(undef, $text{'node_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'node_edit'}, "");
	@res = &list_resources();
	$res = $res[$in{'idx'}];
	}

print "<form action=save_node.cgi>\n";
print "<input type=hidden name=new value='$in{'new'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'node_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'node_node'}</b></td>\n";
printf "<td><input name=node size=40 value='%s'></td> </tr>\n",
	$res->{'node'};

print "<tr> <td valign=top><b>$text{'node_ips'}</b></td>\n";
print "<td><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'node_ip'}</b></td> ",
      "<td><b>$text{'node_cidr'}</b></td> ",
      "<td><b>$text{'node_broad'}</b></td> </tr>\n";
$i = 0;
foreach $a (@{$res->{'ips'}}, "") {
	local @a = split(/\//, $a);
	print "<tr $cb> <td><input name=ip_$i size=15 value='$a[0]'></td>\n";
	printf "<td><input type=radio name=cidr_def_$i value=1 %s> %s\n",
		$a[1] ? "" : "checked", $text{'default'};
	printf "<input type=radio name=cidr_def_$i value=0 %s>\n",
		$a[1] ? "checked" : "";
	print "<input name=cidr_$i size=4 value='$a[1]'></td>\n";
	printf "<td><input type=radio name=broad_def_$i value=1 %s> %s\n",
		$a[2] ? "" : "checked", $text{'default'};
	printf "<input type=radio name=broad_def_$i value=0 %s>\n",
		$a[2] ? "checked" : "";
	print "<input name=broad_$i size=15 value='$a[2]'></td> </tr>\n";
	$i++;
	}
print "</table></td> </tr>\n";

@acts = map { /^(\S+)/; $1 } &foreign_call("init", "list_actions");
opendir(DIR, $resource_d);
while($f = readdir(DIR)) {
	push(@acts, $f) if ($f !~ /^\./);
	}
closedir(DIR);
print "<tr> <td valign=top><b>$text{'node_servs'}</b></td>\n";
print "<td><table border width=100%>\n";
print "<tr $tb> <td><b>$text{'node_serv'}</b></td> ",
      "<td><b>$text{'node_args'}</b></td> </tr>\n";
$i = 0;
foreach $a (@{$res->{'servs'}}, "") {
	local @a = split(/::/, $a);
	print "<tr $cb> <td><select name=serv_$i>\n";
	printf "<option value='' %s>&nbsp;</option>\n",
		$a[0] ? "" : "selected";
	local $found;
	foreach $s (@acts) {
		printf "<option %s>%s</option>\n",
			$a[0] eq $s ? "selected" : "", $s;
		$found++ if ($a[0] eq $s);
		}
	if (!$found && $a[0]) {
		print "<option selected>$a[0]</option>\n";
		}
	print "</select></td>\n";
	printf "<td><input name=args_$i size=40 value='%s'></td> </tr>\n",
		join(" ", @a[1..$#a]);
	$i++;
	}
print "</table></td> </tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'save'}'></td>\n";
print "<td align=right><input type=submit name=delete ",
      "value='$text{'delete'}'></td> </tr>\n";
print "</table>\n";

print "</form>\n";
&ui_print_footer("edit_res.cgi", $text{'res_return'});

