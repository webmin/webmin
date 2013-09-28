#!/usr/local/bin/perl
# edit_user.cgi
# Edit a new or existing webmin user

require './acl-lib.pl';
&foreign_require("webmin", "webmin-lib.pl");

&ReadParse();
if ($in{'user'}) {
	# Editing an existing user
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	&ui_print_header(undef, $text{'edit_title'}, "");
	$u = &get_user($in{'user'});
	$u || &error($text{'edit_egone'});
	%user = %$u;
	}
else {
	# Creating a new user
	$access{'create'} || &error($text{'edit_ecreate'});
	&ui_print_header(undef, $text{'edit_title2'}, "");
	if ($in{'clone'}) {
		# Initial settings come from clone
		$u = &get_user($in{'clone'});
		%user = %$u;
		delete($user{'name'});
		}
	else {
		%user = ( );
		}
	$user{'skill'} = $user{'risk'} = 'high' if ($in{'risk'});
	}
$me = &get_user($base_remote_user);

# Give up if readonly
if ($user{'readonly'} && !$in{'readwrite'}) {
	%minfo = &get_module_info($user{'readonly'});
	print &text('edit_readonly', $minfo{'desc'},
		    "edit_user.cgi?user=$in{'user'}&readwrite=1"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print &ui_form_start("save_user.cgi", "post");
if ($in{'user'}) {
	print &ui_hidden("old", $user{'name'});
	print &ui_hidden("oldpass", $user{'pass'});
	}
if ($in{'clone'}) {
	print &ui_hidden("clone", $in{'clone'});
	}
print &ui_hidden_table_start($text{'edit_rights'}, "width=100%", 2, "rights",
			     1, [ "width=30%" ]);

# Username
print &ui_table_row($text{'edit_user'},
	$access{'rename'} || !$in{'user'} ?
		&ui_textbox("name", $user{'name'}, 30,
			    0, undef, "autocomplete=off") : $user{'name'});

# Source user for clone
if ($in{'clone'}) {
	print &ui_table_row($text{'edit_cloneof'}, "<tt>$in{'clone'}</tt>");
	}

# Find and show parent group
@glist = &list_groups();
@mcan = $access{'gassign'} eq '*' ?
		( ( map { $_->{'name'} } @glist ), '_none' ) :
		split(/\s+/, $access{'gassign'});
map { $gcan{$_}++ } @mcan;
if (@glist && %gcan && !$in{'risk'} && !$user{'risk'}) {
	@opts = ( );
	if ($gcan{'_none'}) {
		push(@opts, [ undef, "&lt;$text{'edit_none'}&gt;" ]);
		}
	$memg = undef;
	foreach $g (@glist) {
		if (&indexof($user{'name'}, @{$g->{'members'}}) >= 0 ||
		    $in{'clone'} &&
		     &indexof($in{'clone'}, @{$g->{'members'}}) >= 0) {
			$memg = $g;
			}
		next if (!$gcan{$g->{'name'}} && $memg ne $g);
		push(@opts, [ $g->{'name'} ]);
		}
	print &ui_table_row($text{'edit_group'},
		&ui_select("group", $memg->{'name'}, \@opts));
	}

# Show password type menu and current password
$passmode = !$in{'user'} ? 0 :
	    $user{'pass'} eq 'x' ? 3 :
	    $user{'sync'} ? 2 :
	    $user{'pass'} eq 'e' ? 5 :
	    $user{'pass'} eq '*LK*' ? 4 : 1;
&get_miniserv_config(\%miniserv);
@opts = ( [ 0, "$text{'edit_set'} .." ] );
if ($in{'user'}) {
	push(@opts, [ 1, $text{'edit_dont'} ]);
	}
push(@opts, [ 3, $text{'edit_unix'} ]);
if ($user{'sync'}) {
	push(@opts, [ 2, $text{'edit_same'} ]);
	}
if ($miniserv{'extauth'}) {
	push(@opts, [ 5, $text{'edit_extauth'} ]);
	}
push(@opts, [ 4, $text{'edit_lock'} ]);
if ($passmode == 1) {
	$lockbox = &ui_checkbox("lock", 1, $text{'edit_templock'},
			               $user{'pass'} =~ /^\!/ ? 1 : 0);
	}
if ($passmode != 3 && $passmode != 4) {
	$tempbox = &ui_checkbox("temp", 1, $text{'edit_temppass'},
				$user{'temppass'});
	}
if ($user{'lastchange'} && $miniserv{'pass_maxdays'}) {
	$daysold = int((time() - $user{'lastchange'})/(24*60*60));
	if ($miniserv{'pass_lockdays'} &&
	    $daysold > $miniserv{'pass_lockdays'}) {
		$expmsg = "<br>"."<font color=#ff0000>".
			  &text('edit_passlocked', $daysold)."</font>";
		}
	elsif ($daysold > $miniserv{'pass_maxdays'}) {
		$expmsg = "<br>"."<font color=#ffaa00>".
			  &text('edit_passmax', $daysold)."</font>";
		}
	elsif ($daysold) {
		$expmsg = "<br>".&text('edit_passold', $daysold);
		}
	else {
		$expmsg = "<br>".$text{'edit_passtoday'};
		}
	}
$js = "onChange='form.pass.disabled = value != 0;'";
print &ui_table_row($text{'edit_pass'},
	&ui_select("pass_def", $passmode, \@opts, 1, 0, 0, 0, $js)." ".
	&ui_password("pass", undef, 25, $passmode != 0, undef,
		     "autocomplete=off").
	($lockbox || $tempbox ? "<br>" : "").$lockbox.$tempbox.$expmsg);

# Real name
print &ui_table_row($text{'edit_real'},
	&ui_textbox("real", $user{'real'}, 60));

# Storage type
if ($in{'user'}) {
	print &ui_table_row($text{'edit_proto'},
		$text{'edit_proto_'.$user{'proto'}});
	}

print &ui_hidden_table_end("rights");

# Start of UI options section
$showui = $access{'chcert'} || $access{'lang'} ||
	  $access{'cats'} || $access{'theme'};
if ($showui) {
	print &ui_hidden_table_start($text{'edit_ui'}, "width=100%", 2, "ui",
				     0, [ "width=30%" ]);
	}

if ($access{'chcert'}) {
	# SSL certificate name
	print &ui_table_row($text{'edit_cert'},
		&ui_opt_textbox("cert", $user{'cert'}, 50, $text{'edit_none'}));
	}

if ($access{'lang'}) {
	# Current language
	print &ui_table_row($text{'edit_lang'},
		&ui_radio("lang_def", $user{'lang'} ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &ui_select("lang", $user{'lang'},
			    [ map { [ $_->{'lang'}, $_->{'desc'}." (".
					uc($_->{'lang'}).")" ] }
				  &list_languages() ]) ]
		  ]));
	}

