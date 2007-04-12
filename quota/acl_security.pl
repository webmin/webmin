
require 'quota-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the quota module
sub acl_security_form
{
local $groups = &quotas_supported() >= 2;

print "<tr> <td valign=top><b>$text{'acl_fss'}</b></td>\n";
print "<td colspan=3>\n";
printf "<input type=radio name=filesys_def value=1 %s> %s\n",
	$_[0]->{'filesys'} eq '*' ? 'checked' : '', $text{'acl_fall'};
printf "<input type=radio name=filesys_def value=0 %s> %s<br>\n",
	$_[0]->{'filesys'} eq '*' ? '' : 'checked', $text{'acl_fsel'};
print "<select width=150 name=filesys multiple size=3>\n";
local ($f, %qcan);
map { $qcan{$_}++ } split(/\s+/, $_[0]->{'filesys'});
foreach $f (&list_filesystems()) {
	if ($f->[4]) {
		printf "<option %s>%s\n",
			$qcan{$f->[0]} ? "selected" : "", $f->[0];
		}
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'acl_ro'}</b></td> <td>\n";
printf "<input type=radio name=ro value=1 %s> $text{'yes'}\n",
	$_[0]->{'ro'} ? "checked" : "";
printf "<input type=radio name=ro value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'ro'} ? "" : "checked";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td><b>$text{'acl_quotaon'}</b></td> <td>\n";
printf "<input type=radio name=enable value=1 %s> $text{'yes'}\n",
	$_[0]->{'enable'} ? "checked" : "";
printf "<input type=radio name=enable value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'enable'} ? "" : "checked";

print "<td><b>$text{'acl_quotanew'}</b></td> <td>\n";
printf "<input type=radio name=default value=1 %s> $text{'yes'}\n",
	$_[0]->{'default'} ? "checked" : "";
printf "<input type=radio name=default value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'default'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_ugrace'}</b></td> <td>\n";
printf "<input type=radio name=ugrace value=1 %s> $text{'yes'}\n",
	$_[0]->{'ugrace'} ? "checked" : "";
printf "<input type=radio name=ugrace value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'ugrace'} ? "" : "checked";

print "<td><b>$text{'acl_vtotal'}</b></td> <td>\n";
printf "<input type=radio name=diskspace value=1 %s> $text{'yes'}\n",
	$_[0]->{'diskspace'} ? "checked" : "";
printf "<input type=radio name=diskspace value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'diskspace'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_maxblocks'}</b></td> <td>\n";
printf "<input type=radio name=maxblocks_def value=1 %s> %s\n",
	$_[0]->{'maxblocks'} ? '' : 'checked', $text{'acl_unlimited'};
printf "<input type=radio name=maxblocks_def value=0 %s>\n",
	$_[0]->{'maxblocks'} ? 'checked' : '';
print "<input name=maxblocks size=8 value='$_[0]->{'maxblocks'}'></td>\n";

print "<td><b>$text{'acl_maxfiles'}</b></td> <td>\n";
printf "<input type=radio name=maxfiles_def value=1 %s> %s\n",
	$_[0]->{'maxfiles'} ? '' : 'checked', $text{'acl_unlimited'};
printf "<input type=radio name=maxfiles_def value=0 %s>\n",
	$_[0]->{'maxfiles'} ? 'checked' : '';
print "<input name=maxfiles size=8 value='$_[0]->{'maxfiles'}'></td> </tr>\n";

print "<tr> <td><b>$text{'acl_email'}</b></td> <td>\n";
printf "<input type=radio name=email value=1 %s> $text{'yes'}\n",
	$_[0]->{'email'} ? "checked" : "";
printf "<input type=radio name=email value=0 %s> $text{'no'}</td>\n",
	$_[0]->{'email'} ? "" : "checked";

if ($groups) {
	print "<td><b>$text{'acl_ggrace'}</b></td> <td>\n";
	printf "<input type=radio name=ggrace value=1 %s> $text{'yes'}\n",
		$_[0]->{'ggrace'} ? "checked" : "";
	printf "<input type=radio name=ggrace value=0 %s> $text{'no'}</td>\n",
		$_[0]->{'ggrace'} ? "" : "checked";
	}
print "</tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'acl_uquota'}",
      "</b></td> <td colspan=3>\n";
printf "<input type=radio name=umode value=0 %s> $text{'acl_uall'}<br>\n",
	$_[0]->{'umode'} == 0 ? "checked" : "";
printf "<input type=radio name=umode value=1 %s> $text{'acl_uonly'}\n",
	$_[0]->{'umode'} == 1 ? "checked" : "";
printf "<input name=ucan size=40 value='%s'> %s<br>\n",
	$_[0]->{'umode'} == 1 ? $_[0]->{'users'} : "",
	&user_chooser_button("ucan", 1);
printf "<input type=radio name=umode value=2 %s> $text{'acl_uexcept'}\n",
	$_[0]->{'umode'} == 2 ? "checked" : "";
printf "<input name=ucannot size=40 value='%s'> %s<br>\n",
	$_[0]->{'umode'} == 2 ? $_[0]->{'users'} : "",
	&user_chooser_button("ucannot", 1);
printf "<input type=radio name=umode value=3 %s> $text{'acl_ugroup'}\n",
	$_[0]->{'umode'} == 3 ? "checked" : "";
printf "<input name=upri size=8 value='%s'> %s<br>\n",
	$_[0]->{'umode'} == 3 ? scalar(getgrgid($_[0]->{'users'})) : "",
	&group_chooser_button("upri", 0);
printf "<input type=radio name=umode value=4 %s> $text{'acl_uuid'}\n",
	$_[0]->{'umode'} == 4 ? "checked" : "";
printf "<input name=umin size=6 value='%s'> -\n",
	$_[0]->{'umode'} == 4 ? $_[0]->{'umin'} : "";
printf "<input name=umax size=6 value='%s'></td> </tr>\n",
	$_[0]->{'umode'} == 4 ? $_[0]->{'umax'} : "";

if ($groups) {
	print "<tr> <td colspan=4><hr></td> </tr>\n";

	print "<tr> <td valign=top><b>$text{'acl_gquota'}",
	      "</b></td> <td colspan=3>\n";
	printf "<input type=radio name=gmode value=0 %s>$text{'acl_gall'}<br>\n",
		$_[0]->{'gmode'} == 0 ? "checked" : "";
	printf "<input type=radio name=gmode value=3 %s>$text{'acl_gnone'}<br>\n",
		$_[0]->{'gmode'} == 3 ? "checked" : "";
	printf "<input type=radio name=gmode value=1 %s>$text{'acl_gonly'}\n",
		$_[0]->{'gmode'} == 1 ? "checked" : "";
	printf "<input name=gcan size=40 value='%s'> %s<br>\n",
		$_[0]->{'gmode'} == 1 ? $_[0]->{'groups'} : "",
		&group_chooser_button("gcan", 1);
	printf "<input type=radio name=gmode value=2 %s>$text{'acl_gexcept'}\n",
		$_[0]->{'gmode'} == 2 ? "checked" : "";
	printf "<input name=gcannot size=40 value='%s'> %s</td> </tr>\n",
		$_[0]->{'gmode'} == 2 ? $_[0]->{'groups'} : "",
		&group_chooser_button("gcannot", 1);
	}
}

