use strict;
use warnings;

require 'bind8-lib.pl';
# Globals from bind8-lib.pl
our (%config, %text, %in);

# acl_security_form(&options)
# Output HTML for editing security options for the bind8 module
sub acl_security_form
{
my $m = $_[0]->{'zones'} eq '*' ? 1 :
	   $_[0]->{'zones'} =~ /^\!/ ? 2 : 0;
print "<tr> <td valign=top><b>$text{'acl_zones'}</b></td>\n";
print "<td colspan=3><table cellpadding=0 cellspacing=0> <tr><td valign=top>\n";
printf "<input type=radio name=zones_def value=1 %s> %s<br>\n",
	$m == 1 ? 'checked' : '', $text{'acl_zall'};
printf "<input type=radio name=zones_def value=0 %s> %s<br>\n",
	$m == 0 ? 'checked' : '', $text{'acl_zsel'};
printf "<input type=radio name=zones_def value=2 %s> %s</td>\n",
	$m == 2 ? 'checked' : '', $text{'acl_znsel'};

print "<td><select name=zones multiple size=4 width=150>\n";
my $conf = &get_config();
my @zones = grep { $_->{'value'} ne "." }
		    &find("zone", $conf);
my @views = &find("view", $conf);
foreach my $v (@views) {
	push(@zones, grep { $_->{'value'} ne "." }
			  &find("zone", $v->{'members'}));
	}
my %zcan;
map { $zcan{$_}++ } split(/\s+/, $_[0]->{'zones'});
foreach my $z (sort { $a->{'value'} cmp $b->{'value'} } @zones) {
	printf "<option value='%s' %s>%s</option>\n",
		$z->{'value'},
		$zcan{$z->{'value'}} ? "selected" : "",
		&arpa_to_ip($z->{'value'});
	}
foreach my $v (sort { $a->{'value'} cmp $b->{'value'} } @views) {
	printf "<option value='%s' %s>%s</option>\n",
		'view_'.$v->{'value'},
		$zcan{'view_'.$v->{'value'}} ? "selected" : "",
		&text('acl_inview', $v->{'value'});
	}
print "</select></td> </tr></table></td></tr>\n";

if (@views) {
	print "<tr> <td valign=top><b>$text{'acl_inviews'}</b></td>\n";
	print "<td colspan=3>\n";
	print &ui_radio("inviews_def", $_[0]->{'inviews'} eq "*" ? 1 : 0,
			[ [ 1, $text{'acl_vall'} ],
			  [ 0, $text{'acl_vsel'} ] ]),"<br>\n";
	print "<select name=inviews multiple size=4 width=150>\n";
	my %vcan;
	map { $vcan{$_}++ } split(/\s+/, $_[0]->{'inviews'});
	printf "<option value='%s' %s>%s</option>\n",
		"_", $vcan{"_"} ? "selected" : "",
		"&lt;".$text{'acl_toplevel'}."&gt;";
	foreach my $v (sort { $a->{'value'} cmp $b->{'value'} } @views) {
		printf "<option value='%s' %s>%s</option>\n",
			$v->{'value'},
			$vcan{$v->{'value'}} ? "selected" : "", $v->{'value'};
		}
	print "</select></td></tr>\n";
	}

print "<tr> <td><b>$text{'acl_types'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=types_def value=1 %s> %s\n",
	$_[0]->{'types'} ? "" : "checked", $text{'acl_types1'};
printf "<input type=radio name=types_def value=0 %s> %s\n",
	$_[0]->{'types'} ? "checked" : "", $text{'acl_types0'};
printf "<input name=types size=40 value='%s'></td> </tr>\n",
	$_[0]->{'types'};

print "<tr> <td valign=top><b>$text{'acl_dir'}</b></td>\n";
printf "<td colspan=3><input name=dir size=30 value='%s'> %s<br>\n",
	$_[0]->{'dir'}, &file_chooser_button("dir", 1);
printf "<input type=checkbox name=dironly value=1 %s> %s</td> </tr>\n",
	$_[0]->{'dironly'} ? "checked" : "", $text{'acl_dironly'};

print "<tr> <td><b>$text{'acl_defaults'}</b></td> <td nowrap>\n";
printf "<input type=radio name=defaults value=1 %s> $text{'yes'}\n",
	$_[0]->{'defaults'} ? "checked" : "";
printf "<input type=radio name=defaults value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'defaults'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_ztypes'}</b></td> <td colspan=3>\n";
foreach my $t ("master", "slave", "forward", "delegation") {
	printf "<input type=checkbox name=%s %s> %s\n",
		$t, $_[0]->{$t} ? "checked" : "", $text{'acl_ztypes_'.$t};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_reverse'}</b></td> <td nowrap>\n";
printf "<input type=radio name=reverse value=1 %s> $text{'yes'}\n",
	$_[0]->{'reverse'} ? "checked" : "";
printf "<input type=radio name=reverse value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'reverse'} ? "" : "checked";

print "<td><b>$text{'acl_multiple'}</b></td> <td nowrap>\n";
printf "<input type=radio name=multiple value=1 %s> $text{'yes'}\n",
	$_[0]->{'multiple'} ? "checked" : "";
printf "<input type=radio name=multiple value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'multiple'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_ro'}</b></td> <td nowrap>\n";
printf "<input type=radio name=ro value=1 %s> $text{'yes'}\n",
	$_[0]->{'ro'} ? "checked" : "";
printf "<input type=radio name=ro value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'ro'} ? "" : "checked";

print "<td><b>$text{'acl_apply'}</b></td> <td nowrap>\n";
print &ui_select("apply", $_[0]->{'apply'},
		[ [ 1, $text{'yes'} ],
		  [ 2, $text{'acl_applyonly'} ],
		  [ 3, $text{'acl_applygonly'} ],
		  [ 0, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_file'}</b></td> <td nowrap>\n";
printf "<input type=radio name=file value=1 %s> $text{'yes'}\n",
	$_[0]->{'file'} ? "checked" : "";
printf "<input type=radio name=file value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'file'} ? "" : "checked";

print "<td><b>$text{'acl_params'}</b></td> <td nowrap>\n";
printf "<input type=radio name=params value=1 %s> $text{'yes'}\n",
	$_[0]->{'params'} ? "checked" : "";
printf "<input type=radio name=params value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'params'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_opts'}</b></td> <td nowrap>\n";
printf "<input type=radio name=opts value=1 %s> $text{'yes'}\n",
	$_[0]->{'opts'} ? "checked" : "";
printf "<input type=radio name=opts value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'opts'} ? "" : "checked";

print "<td><b>$text{'acl_delete'}</b></td> <td nowrap>\n";
printf "<input type=radio name=delete value=1 %s> $text{'yes'}\n",
	$_[0]->{'delete'} ? "checked" : "";
printf "<input type=radio name=delete value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'delete'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_gen'}</b></td> <td nowrap>\n";
printf "<input type=radio name=gen value=1 %s> $text{'yes'}\n",
	$_[0]->{'gen'} ? "checked" : "";
printf "<input type=radio name=gen value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'gen'} ? "" : "checked";

print "<td><b>$text{'acl_whois'}</b></td> <td nowrap>\n";
printf "<input type=radio name=whois value=1 %s> $text{'yes'}\n",
	$_[0]->{'whois'} ? "checked" : "";
printf "<input type=radio name=whois value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'whois'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_findfree'}</b></td> <td nowrap>\n";
printf "<input type=radio name=findfree value=1 %s> $text{'yes'}\n",
	$_[0]->{'findfree'} ? "checked" : "";
printf "<input type=radio name=findfree value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'findfree'} ? "" : "checked";

print "<td><b>$text{'acl_remote'}</b></td> <td nowrap>\n";
printf "<input type=radio name=remote value=1 %s> $text{'yes'}\n",
	$_[0]->{'remote'} ? "checked" : "";
printf "<input type=radio name=remote value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'remote'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_slaves'}</b></td> <td nowrap>\n";
printf "<input type=radio name=slaves value=1 %s> $text{'yes'}\n",
	$_[0]->{'slaves'} ? "checked" : "";
printf "<input type=radio name=slaves value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'slaves'} ? "" : "checked";

print "<td><b>$text{'acl_dnssec'}</b></td> <td nowrap>\n";
printf "<input type=radio name=dnssec value=1 %s> $text{'yes'}\n",
	$_[0]->{'dnssec'} ? "checked" : "";
printf "<input type=radio name=dnssec value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'dnssec'} ? "" : "checked";

print "</tr>\n";

print "<tr> <td><b>$text{'acl_views'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=views value=1 %s> $text{'yes'}\n",
	$_[0]->{'views'} == 1 ? "checked" : "";
printf "<input type=radio name=views value=2 %s> $text{'acl_edonly'}\n",
	$_[0]->{'views'} == 2 ? "checked" : "";
printf "<input type=radio name=views value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'views'} ? "" : "checked";

if (@views) {
	my $m = $_[0]->{'vlist'} eq '*' ? 1 :
		   $_[0]->{'vlist'} =~ /^\!/ ? 2 :
		   $_[0]->{'vlist'} eq '' ? 3 : 0;
	print "<tr> <td valign=top><b>$text{'acl_vlist'}</b></td>\n";
	print "<td colspan=3><table cellpadding=0 cellspacing=0> <tr><td valign=top>\n";
	printf "<input type=radio name=vlist_def value=1 %s> %s<br>\n",
		$m == 1 ? 'checked' : '', $text{'acl_vall'};
	printf "<input type=radio name=vlist_def value=0 %s> %s<br>\n",
		$m == 0 ? 'checked' : '', $text{'acl_vsel'};
	printf "<input type=radio name=vlist_def value=2 %s> %s<br>\n",
		$m == 2 ? 'checked' : '', $text{'acl_vnsel'};
	printf "<input type=radio name=vlist_def value=3 %s> %s</td>\n",
		$m == 3 ? 'checked' : '', $text{'acl_vnone'};

	print "<td><select name=vlist multiple size=4 width=150>\n";
	my ($v, %vcan);
	map { $vcan{$_}++ } split(/\s+/, $_[0]->{'vlist'});
	foreach my $v (sort { $a->{'value'} cmp $b->{'value'} } @views) {
		printf "<option value='%s' %s>%s</option>\n",
			$v->{'value'},
			$vcan{$v->{'value'}} ? "selected" : "", $v->{'value'};
		}
	print "</select></td> </tr></table></td></tr>\n";
	}
}

# acl_security_save(&options)
# Parse the form for security options for the bind8 module
sub acl_security_save
{
if ($in{'zones_def'} == 1) {
	$_[0]->{'zones'} = "*";
	}
elsif ($in{'zones_def'} == 2) {
	$_[0]->{'zones'} = join(" ", "!", split(/\0/, $in{'zones'}));
	}
else {
	$_[0]->{'zones'} = join(" ", split(/\0/, $in{'zones'}));
	}
$_[0]->{'inviews'} = !defined($in{'inviews'}) || $in{'inviews_def'} ? "*" :
			join(" ", split(/\0/, $in{'inviews'}));
$_[0]->{'types'} = $in{'types_def'} ? undef : $in{'types'};
$_[0]->{'master'} = $in{'master'} || 0;
$_[0]->{'slave'} = $in{'slave'} || 0;
$_[0]->{'forward'} = $in{'forward'} || 0;
$_[0]->{'delegation'} = $in{'delegation'} || 0;
$_[0]->{'defaults'} = $in{'defaults'};
$_[0]->{'reverse'} = $in{'reverse'};
$_[0]->{'multiple'} = $in{'multiple'};
$_[0]->{'ro'} = $in{'ro'};
$_[0]->{'apply'} = $in{'apply'};
$_[0]->{'dir'} = $in{'dir'};
$_[0]->{'dironly'} = $in{'dironly'};
$_[0]->{'file'} = $in{'file'};
$_[0]->{'params'} = $in{'params'};
$_[0]->{'opts'} = $in{'opts'};
$_[0]->{'delete'} = $in{'delete'};
$_[0]->{'findfree'} = $in{'findfree'};
$_[0]->{'slaves'} = $in{'slaves'};
$_[0]->{'views'} = $in{'views'};
$_[0]->{'remote'} = $in{'remote'};
$_[0]->{'dnssec'} = $in{'dnssec'};
$_[0]->{'gen'} = $in{'gen'};
$_[0]->{'whois'} = $in{'whois'};
$_[0]->{'vlist'} = $in{'vlist_def'} == 1 ? "*" :
		   $in{'vlist_def'} == 3 ? "" :
		   $in{'vlist_def'} == 2 ? join(" ", "!",split(/\0/, $in{'vlist'}))
					 : join(" ", split(/\0/, $in{'vlist'}));
}