if ($access{'cats'}) {
	# Show categorized modules?
	print &ui_table_row($text{'edit_notabs'},
		&ui_radio("notabs", int($user{'notabs'}),
			  [ [ 1, $text{'yes'} ],
			    [ 2, $text{'no'} ],
			    [ 0, $text{'default'} ] ]));
	}

if ($access{'theme'}) {
	@all = &webmin::list_themes();
	@themes = grep { !$_->{'overlay'} } @all;
	@overlays = grep { $_->{'overlay'} } @all;

	# Current theme
	@topts = ( );
	push(@topts, [ "", $text{'edit_themedef'} ]);
	foreach $t (@themes) {
		push(@topts, [ $t->{'dir'}, $t->{'desc'} ]);
		}
	print &ui_table_row($text{'edit_theme'},
		&ui_radio("theme_def", defined($user{'theme'}) ? 0 : 1,
		  [ [ 1, $text{'edit_themeglobal'} ],
		    [ 0, &ui_select("theme", $user{'theme'}, \@topts) ] ]));
	}

if ($access{'theme'} && @overlays) {
	# Overlay theme, if any
	print &ui_table_row($text{'edit_overlay'},
		&ui_radio("overlay_def", defined($user{'overlay'}) ? 0 : 1,
		  [ [ 1, $text{'edit_overlayglobal'} ],
		    [ 0, &ui_select("overlay", $user{'overlay'},
			   [ map { [ $_->{'dir'}, $_->{'desc'} ] } @overlays ]
				    ) ] ]));
	}