# acl_security_save(&options)
# Parse the form for security options for the quota module
sub acl_security_save
{
if ($in{'filesys_def'}) {
	$_[0]->{'filesys'} = "*";
	}
else {
	$_[0]->{'filesys'} = join(" ", split(/\0/, $in{'filesys'}));
	}
$_[0]->{'ro'} = $in{'ro'};
$_[0]->{'umode'} = $in{'umode'};
$_[0]->{'users'} = $in{'umode'} == 0 ? "" :
		   $in{'umode'} == 1 ? $in{'ucan'} :
		   $in{'umode'} == 2 ? $in{'ucannot'} :
		   $in{'umode'} == 3 ? scalar(getgrnam($in{'upri'})) : "";
$_[0]->{'umin'} = $in{'umin'};
$_[0]->{'umax'} = $in{'umax'};
$_[0]->{'gmode'} = $in{'gmode'};
$_[0]->{'groups'} = $in{'gmode'} == 0 ? "" :
		    $in{'gmode'} == 1 ? $in{'gcan'} : $in{'gcannot'};
$_[0]->{'enable'} = $in{'enable'};
$_[0]->{'default'} = $in{'default'};
$_[0]->{'email'} = $in{'email'};
$_[0]->{'ugrace'} = $in{'ugrace'};
$_[0]->{'ggrace'} = $in{'ggrace'};
$_[0]->{'diskspace'} = $in{'diskspace'};
$_[0]->{'maxblocks'} = $in{'maxblocks_def'} ? undef : $in{'maxblocks'};
$_[0]->{'maxfiles'} = $in{'maxfiles'};
}

