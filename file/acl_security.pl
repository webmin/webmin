
require 'file-lib.pl';
do '../ui-lib.pl';

# acl_security_form(&options)
# Output HTML for editing security options for the file module
sub acl_security_form
{
print "<tr> <td><b>$text{'acl_user'}</b></td>\n";
local $u = $_[0]->{'uid'} < 0 ? '' : getpwuid($_[0]->{'uid'});
printf "<td colspan=3><input type=radio name=uid_def value=1 %s> %s\n",
	$_[0]->{'uid'} < 0 ? 'checked' : '', $text{'acl_user_def'};
printf "<input type=radio name=uid_def value=0 %s>\n",
	$_[0]->{'uid'} < 0 ? '' : 'checked';
print "<input name=uid size=8 value='$u'> ",
	&user_chooser_button("uid", 0),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_umask'}</b></td>\n";
print "<td colspan=3><input name=umask size=3 value='$_[0]->{'umask'}'></td> </tr>\n";

print "<tr> <td><b>$text{'acl_follow'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=follow value=1 %s> $text{'yes'}\n",
	$_[0]->{'follow'} == 1 ? "checked" : "";
printf "<input type=radio name=follow value=2 %s> $text{'acl_fyes'}\n",
	$_[0]->{'follow'} == 2 ? "checked" : "";
printf "<input type=radio name=follow value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'follow'} == 0 ? "checked" : "";

print "<tr> <td><b>$text{'acl_ro'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=ro value=1 %s> $text{'yes'}\n",
	$_[0]->{'ro'} ? "checked" : "";
printf "<input type=radio name=ro value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'ro'} ? "" : "checked";

print "<tr> <td><b>$text{'acl_max'}</b></td>\n";
printf "<td colspan=3><input type=radio name=max_def value=1 %s> %s\n",
	$_[0]->{'max'} ? "" : "checked", $text{'acl_unlim'};
printf "<input type=radio name=max_def value=0 %s>\n",
	$_[0]->{'max'} ? "checked" : "";
printf "<input name=max size=8 value='%s'> %s</td> </tr>\n",
	$_[0]->{'max'}, $text{'acl_b'};

print "<tr> <td><b>$text{'acl_archive'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=archive value=1 %s> $text{'yes'}\n",
	$_[0]->{'archive'} == 1 ? "checked" : "";
printf "<input type=radio name=archive value=2 %s> $text{'acl_archmax'}\n",
	$_[0]->{'archive'} == 2 ? "checked" : "";
printf "<input name=archmax size=10 value='%s'> %s\n",
	$_[0]->{'archmax'}, $text{'acl_b'};
printf "<input type=radio name=archive value=0 %s> $text{'no'}</td> </tr>\n",
	$_[0]->{'archive'} == 0 ? "checked" : "";

print "<tr> <td><b>$text{'acl_unarchive'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=unarchive value=2 %s> %s\n",
	$_[0]->{'unarchive'} == 2 ? "checked" : "", $text{'acl_unarchive2'};
printf "<input type=radio name=unarchive value=1 %s> %s\n",
	$_[0]->{'unarchive'} == 1 ? "checked" : "", $text{'acl_unarchive1'};
printf "<input type=radio name=unarchive value=0 %s> %s</td> </tr>\n",
	$_[0]->{'unarchive'} == 0 ? "checked" : "", $text{'acl_unarchive0'};

print "<tr> <td><b>$text{'acl_dostounix'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=dostounix value=1 %s> %s\n",
	$_[0]->{'dostounix'} == 1 ? "checked" : "", $text{'yes'};
printf "<input type=radio name=dostounix value=0 %s> %s</td> </tr>\n",
	$_[0]->{'dostounix'} == 0 ? "checked" : "", $text{'no'};

print "<tr> <td valign=top><b>$text{'acl_buttons'}</b></td> <td colspan=3>\n";
foreach $b (@file_buttons) {
	printf "<input type=checkbox name=button_%s %s> %s<br>\n",
		$b, $_[0]->{'button_'.$b} ? "checked" : "",
		$text{'acl_button_'.$b};
	}
print "</td> </tr>\n";

print "<tr> <td><b>$text{'acl_noperms'}</b></td>\n";
print "<td>",&ui_radio("noperms", int($_[0]->{'noperms'}),
	       [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),"</td>\n";

print "<td><b>$text{'acl_nousers'}</b></td>\n";
print "<td>",&ui_radio("nousers", int($_[0]->{'nousers'}),
	       [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_filesystems'}</b></td>\n";
print "<td>",&ui_yesno_radio("filesystems",
			     int($_[0]->{'filesystems'})),"</td>\n";

print "<td><b>$text{'acl_contents'}</b></td>\n";
print "<td>",&ui_yesno_radio("contents",
			     int($_[0]->{'contents'})),"</td> </tr>\n";

print "<tr> <td><b>$text{'acl_chroot'}</b></td>\n";
printf "<td colspan=3><input name=chroot size=40 value='%s'></td>\n",
	$_[0]->{'chroot'};

print "<tr> <td valign=top><b>$text{'acl_dirs'}</b><br>$text{'acl_relto'}</td>\n";
print "<td colspan=3><textarea name=root rows=3 cols=40>",
	join("\n", split(/\s+/, $_[0]->{'root'})),"</textarea><br>\n";
printf "<input type=checkbox name=home value=1 %s> %s<br>\n",
	$_[0]->{'home'} ? 'checked' : '', $text{'acl_home'};
printf "<input type=checkbox name=goto value=1 %s> %s</td>\n",
	$_[0]->{'goto'} ? 'checked' : '', $text{'acl_goto'};

print "<tr> <td valign=top><b>$text{'acl_nodirs'}</b><br>$text{'acl_relto'}</td>\n";
print "<td colspan=3><textarea name=noroot rows=3 cols=40>",
	join("\n", split(/\s+/, $_[0]->{'noroot'})),"</textarea><br>\n";
}

# acl_security_save(&options)
# Parse the form for security options for the file module
sub acl_security_save
{
$_[0]->{'uid'} = $in{'uid_def'} ? -1 : getpwnam($in{'uid'});
$in{'root'} =~ s/\r//g;
local @root = split(/\s+/, $in{'root'});
map { s/\/+/\//g } @root;
map { s/([^\/])\/+$/$1/ } @root;
$_[0]->{'root'} = join(" ", @root);
$in{'noroot'} =~ s/\r//g;
local @noroot = split(/\s+/, $in{'noroot'});
map { s/\/+/\//g } @noroot;
map { s/([^\/])\/+$/$1/ } @noroot;
$_[0]->{'noroot'} = join(" ", @noroot);
$_[0]->{'follow'} = $in{'follow'};
$_[0]->{'ro'} = $in{'ro'};
$in{'umask'} =~ /^[0-7]{3}$/ || &error("Invalid umask");
$_[0]->{'umask'} = $in{'umask'};
$_[0]->{'home'} = $in{'home'};
$_[0]->{'goto'} = $in{'goto'};
$_[0]->{'max'} = $in{'max_def'} ? undef : $in{'max'};
$_[0]->{'archive'} = $in{'archive'};
$_[0]->{'archmax'} = $in{'archmax'};
foreach $b (@file_buttons) {
	$_[0]->{"button_$b"} = $in{"button_$b"};
	}
$_[0]->{'unarchive'} = $in{'unarchive'};
$_[0]->{'dostounix'} = $in{'dostounix'};
$_[0]->{'chroot'} = $in{'chroot'};
$_[0]->{'noperms'} = $in{'noperms'};
$_[0]->{'nousers'} = $in{'nousers'};
$_[0]->{'filesystems'} = $in{'filesystems'};
$_[0]->{'contents'} = $in{'contents'};
}

