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
my $rv = &ui_columns_start([ $text{'mod_auth_dir'},
			     $text{'mod_auth_groups'} ]);
my $i = 0;
foreach my $r (@{$_[0]}, { }) {
	my @w = @{$r->{'words'}};

	my $dd = $w[0] eq "~" ? 2 : $w[0] ? 0 : 1;
	$rv .= &ui_columns_row([
		&ui_radio("DefaultRoot_dd_$i", $dd,
			  [ [ 1, $text{'mod_auth_none'} ],
			    [ 2, $text{'mod_auth_home'} ],
			    [ 0, &ui_textbox("DefaultRoot_d_$i", $dd ? "" : $w[0], 20) ] ]),
		&ui_radio("DefaultRoot_gd_$i", $w[1] ? 0 : 1,
			  [ [ 1, $text{'mod_auth_all'} ],
			    [ 0, &ui_textbox("DefaultRoot_g_$i",
					     join(" ", split(/,/, $w[1])), 12) ] ]),
		]);
	$i++;
	}
$rv .= &ui_columns_end();
return (2, $text{'mod_auth_chroot'}, $rv);
}
sub save_DefaultRoot
{
my @rv;
for(my $i=0; defined($in{"DefaultRoot_d_$i"}); $i++) {
	next if ($in{"DefaultRoot_dd_$i"} == 1);
	my $v = $in{"DefaultRoot_dd_$i"} == 2 ? "~" :$in{"DefaultRoot_d_$i"};
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


