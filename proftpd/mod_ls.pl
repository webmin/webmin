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
$rv .= &ui_radio("DirFakeGroup", lc($w),
		 [ [ 'off', $text{'no'} ],
		   [ '', $text{'default'} ],
		   [ 'on', $text{'mod_ls_fakeasgroup'} ] ]);
my $a = $_[0]->{'words'}->[1];
$rv .= &ui_radio("DirFakeGroup_m",
		 $a eq "~" ? 1 : $a eq "" ? 0 : 2,
		 [ [ 0, "<tt>ftp</tt>" ],
		   [ 1, $text{'mod_ls_fakesamegroup'} ],
		   [ 2, &ui_textbox("DirFakeGroup_a", $a eq "~" ? "" : $a, 12) ] ]);
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
my $rv;
my $w = $_[0]->{'words'}->[0];
$rv .= &ui_radio("DirFakeUser", lc($w),
		 [ [ 'off', $text{'no'} ],
		   [ '', $text{'default'} ],
		   [ 'on', $text{'mod_ls_fakeasuser'} ] ]);
my $a = $_[0]->{'words'}->[1];
$rv .= &ui_radio("DirFakeUser_m",
		 $a eq "~" ? 1 : $a eq "" ? 0 : 2,
		 [ [ 0, "<tt>ftp</tt>" ],
		   [ 1, $text{'mod_ls_fakesameuser'} ],
		   [ 2, &ui_textbox("DirFakeUser_a", $a eq "~" ? "" : $a, 12) ] ]);
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
my $rv = &opt_input($_[0]->{'words'}->[0], "ListOptions",
		       $text{'default'}, 20);
$rv .= &ui_checkbox("ListOptions_strict", 1, $text{'mod_ls_strict'},
		    lc($_[0]->{'words'}->[1]) eq 'strict');
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


