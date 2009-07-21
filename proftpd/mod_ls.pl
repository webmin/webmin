# mod_ls.pl

sub mod_ls_directives
{
local $rv = [
	[ 'DirFakeUser', 0, 2, 'virtual anon global', 1.15 ],
	[ 'DirFakeGroup', 0, 2, 'virtual anon global', 1.15 ],
	[ 'DirFakeMode', 0, 2, 'virtual anon global', 1.16 ],
	[ 'LsDefaultOptions', 0, 2, 'virtual anon global', 1.16 ],
	[ 'ListOptions', 0, 2, 'virtual anon global directory ftpaccess', 1.208 ],
	[ 'ShowDotFiles', 0, 2, 'virtual anon global', '0.99-1.206' ],
	];
return &make_directives($rv, $_[0], "mod_ls");
}

sub edit_DirFakeGroup
{
local $rv;
local $w = $_[0]->{'words'}->[0];
$rv .= sprintf "<input type=radio name=DirFakeGroup value=off %s> %s\n",
	lc($w) eq 'off' ? "checked" : "", $text{'no'};
$rv .= sprintf "<input type=radio name=DirFakeGroup value='' %s> %s\n",
	lc($w) ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=DirFakeGroup value=on %s> %s\n",
	lc($w) eq 'on' ? "checked" : "", $text{'mod_ls_fakeasgroup'};

$rv .= "<table border cellpadding=0 cellspacing=0><tr><td>";
local $a = $_[0]->{'words'}->[1];
$rv .= sprintf "<input type=radio name=DirFakeGroup_m value=0 %s> %s\n",
	$a ? "" : "checked", "<tt>ftp</tt>";
$rv .= sprintf "<input type=radio name=DirFakeGroup_m value=1 %s> %s\n",
	$a eq "~" ? "checked" : "", $text{'mod_ls_fakesamegroup'};
$rv .= sprintf "<input type=radio name=DirFakeGroup_m value=2 %s>\n",
	$a eq "~" || !$a ? "" : "checked";
$rv .= sprintf "<input name=DirFakeGroup_a size=12 value='%s'>\n",
	$a eq "~" ? "" : $a;
$rv .= "</td></tr></table>\n";

return (2, $text{'mod_ls_fakegroup'}, $rv);
}
sub save_DirFakeGroup
{
if (!$in{'DirFakeGroup'}) {
	return ( [ ] );
	}
else {
	local $s = $in{'DirFakeGroup'};
	if ($in{'DirFakeGroup_m'} == 1) {
		$s .= " ~";
		}
	elsif ($in{'DirFakeGroup_m'} == 2) {
		$in{'DirFakeGroup_a'} =~ /^\S+$/ ||
			&error($text{'mod_ls_efakegroup'});
		$s .= " ".$in{'DirFakeGroup_a'};
		}
	return ( [ $s ] );
	}
}

sub edit_DirFakeUser
{
local $rv;
local $w = $_[0]->{'words'}->[0];
$rv .= sprintf "<input type=radio name=DirFakeUser value=off %s> %s\n",
	lc($w) eq 'off' ? "checked" : "", $text{'no'};
$rv .= sprintf "<input type=radio name=DirFakeUser value='' %s> %s\n",
	lc($w) ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=DirFakeUser value=on %s> %s\n",
	lc($w) eq 'on' ? "checked" : "", $text{'mod_ls_fakeasuser'};

$rv .= "<table border cellpadding=0 cellspacing=0><tr><td>";
local $a = $_[0]->{'words'}->[1];
$rv .= sprintf "<input type=radio name=DirFakeUser_m value=0 %s> %s\n",
	$a ? "" : "checked", "<tt>ftp</tt>";
$rv .= sprintf "<input type=radio name=DirFakeUser_m value=1 %s> %s\n",
	$a eq "~" ? "checked" : "", $text{'mod_ls_fakesameuser'};
$rv .= sprintf "<input type=radio name=DirFakeUser_m value=2 %s>\n",
	$a eq "~" || !$a ? "" : "checked";
$rv .= sprintf "<input name=DirFakeUser_a size=12 value='%s'>\n",
	$a eq "~" ? "" : $a;
$rv .= "</td></tr></table>\n";

return (2, $text{'mod_ls_fakeuser'}, $rv);
}
sub save_DirFakeUser
{
if (!$in{'DirFakeUser'}) {
	return ( [ ] );
	}
else {
	local $s = $in{'DirFakeUser'};
	if ($in{'DirFakeUser_m'} == 1) {
		$s .= " ~";
		}
	elsif ($in{'DirFakeUser_m'} == 2) {
		$in{'DirFakeUser_a'} =~ /^\S+$/ ||
			&error($text{'mod_ls_efakeuser'});
		$s .= " ".$in{'DirFakeUser_a'};
		}
	return ( [ $s ] );
	}
}

sub edit_DirFakeMode
{
return (1, $text{'mod_ls_fakemode'},
	&opt_input($_[0]->{'value'}, "DirFakeMode", $text{'mod_ls_nofake'}, 5));
}
sub save_DirFakeMode
{
return &parse_opt("DirFakeMode", '0[0-7]{3}', $text{'mod_ls_efakemode'});
}

sub edit_LsDefaultOptions
{
return (1, $text{'mod_ls_ls'},
	&opt_input($_[0]->{'value'}, "LsDefaultOptions", $text{'default'}, 20));
}
sub save_LsDefaultOptions
{
return &parse_opt("LsDefaultOptions", '\S', $text{'mod_ls_els'});
}

sub edit_ShowDotFiles
{
return (1, $text{'mod_ls_dotfiles'},
	&choice_input($_[0]->{'value'}, "ShowDotFiles", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_ShowDotFiles
{
return &parse_choice("ShowDotFiles", "");
}

sub edit_ListOptions
{
local $rv = &opt_input($_[0]->{'words'}->[0], "ListOptions",
		       $text{'default'}, 20);
$rv .= sprintf "<input type=checkbox name=ListOptions_strict value=1 %s> %s\n",
		lc($_[0]->{'words'}->[1]) eq 'strict' ? "checked" : "",
		$text{'mod_ls_strict'};
return (2, $text{'mod_ls_options'}, $rv);
}
sub save_ListOptions
{
if ($in{"ListOptions_def"}) {
	return ( [ ] );
	}
else {
	local $rv = '"'.$in{"ListOptions"}.'"';
	$rv .= " strict" if ($in{'ListOptions_strict'});
	return ( [ $rv ] );
	}
}