if ($showui) {
	print &ui_hidden_table_end("ui");
	}

# Start of security options section
$showsecurity = $access{'logouttime'} || $access{'ips'} || $access{'minsize'} ||
		&supports_rbac() && $access{'mode'} == 0 || $access{'times'};
if ($showsecurity) {
	print &ui_hidden_table_start($text{'edit_security'}, "width=100%", 2,
				     "security", 0, [ "width=30%" ]);
	}

if ($access{'logouttime'}) {
	# Show logout time
	print &ui_table_row($text{'edit_logout'},
		&ui_opt_textbox("logouttime", $user{'logouttime'}, 5,
		      		$text{'default'})." ".$text{'edit_mins'});
	}

if ($access{'minsize'}) {
	# Show minimum password length, for just this user
	print &ui_table_row($text{'edit_minsize'},
		&ui_opt_textbox("minsize", $user{'minsize'}, 5,
		      		$text{'default'})." ".$text{'edit_chars'});
	}

if ($access{'nochange'} && $miniserv{'pass_maxdays'}) {
	# Opt out of forced password change, for this user
	print &ui_table_row($text{'edit_nochange'},
		&ui_radio("nochange", $user{'nochange'}, [ [ 0, $text{'yes'} ],
							   [ 1, $text{'no'} ] ]));
	}

if ($access{'ips'}) {
	# Allowed IP addresses
	print &ui_table_row(&hlink("<b>$text{'edit_ips'}</b>", "ips"),
		&ui_radio("ipmode", $user{'allow'} ? 1 :
				    $user{'deny'} ? 2 : 0,
			  [ [ 0, $text{'edit_all'}."<br>" ],
			    [ 1, $text{'edit_allow'}."<br>" ],
			    [ 2, $text{'edit_deny'}."<br>" ] ]).
		&ui_textarea("ips",
		    join("\n", split(/\s+/, $user{'allow'} ? $user{'allow'}
						           : $user{'deny'})),
		    4, 30));
	}

if (&supports_rbac() && $access{'mode'} == 0) {
	# Deny access to modules not managed by RBAC?
	print &ui_table_row($text{'edit_rbacdeny'},
		&ui_radio("rbacdeny", $user{'rbacdeny'} ? 1 : 0,
			  [ [ 0, $text{'edit_rbacdeny0'} ],
			    [ 1, $text{'edit_rbacdeny1'} ] ]));
	}

if ($access{'times'}) {
	# Show allowed days of the week
	%days = map { $_, 1 } split(/,/, $user{'days'});
	$daysels = "";
	for(my $i=0; $i<7; $i++) {
		$daysels .= &ui_checkbox("days", $i, $text{'day_'.$i},
					 $days{$i});
		}
	print &ui_table_row($text{'edit_days'},
		&ui_radio("days_def", $user{'days'} eq '' ? 1 : 0,
			  [ [ 1, $text{'edit_alldays'} ],
			    [ 0, $text{'edit_seldays'} ] ])."<br>".
		$daysels);

	# Show allow hour/minute range
	($hf, $mf) = split(/\./, $user{'hoursfrom'});
	($ht, $mt) = split(/\./, $user{'hoursto'});
	print &ui_table_row($text{'edit_hours'},
		&ui_radio("hours_def", $user{'hoursfrom'} eq '' ? 1 : 0,
			[ [ 1, $text{'edit_allhours'} ],
		  	  [ 0, &text('edit_selhours',
				&ui_textbox("hours_hfrom", $hf, 2),
				&ui_textbox("hours_mfrom", $mf, 2),
				&ui_textbox("hours_hto", $ht, 2),
				&ui_textbox("hours_mto", $mt, 2)) ] ]));
	}

