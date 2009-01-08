#!/usr/local/bin/perl
# edit_host.cgi
# Display a form for editing or creating an allowed host

require './postgresql-lib.pl';
&ReadParse();
$v = &get_postgresql_version();
if ($in{'new'}) {
	$type = $in{'new'};
	&ui_print_header(undef, $text{"host_create"}, "");
	$host = { 'type' => $type, 'netmask' => '0.0.0.0',
		  'auth' => 'trust', 'db' => 'all' };
	}
else {
	@all = &get_hba_config($v);
	$host = $all[$in{'idx'}];
	$type = $host->{'type'};
	&ui_print_header(undef, $text{"host_edit"}, "");
	}

# Start of form block
print &ui_form_start("save_host.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'host_header'}, "width=100%", 2);

# XXX
$mode = $type eq 'local' ? 3 :
	$host->{'cidr'} ne '' ? 4 :
	$host->{'netmask'} eq '0.0.0.0' ? 0 :
	$host->{'netmask'} eq '255.255.255.255' ? 1 : 2;
print "<tr> <td valign=top><b>$text{'host_address'}</b></td> <td colspan=2>\n";
printf "<input type=radio name=addr_mode value=3 %s> %s<br>\n",
	$mode == 3 ? 'checked' : '', $text{'host_local'};

printf "<input type=radio name=addr_mode value=0 %s> %s<br>\n",
	$mode == 0 ? 'checked' : '', $text{'host_any'};

printf "<input type=radio name=addr_mode value=1 %s> %s\n",
	$mode == 1 ? 'checked' : '', $text{'host_single'};
printf "<input name=host size=20 value='%s'><br>\n",
	$mode == 1 ? $host->{'address'} : '';

printf "<input type=radio name=addr_mode value=2 %s> %s\n",
	$mode == 2 ? 'checked' : '', $text{'host_network'};
printf "<input name=network size=20 value='%s'> %s\n",
	$mode == 2 ? $host->{'address'} : '', $text{'host_netmask'};
printf "<input name=netmask size=20 value='%s'><br>\n",
	$mode == 2 ? $host->{'netmask'} : '';

printf "<input type=radio name=addr_mode value=4 %s> %s\n",
	$mode == 4 ? 'checked' : '', $text{'host_network'};
printf "<input name=network2 size=20 value='%s'> %s\n",
	$mode == 4 ? $host->{'address'} : '', $text{'host_cidr'};
printf "<input name=cidr size=5 value='%s'></td> </tr>\n",
	$mode == 4 ? $host->{'cidr'} : '';

if ($type eq "hostssl" || $v >= 7.3) {
	print "<tr> <td></td> <td colspan=2>&nbsp;&nbsp;&nbsp;\n";
	printf "<input type=checkbox name=ssl value=1 %s> %s</td> </tr>\n",
		$typeq eq "hostssl" ? "checked" : "", $text{'host_ssl'};
	}

local $found = !$host->{'db'} || $host->{'db'} eq 'all' ||
	       $host->{'db'} eq 'sameuser';
print "<tr> <td><b>$text{'host_db'}</b></td>\n";
print "<td colspan=2><select name=db>\n";
printf "<option value=all %s>&lt;$text{'host_all'}&gt;\n",
	$host->{'db'} eq 'all' ? 'selected' : '';
printf "<option value=sameuser %s>&lt;$text{'host_same'}&gt;\n",
	$host->{'db'} eq 'sameuser' ? 'selected' : '';
if ($v >= 7.3) {
	printf "<option value=samegroup %s>&lt;$text{'host_gsame'}&gt;\n",
		$host->{'db'} eq 'samegroup' ? 'selected' : '';
	$found++ if ($host->{'db'} eq 'samegroup');
	}
foreach $d (&list_databases()) {
	printf "<option %s>%s\n", $host->{'db'} eq $d ? 'selected' : '', $d;
	$found++ if ($host->{'db'} eq $d);
	}
printf "<option value='' %s>%s\n",
	$found ? "" : "selected", $text{'host_other'};
print "</select>\n";
printf "<input name=dbother size=20 value='%s'></td> </tr>\n",
	$found ? "" : join(" ", split(/,/, $host->{'db'}));

if ($v >= 7.3) {
	print "<tr> <td><b>$text{'host_user'}</b></td> <td colspan=2>\n";
	printf "<input type=radio name=user_def value=1 %s> %s\n",
		$host->{'user'} eq 'all' || !$host->{'user'} ? "checked" : "",
		$text{'host_uall'};
	printf "<input type=radio name=user_def value=0 %s> %s\n",
		$host->{'user'} eq 'all' || !$host->{'user'} ? "" : "checked",
		$text{'host_usel'};
	printf "<input name=user size=25 value='%s'></td> </tr>\n",
		$host->{'user'} eq 'all' ? ""
					 : join(" ", split(/,/, $host->{'user'}));
	}

print "<tr> <td valign=top><b>$text{'host_auth'}</b></td> <td valign=top>\n";
foreach $a ('password', 'crypt', ($v >= 7.2 ? ( 'md5' ) : ( )),
	    'trust', 'reject', 'ident', 'krb4', 'krb5',
	    ($v >= 7.3 ? ( 'pam' ) : ( )) ) {
	printf "<input type=radio name=auth value=%s %s> %s\n",
		$a, $host->{'auth'} eq $a ? 'checked' : '', $text{"host_$a"};
	$arg = $host->{'auth'} eq $a ? $host->{'arg'} : undef;
	if ($a eq 'password') {
		print "<br>&nbsp;&nbsp;&nbsp;\n";
		printf "<input type=checkbox name=passwordarg value=1 %s> %s\n",
			$arg ? 'checked' : '', $text{'host_passwordarg'};
		print "<input name=password size=20 value='$arg'>\n";
		}
	elsif ($a eq 'ident') {
		print "<br>&nbsp;&nbsp;&nbsp;\n";
		printf "<input type=checkbox name=identarg value=1 %s> %s\n",
			$arg ? 'checked' : '', $text{'host_identarg'};
		print "<input name=ident size=10 value='$arg'>\n";
		}
	elsif ($a eq 'pam') {
		print "<br>&nbsp;&nbsp;&nbsp;\n";
		printf "<input type=checkbox name=pamarg value=1 %s> %s\n",
			$arg ? 'checked' : '', $text{'host_pamarg'};
		print "<input name=pam size=10 value='$arg'>\n";
		}
	print "<br>\n";
	if ($a eq 'reject') {
		print "</td><td valign=top>\n";
		}
	}
print "</td></tr>\n";

print "</table></td></tr></table>\n";
print "<table width=100%><tr>\n";
if ($in{'new'}) {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
print "</tr></table>\n";

&ui_print_footer("list_hosts.cgi", $text{'host_return'});

