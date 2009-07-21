# mod_auth.pl

sub mod_auth_directives
{
local $rv = [
	[ 'DefaultChdir', 0, 2, 'virtual anon global', 1.20 ],
	[ 'DefaultRoot', 1, 2, 'virtual global', 0.99 ],
	[ 'LoginPasswordPrompt', 0, 3, 'virtual anon global', 1.20 ],
	[ 'RootLogin', 0, 6, 'virtual anon global', 1.15 ]
	];
return &make_directives($rv, $_[0], "mod_auth");
}

sub edit_DefaultChdir
{
return (1, $text{'mod_auth_chdir'},
	&opt_input($_[0]->{'value'}, "DefaultChdir", $text{'default'}, 20));
}
sub save_DefaultChdir
{
return &parse_opt("DefaultChdir", '^\S+$', $text{'mod_auth_echdir'});
}

sub edit_DefaultRoot
{
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'mod_auth_dir'}</b></td> ".
	    "<td><b>$text{'mod_auth_groups'}</b></td> </tr>\n";
local $i = 0;
foreach $r (@{$_[0]}, { }) {
	local @w = @{$r->{'words'}};
	$rv .= "<tr $cb>\n";

	local $dd = $w[0] eq "~" ? 2 : $w[0] ? 0 : 1;
	$rv .= sprintf "<td nowrap><input name=DefaultRoot_dd_$i type=radio value=1 %s> %s\n", $dd == 1 ? "checked" : "", $text{'mod_auth_none'};
	$rv .= sprintf "<input name=DefaultRoot_dd_$i type=radio value=2 %s> %s\n", $dd == 2 ? "checked" : "", $text{'mod_auth_home'};
	$rv .= sprintf "<input name=DefaultRoot_dd_$i type=radio value=0 %s>\n", $dd == 0 ? "checked" : "";
	$rv .= sprintf "<input name=DefaultRoot_d_$i size=20 value='%s'></td>\n", $dd ? "" : $w[0];

	$rv .= sprintf "<td nowrap><input name=DefaultRoot_gd_$i type=radio value=1 %s> %s\n", $w[1] ? "" : "checked", $text{'mod_auth_all'};
	$rv .= sprintf "<input name=DefaultRoot_gd_$i type=radio value=0 %s>\n", $w[1] ? "checked" : "";
	$rv .= sprintf "<input name=DefaultRoot_g_$i size=12 value='%s'></td>\n", join(" ", split(/,/, $w[1]));
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
return (2, $text{'mod_auth_chroot'}, $rv);
}
sub save_DefaultRoot
{
for($i=0; defined($in{"DefaultRoot_d_$i"}); $i++) {
	next if ($in{"DefaultRoot_dd_$i"} == 1);
	local $v = $in{"DefaultRoot_dd_$i"} == 2 ? "~" :$in{"DefaultRoot_d_$i"};
	$v =~ /^\S+$/ || &error($text{'mod_auth_edir'});
	if (!$in{"DefaultRoot_gd_$i"}) {
		local @g = split(/\s+/, $in{"DefaultRoot_g_$i"});
		@g || &error($text{'mod_auth_egroups'});
		$v .= " ".join(",", @g);
		}
	push(@rv, $v);
	}
return ( \@rv );
}

sub edit_LoginPasswordPrompt
{
return (1, $text{'mod_auth_login'},
	&choice_input($_[0]->{'value'}, "LoginPasswordPrompt", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_LoginPasswordPrompt
{
return &parse_choice("LoginPasswordPrompt", "");
}

sub edit_RootLogin
{
return (1, $text{'mod_auth_root'},
	&choice_input($_[0]->{'value'}, "RootLogin", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_RootLogin
{
return &parse_choice("RootLogin", "");
}