# Two-factor details
if ($user{'twofactor_provider'}) {
	($prov) = grep { $_->[0] eq $user{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &ui_table_row($text{'edit_twofactor'},
		&text('edit_twofactorprov', "<i>$prov->[1]</i>",
		      "<tt>$user{'twofactor_id'}</tt>"));
	}

print &ui_hidden_table_end("security");

# Work out which modules can be selected
@mcan = $access{'mode'} == 1 ? @{$me->{'modules'}} :
	$access{'mode'} == 2 ? split(/\s+/, $access{'mods'}) :
			       &list_modules();
map { $mcan{$_}++ } @mcan;
map { $has{$_}++ } @{$user{'modules'}};
map { $has{$_} = 0 } $group ? @{$group->{'modules'}} : ();

# Start of modules section
print &ui_hidden_table_start(@groups ? $text{'edit_modsg'} : $text{'edit_mods'},
			     "width=100%", 2, "mods");

# Show available modules, under categories
@mlist = grep { $access{'others'} || $has{$_->{'dir'}} || $mcan{$_->{'dir'}} }
	      &list_module_infos();
@links = ( &select_all_link("mod", 0, $text{'edit_selall'}),
	   &select_invert_link("mod", 0, $text{'edit_invert'}) );
@cats = &unique(map { $_->{'category'} } @mlist);
&read_file("$config_directory/webmin.catnames", \%catnames);
$grids = "";
foreach $c (sort { $b cmp $a } @cats) {
	@cmlist = grep { $_->{'category'} eq $c } @mlist;
	$grids .= "<b>".($catnames{$c} || $text{'category_'.$c})."</b><br>\n";
	@grid = ( );
	$sw = 0;
	foreach $m (@cmlist) {
		local $md = $m->{'dir'};
		$fromgroup = $memg && &indexof($md, @{$memg->{'modules'}}) >= 0;
		if ($mcan{$md} && $fromgroup) {
			# Module comes from group
			push(@grid, (sprintf "<img src=images/%s.gif> %s\n",
                                $has{$md} ? 'tick' : 'empty', $m->{'desc'}).
				($has{$md} ? &ui_hidden("mod", $md) : ""));
			}
		elsif ($mcan{$md}) {
			$label = "";
			if ($access{'acl'} && $in{'user'}) {
				# Show link for editing ACL
				$label = sprintf "<a href='edit_acl.cgi?".
						 "mod=%s&%s=%s'>%s</a>\n",
					&urlize($m->{'dir'}),
					"user", &urlize($in{'user'}),
					$m->{'desc'};
				}
			else {
				# No privileges to edit ACL
				$label = $m->{'desc'};
				}
			push(@grid, &ui_checkbox("mod", $md, $label,$has{$md}));
			}
		else {
			push(@grid, (sprintf "<img src=images/%s.gif> %s\n",
				$has{$md} ? 'tick' : 'empty', $m->{'desc'}));
			}
		}
	$grids .= &ui_grid_table(\@grid, 2, 100, [ "width=50%", "width=50%" ]);
	}

print &ui_table_row(undef, &ui_links_row(\@links).
                           $grids.
                           &ui_links_row(\@links), 2);
print &ui_hidden_table_end("mods");

# Add global ACL section, but only if not set from the group
$groupglobal = $memg && -r "$config_directory/$memg->{'name'}.acl";
if ($access{'acl'} && !$groupglobal && $in{'user'}) {
	print &ui_hidden_table_start($text{'edit_global'}, "width=100%", 2,
				     "global", 0, [ "width=30%" ]);
	%uaccess = &get_module_acl($in{'user'}, "", 1);
	print &ui_hidden("acl_security_form", 1);
	&foreign_require("", "acl_security.pl");
	&foreign_call("", "acl_security_form", \%uaccess);
	print &ui_hidden_table_end("global");
	}

# Generate form end buttons
@buts = ( );
push(@buts, [ undef, $in{'user'} ? $text{'save'} : $text{'create'} ]);
if ($in{'user'}) {
	if ($access{'create'} && !$group) {
		push(@buts, [ "but_clone", $text{'edit_clone'} ]);
		}
	if (&foreign_available("webminlog")) {
		push(@buts, [ "but_log", $text{'edit_log'} ]);
		}
	if ($access{'switch'} && $main::session_id) {
		push(@buts, [ "but_switch", $text{'edit_switch'} ]);
		}
	if ($access{'delete'}) {
		push(@buts, [ "but_delete", $text{'delete'} ]);
		}
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

