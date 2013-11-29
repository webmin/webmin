# mod_core.pl
# Core proftpd directives

# mod_core_directives(version)
# Returns a directive structure, like the one user by Apache. Types are :
#	0 - Networking
#	1 - Logging
#	2 - Files
#	3 - Access control
#	4 - Misc
#	5 - User and Group
#	6 - Authentication
sub mod_core_directives
{
local $rv = [
	[ 'AccessDenyMsg', 0, 3, 'virtual anon global', 1.202 ],
	[ 'AccessGrantMsg', 0, 3, 'virtual anon global', 0.99 ],
	[ 'Allow Deny Order', 1, 3, 'limit', 0.99 ],
	[ 'AllowAll DenyAll', 0, 3, 'directory anon limit ftpaccess', 0.99 ],
	[ 'AllowFilter', 0, 3, 'virtual anon global', 1.20 ],
	[ 'AllowForeignAddress', 0, 0, 'virtual anon global', 1.17 ],
	[ 'AllowGroup', 1, 3, 'limit', 1.11 ],
	[ 'AllowOverwrite', 0, 3, 'virtual anon directory ftpaccess global', 0.99 ],
	[ 'AllowUser', 1, 3, 'limit', 1.17 ],
	[ 'AllowRetrieveRestart', 0, 0, 'virtual anon directory global ftpaccess', 0.99 ],
	[ 'AllowStoreRestart', 0, 0, 'virtual anon directory global ftpaccess', 0.99 ],
	[ 'AnonRequirePassword', 0, 6, 'anon', 0.99 ],
	[ 'AnonymousGroup', 0, 6, 'virtual global', 1.13 ],
	[ 'AuthAliasOnly', 0, 6, 'virtual anon global', 1.13 ],
	[ 'AuthUsingAlias', 0, 6, 'anon', 1.20 ],
	[ 'Bind', 0, 0, 'virtual', '1.16-1.27' ],
	[ 'DefaultAddress', 0, 0, 'virtual', '1.27' ],
	[ 'CDPath', 1, 2, 'virtual anon global', 1.20 ],
	[ 'Class Classes', 1, 3, 'virtual', 1.20 ],
	[ 'CommandBufferSize', 0, 0, 'virtual global', 1.20 ],
	[ 'DefaultServer', 0, 0, 'virtual', undef, 0.99, 8 ],
	[ 'DefaultTransferMode', 0, 0, 'virtual global', 1.20 ],
	[ 'DeferWelcome', 0, 0, 'virtual global', 0.99 ],
	[ 'DeleteAbortedStores', 0, 2, 'virtual directory anon global ftpaccess', 1.20 ],
	[ 'DenyFilter', 0, 3, 'virtual anon global', 1.20 ],
	[ 'DenyGroup', 1, 3, 'limit', 1.11 ],
	[ 'DenyUser', 1, 3, 'limit', 1.17 ],
	[ 'DisplayConnect', 0, 6, 'virtual global', 1.20 ],
	[ 'DisplayFirstChdir', 0, 2, 'virtual anon directory global', '0.99-1.31' ],
	[ 'DisplayChdir', 0, 2, 'virtual anon directory global', 1.31 ],
	[ 'DisplayGoAway', 0, 6, 'virtual anon global', 1.20 ],
	[ 'DisplayLogin', 0, 6, 'virtual anon global', 0.99 ],
	[ 'DisplayQuit', 0, 6, 'virtual anon global', 1.20 ],
	[ 'Group', 0, 5, 'virtual anon', undef, 0.99, 9 ],
	[ 'GroupOwner', 0, 5, 'anon directory ftpaccess', 0.99 ],
	[ 'GroupPassword', 1, 6, 'virtual anon global', 0.99 ],
	[ 'HiddenStor', 0, 2, 'virtual anon directory global', '1.20-1.31' ],
	[ 'HiddenStores', 0, 2, 'virtual anon directory global', 1.31 ],
	[ 'HideGroup', 1, 2, 'directory anon', 0.99 ],
	[ 'HideNoAccess', 0, 2, 'directory anon', 0.99 ],
	[ 'HideUser', 1, 2, 'directory anon', 0.99 ],
	[ 'IdentLookups', 0, 0, 'virtual global', 1.15 ],
	[ 'IgnoreHidden', 0, 2, 'limit', 0.99 ],
	[ 'MasqueradeAddress', 0, 0, 'virtual', 1.202 ],
	[ 'MaxClients', 0, 0, 'virtual anon global', 0.99 ],
	[ 'MaxClientsPerHost', 0, 0, 'virtual anon global', 1.17 ],
#	[ 'MaxClientsPerUser', 0, 0, 'virtual anon global', 1.20 ],
	[ 'MaxInstances', 0, 0, 'root', undef, 1.16, 8 ],
	[ 'MaxLoginAttempts', 0, 6, 'virtual global', 0.99 ],
	[ 'MultilineRFC2228', 0, 0, 'root', 1.20 ],
	[ 'PassivePorts', 0, 0, 'virtual global', 1.20 ],
	[ 'PathAllowFilter', 0, 2, 'virtual anon global', 1.17 ],
	[ 'PathDenyFilter', 0, 2, 'virtual anon global', 1.17 ],
	[ 'PidFile', 0, 4, 'root', 1.20 ],
	[ 'Port', 0, 0, 'virtual', 0.99 ],
	[ 'RequireValidShell', 0, 6, 'virtual anon global', 0.99 ],
	[ 'RLimitCPU', 0, 4, 'root', 1.202 ],
	[ 'RLimitMemory', 0, 4, 'root', 1.202 ],
	[ 'RLimitOpenFiles', 0, 4, 'root', 1.202 ],
	[ 'ScoreboardPath', 0, 4, 'root', 1.16 ],
	[ 'ServerAdmin', 0, 4, 'virtual', 0.99 ],
	[ 'ServerIdent', 0, 0, 'virtual global', 1.20 ],
	[ 'ServerName', 0, 4, 'virtual', undef, 0.99, 11 ],
	[ 'ServerType', 0, 0, 'root', undef, 0.99, 10 ],
	[ 'ShowSymlinks', 0, 2, 'virtual anon global', 0.99 ],
	[ 'SocketBindTight', 0, 0, 'root', 0.99 ],
	[ 'SyslogFacility', 0, 1, 'root', 1.16 ],
	[ 'SyslogLevel', 0, 1, 'virtual anon global', 1.20 ],
	[ 'tcpBackLog', 0, 0, 'root', 0.99 ],
	[ 'tcpNoDelay', 0, 0, 'virtual global', 1.20 ],
	[ 'tcpReceiveWindow', 0, 0, 'virtual', 0.99 ],
	[ 'tcpSendWindow', 0, 0, 'virtual', 0.99 ],
	[ 'TimesGMT', 0, 4, 'root', 1.20 ],
	[ 'TimeoutIdle', 0, 0, 'root', 0.99 ],
	[ 'TimeoutLogin', 0, 0, 'root', 0.99 ],
	[ 'TimeoutNoTransfer', 0, 0, 'root', 0.99 ],
	[ 'TimeoutStalled', 0, 0, 'root', 1.16 ],
	[ 'TransferLog', 0, 1, 'virtual anon global', undef, 1.14, 10 ],
	[ 'Umask', 0, 2, 'virtual directory ftpaccess', undef, 0.99, 3 ],
	[ 'UseFtpUsers', 0, 6, 'virtual anon global', 0.99 ],
	[ 'UseHostsAllowFile', 0, 3, 'virtual anon', 1.20 ],
	[ 'UseHostsDenyFile', 0, 3, 'virtual anon', 1.20 ],
	[ 'UseReverseDNS', 0, 0, 'root', 1.17 ],
	[ 'User', 0, 5, 'virtual anon', undef, 0.99, 10 ],
	[ 'UserDirRoot', 0, 2, 'anon', 1.20 ],
	[ 'UserAlias', 1, 6, 'virtual anon global', 0.99 ],
	[ 'UserOwner', 0, 5, 'anon directory', 1.20 ],
	[ 'UserPassword', 1, 6, 'virtual anon global', 0.99 ],
	[ 'WtmpLog', 0, 4, 'virtual anon global', 1.17 ],
	];
return &make_directives($rv, $_[0], "mod_core");
}

sub edit_AccessDenyMsg
{
return (1, $text{'mod_core_accessdeny'},
	&opt_input($_[0]->{'words'}->[0], "AccessDenyMsg", $text{'default'}, 20));
}
sub save_AccessDenyMsg
{
return &parse_opt("AccessDenyMsg");
}

sub edit_AccessGrantMsg
{
return (1, $text{'mod_core_accessgrant'},
	&opt_input($_[0]->{'words'}->[0], "AccessGrantMsg", $text{'default'}, 20));
}
sub save_AccessGrantMsg
{
return &parse_opt("AccessGrantMsg");
}

sub edit_Allow_Deny_Order
{
local (@type, @what, @mode, $i);
foreach $d (@{$_[0]}, @{$_[1]}) {
	local @w = @{$d->{'words'}};
	shift(@w) if (lc($w[0]) eq 'from');
	for($i=0; $i<@w; $i++) {
		push(@type, lc($d->{'name'}) eq "allow" ? 1 : 2);
		push(@what, $w[$i] eq 'all' || $w[$i] eq 'none' ? undef
								: $w[$i]);
		if ($w[$i] eq 'all') { push(@mode, 0); }
		elsif ($w[$i] eq 'none') { push(@mode, 1); }
		elsif ($w[$i] =~ /^\d+\.\d+\.\d+\.\d+$/) { push(@mode, 2); }
		elsif ($w[$i] =~ /^[0-9\.\/]+$/) { push(@mode, 3); }
		else { push(@mode, 4); }
		}
	}
push(@type, ""); push(@what, ""); push(@mode, 0);
$rv = "<i>$text{'mod_core_order'}</i>\n".
      &choice_input($_[2]->[0]->{'value'}, "order", "",
      		    "$text{'mod_core_denyallow'},deny,allow", 
      		    "$text{'mod_core_allowdeny'},allow,deny", 
      		    "$text{'default'},")."<br>\n";
$rv .= "<table border>\n".
       "<tr $tb> <td><b>$text{'mod_core_action'}</b></td> ".
       "<td><b>$text{'mod_core_cond'}</b></td> </tr>\n";
@sels = map { $text{"mod_core_mode_$_"}.','.$_ } (0 .. 4);
for($i=0; $i<@type; $i++) {
	$rv .= "<tr $cb> <td>".&select_input($type[$i], "allow_type_$i", "0",
		"&nbsp;,0", "$text{'mod_core_allow'},1",
		"$text{'mod_core_deny'},2")."</td>\n";
	$rv .= "<td>".&select_input($mode[$i], "allow_mode_$i", "0", @sels);
	$rv .= sprintf "<input name=allow_what_$i size=20 value=\"%s\"></td>\n",
		 $mode[$i] ? $what[$i] : "";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, $text{'mod_core_allow_deny'}, $rv);
}
sub save_Allow_Deny_Order
{
local ($i, $type, $mode, $what, @allow, @deny);
for($i=0; defined($type = $in{"allow_type_$i"}); $i++) {
	$mode = $in{"allow_mode_$i"}; $what = $in{"allow_what_$i"};
	next if (!$type);
	if ($mode == 0) { $what = "all"; }
	elsif ($mode == 1) { $what = "none"; }
	elsif ($mode == 2) {
		&check_ipaddress($what) || &check_ip6address($what) ||
			&error(&text('mod_core_eip', $what));
		}
	elsif ($mode == 3) {
		$what =~ /^[0-9\.]+\.$/ ||
		    $what =~ /^([0-9\.]+)\/\d+$/ && &check_ipaddress("$1") ||
		    $what =~ /^([a-f0-9:]+)\/\d+$/ && &check_ip6address("$1") ||
			&error(&text('mod_core_enet', $what));
		}
	elsif ($mode == 4) {
		$what =~ /^[A-Za-z0-9\.\-]+$/ ||
			&error(&text('mod_core_ehost', $what));
		}
	if ($type == 1) { push(@allow, $what); }
	else { push(@deny, $what); }
	}
return ( \@allow, \@deny, &parse_choice("order", ""));
}

sub edit_AllowAll_DenyAll
{
#local $a = @{$_[0]}, $d = @{$_[1]};
local $a = $_[0], $d = $_[1];
local $rv = sprintf "<input type=radio name=AllowAll value=0 %s> %s\n",
	$a || $d ? "" : "checked", $text{'mod_core_addefault'};
$rv .= sprintf "<input type=radio name=AllowAll value=1 %s> %s\n",
	$a ? "checked" : "", $text{'mod_core_allowall'};
$rv .= sprintf "<input type=radio name=AllowAll value=2 %s> %s\n",
	$d ? "checked" : "", $text{'mod_core_denyall'};
return (1, $text{'mod_core_adall'}, $rv);
}
sub save_AllowAll_DenyAll
{
return $in{'AllowAll'} == 0 ? ( [ ], [ ] ) :
       $in{'AllowAll'} == 1 ? ( [ "" ], [ ] ) : ( [ ], [ "" ] );
}

sub edit_AllowFilter
{
return (1, $text{'mod_core_filter'},
	&opt_input($_[0]->{'value'}, "AllowFilter", $text{'default'}, 15));
}
sub save_AllowFilter
{
return &parse_opt("AllowFilter");
}

sub edit_AllowForeignAddress
{
return (1, $text{'mod_core_foreign'},
	&choice_input($_[0]->{'value'}, "AllowForeignAddress", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AllowForeignAddress
{
return &parse_choice("AllowForeignAddress", "");
}

sub edit_AllowGroup
{
local $v = @{$_[0]} ? join(" ", (map { $_->{'value'} } @{$_[0]})) : undef;
return (2, $text{'mod_core_agroup'},
	&opt_input($v, "AllowGroup", $text{'mod_core_all'}, 50));
}
sub save_AllowGroup
{
return ( $in{'AllowGroup_def'} ? [ ] : [ split(/\s+/, $in{'AllowGroup'}) ] );
}

sub edit_AllowOverwrite
{
return (1, $text{'mod_core_overwrite'},
	&choice_input($_[0]->{'value'}, "AllowOverwrite", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AllowOverwrite
{
return &parse_choice("AllowOverwrite", "");
}

sub edit_AllowRetrieveRestart
{
return (1, $text{'mod_core_restart'},
	&choice_input($_[0]->{'value'}, "AllowRetrieveRestart", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AllowRetrieveRestart
{
return &parse_choice("AllowRetrieveRestart", "");
}

sub edit_AllowStoreRestart
{
return (1, $text{'mod_core_restart2'},
	&choice_input($_[0]->{'value'}, "AllowStoreRestart", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AllowStoreRestart
{
return &parse_choice("AllowStoreRestart", "");
}

sub edit_AllowUser
{
local $v = @{$_[0]} ? join(" ", (map { $_->{'value'} } @{$_[0]})) : undef;
return (2, $text{'mod_core_auser'},
	&opt_input($v, "AllowUser", $text{'mod_core_all'}, 50));
}
sub save_AllowUser
{
return ( $in{'AllowUser_def'} ? [ ] : [ split(/\s+/, $in{'AllowUser'}) ] );
}

sub edit_AnonRequirePassword
{
return (1, $text{'mod_core_require'},
	&choice_input($_[0]->{'value'}, "AnonRequirePassword", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AnonRequirePassword
{
return &parse_choice("AnonRequirePassword", "");
}

sub edit_AnonymousGroup
{
return (2, $text{'mod_core_anongroup'},
	&opt_input($_[0]->{'value'}, "AnonymousGroup", $text{'default'}, 50));
	
}
sub save_AnonymousGroup
{
return &parse_opt("AnonymousGroup", '\S', $text{'mod_core_eanongroup'});
}

sub edit_AuthAliasOnly
{
return (1, $text{'mod_core_authalias'},
	&choice_input($_[0]->{'value'}, "AuthAliasOnly", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AuthAliasOnly
{
return &parse_choice("AuthAliasOnly", "");
}

sub edit_AuthUsingAlias
{
return (1, $text{'mod_core_authusingalias'},
	&choice_input($_[0]->{'value'}, "AuthUsingAlias", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_AuthUsingAlias
{
return &parse_choice("AuthUsingAlias", "");
}

sub edit_Bind
{
return (1, $text{'mod_core_bind'},
	&opt_input($_[0]->{'value'}, "Bind", $text{'mod_core_bind_all'}, 15));
}
sub save_Bind
{
return &parse_opt("Bind", '^(\d+)\.(\d+)\.(\d+)\.(\d+)|([0-9:]+)$',
		  $text{'mod_core_ebind'});
}

sub edit_DefaultAddress
{
return (1, $text{'mod_core_bind'},
	&opt_input($_[0]->{'value'}, "DefaultAddress", $text{'mod_core_bind_all'}, 15));
}
sub save_DefaultAddress
{
$in{'DefaultAddress_def'} || &to_ipaddress($in{'DefaultAddress'}) ||
	&to_ip6address($in{'DefaultAddress'}) ||
	&error(text{'mod_core_ebind'});
return &parse_opt("DefaultAddress", '^\S+$',
		  $text{'mod_core_ebind'});
}

sub edit_CDPath
{
local $rv = "<textarea rows=3 cols=50 name=CDPath>";
foreach $p (@{$_[0]}) {
	$rv .= "$p->{'value'}\n";
	}
$rv .= "</textarea>\n";
return (2, $text{'mod_core_cdpath'}, $rv);
}
sub save_CDPath
{
$in{'CDPath'} =~ s/\r//g;
return ( [ split(/\s+/, $in{'CDPath'}) ] );
}

sub edit_Class_Classes
{
local $rv = $text{'mod_core_classes'}.
	    &choice_input($_[1]->[0]->{'value'}, "Classes", "",
		          "$text{'yes'},on", "$text{'no'},off",
		      	  "$text{'default'},")."<br>\n";
$rv .= "<table border>\n".
       "<tr $tb> <td><b>$text{'mod_core_cname'}</b></td> ".
       "<td><b>$text{'mod_core_ctype'}</b></td> </tr>\n";
local $i = 0;
foreach $c (@{$_[0]}, { }) {
	local @w = @{$c->{'words'}};
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=Class_n_$i size=10 value='$w[0]'></td>\n";
	$rv .= "<td><select name=Class_t_$i>\n";
	$rv .= sprintf "<option value=limit %s>%s</option>\n",
		$w[1] eq 'limit' ? 'selected' : '', $text{'mod_core_climit'};
	$rv .= sprintf "<option value=regex %s>%s</option>\n",
		$w[1] eq 'regex' ? 'selected' : '', $text{'mod_core_cregex'};
	$rv .= sprintf "<option value=ip %s>%s</option>\n",
		$w[1] eq 'ip' ? 'selected' : '', $text{'mod_core_cip'};
	$rv .= "</select>\n";
	$rv .= "<input name=Class_v_$i size=20 value='$w[2]'></td>\n";
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
return (2, $text{'mod_core_cls'}, $rv);
}
sub save_Class_Classes
{
local ($i, @rv);
for($i=0; defined($in{"Class_n_$i"}); $i++) {
	next if (!$in{"Class_n_$i"});
	$in{"Class_t_$i"} ne 'limit' ||
		$in{"Class_v_$i"} =~ /^\d+$/ ||
			&error($text{'mod_core_eclimit'});
	$in{"Class_t_$i"} ne 'regex' ||
		$in{"Class_v_$i"} =~ /\S/ ||
			&error($text{'mod_core_ecregex'});
	$in{"Class_t_$i"} ne 'ip' ||
		$in{"Class_v_$i"} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/ ||
			&error($text{'mod_core_ecip'});
	push(@rv, join(" ", $in{"Class_n_$i"}, $in{"Class_t_$i"},
			    $in{"Class_v_$i"}));
	}
return ( \@rv, $in{'Classes'} eq 'on' ? [ 'on' ] :
	       $in{'Classes'} eq 'off' ? [ 'off' ] : [ ] );
}

sub edit_CommandBufferSize
{
return (1, $text{'mod_core_buffer'},
	&opt_input($_[0]->{'value'}, "CommandBufferSize", $text{'default'}, 5));
}
sub save_CommandBufferSize
{
return &parse_opt("CommandBufferSize", '^\d+$', $text{'mod_core_ebuffer'});
}

sub edit_DefaultServer
{
return (1, $text{'mod_core_defaultserver'},
	&choice_input($_[0]->{'value'}, "DefaultServer", "off",
		      "$text{'yes'},on",
		      "$text{'no'},off"));
}
sub save_DefaultServer
{
return &parse_choice("DefaultServer", "off");
}

sub edit_DefaultTransferMode
{
return (1, $text{'mod_core_transfer'},
	&select_input($_[0]->{'value'}, "DefaultTransferMode", "",
		      "$text{'mod_core_ascii'},ascii",
		      "$text{'mod_core_binary'},binary",
		      "$text{'default'},"));
}
sub save_DefaultTransferMode
{
return &parse_choice("DefaultTransferMode", "");
}

sub edit_DeferWelcome
{
return (1, $text{'mod_core_defer'},
	&choice_input($_[0]->{'value'}, "DeferWelcome", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_DeferWelcome
{
return &parse_choice("DeferWelcome", "");
}

sub edit_DeleteAbortedStores
{
return (1, $text{'mod_core_aborted'},
	&choice_input($_[0]->{'value'}, "DeleteAbortedStores", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_DeleteAbortedStores
{
return &parse_choice("DeleteAbortedStores", "");
}

sub edit_DenyFilter
{
return (1, $text{'mod_core_dfilter'},
	&opt_input($_[0]->{'value'}, "DenyFilter", $text{'default'}, 15));
}
sub save_DenyFilter
{
return &parse_opt("DenyFilter");
}

sub edit_DenyGroup
{
local $v = @{$_[0]} ? join(" ", (map { $_->{'value'} } @{$_[0]})) : undef;
return (2, $text{'mod_core_dgroup'},
	&opt_input($v, "DenyGroup", $text{'mod_core_none'}, 50));
}
sub save_DenyGroup
{
return ( $in{'DenyGroup_def'} ? [ ] : [ split(/\s+/, $in{'DenyGroup'}) ] );
}

sub edit_DenyUser
{
local $v = @{$_[0]} ? join(" ", (map { $_->{'value'} } @{$_[0]})) : undef;
return (2, $text{'mod_core_duser'},
	&opt_input($v, "DenyUser", $text{'mod_core_none'}, 50));
}
sub save_DenyUser
{
return ( $in{'DenyUser_def'} ? [ ] : [ split(/\s+/, $in{'DenyUser'}) ] );
}

sub edit_DisplayConnect
{
return (2, $text{'mod_core_display'},
	&opt_input($_[0]->{'value'}, "DisplayConnect",
		   $text{'mod_core_none'}, 50));
}
sub save_DisplayConnect
{
return &parse_opt("DisplayConnect", '\S', $text{'mod_core_edisplay'});
}

sub edit_DisplayFirstChdir
{
return (1, $text{'mod_core_firstcd'},
	&opt_input($_[0]->{'value'}, "DisplayFirstChdir",
		   $text{'mod_core_none'}, 15));
}
sub save_DisplayFirstChdir
{
return &parse_opt("DisplayFirstChdir", '^\S+$', $text{'mod_core_efirstcd'});
}

sub edit_DisplayChdir
{
return (1, $text{'mod_core_firstcd'},
	&opt_input($_[0]->{'words'}->[0], "DisplayChdir",
		   $text{'mod_core_none'}, 15).
	&ui_checkbox("DisplayChdir_always", 'true', $text{'mod_core_firstcdt'},
		     $_[0]->{'words'}->[1] eq 'true'));
}
sub save_DisplayChdir
{
local @rv = &parse_opt("DisplayChdir", '^\S+$', $text{'mod_core_efirstcd'});
if ($in{'DisplayChdir_always'}) {
	$rv[0]->[0] .= ' true';
	}
return @rv;
}

sub edit_DisplayGoAway
{
return (2, $text{'mod_core_goaway'},
	&opt_input($_[0]->{'value'}, "DisplayGoAway",
		   $text{'mod_core_none'}, 50));
}
sub save_DisplayGoAway
{
return &parse_opt("DisplayGoAway", '\S', $text{'mod_core_egoaway'});
}

sub edit_DisplayLogin
{
return (2, $text{'mod_core_login'},
	&opt_input($_[0]->{'value'}, "DisplayLogin",
		   $text{'mod_core_none'}, 50));
}
sub save_DisplayLogin
{
return &parse_opt("DisplayLogin", '\S', $text{'mod_core_elogin'});
}

sub edit_DisplayQuit
{
return (2, $text{'mod_core_quit'},
	&opt_input($_[0]->{'value'}, "DisplayQuit",
		   $text{'mod_core_none'}, 50));
}
sub save_DisplayQuit
{
return &parse_opt("DisplayQuit", '\S', $text{'mod_core_equit'});
}

sub edit_Group
{
local($rv, @ginfo);
$rv = sprintf "<input type=radio name=Group value=0 %s> $text{'default'}\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=Group value=1 %s> %s\n",
        $_[0] && $_[0]->{'value'} !~ /^#/ ? "checked" : "",
	$text{'mod_core_gname'};
$rv .= sprintf "<input name=Group_name size=8 value=\"%s\"> %s\n",
	$_[0]->{'value'} !~ /^#/ ? $_[0]->{'value'} : "",
	&group_chooser_button("Group_name", 0);
$rv .= sprintf "<input type=radio name=Group value=2 %s> %s\n",
        $_[0]->{'value'} =~ /^#/ ? "checked" : "",
	$text{'mod_core_gid'};
$rv .= sprintf "<input name=Group_id size=6 value=\"%s\">\n",
	 $_[0]->{'value'} =~ /^#(.*)$/ ? $1 : "";
return (2, $text{'mod_core_group'}, $rv);
}
sub save_Group
{
if ($in{'Group'} == 0) { return ( [ ] ); }
elsif ($in{'Group'} == 1) { return ( [ $in{'Group_name'} ] ); }
elsif ($in{'Group_id'} !~ /^\-?\d+$/) {
	&error(&text('core_euid', $in{'Group_id'}));
	}
else { return ( [ "#$in{'Group_id'}" ] ); }
}

sub edit_GroupOwner
{
return (1, $text{'mod_core_gowner'},
	&opt_input($_[0]->{'value'}, "GroupOwner", $text{'default'}, 13,
		   &group_chooser_button("GroupOwner")));
}
sub save_GroupOwner
{
if ($in{'GroupOwner_def'}) { return ( [ ] ); }
else {
	defined(getgrnam($in{'GroupOwner'})) || &error($text{'mod_core_egowner'});
	return ( [ $in{'GroupOwner'} ] );
	}
}

sub edit_GroupPassword
{
local $rv = "<table border>\n";
$rv .= "<tr $tb> <td><b>$text{'mod_core_gpname'}</b></td> ".
       "<td><b>$text{'mod_core_gppass'}</b></td> </tr>\n";
local $i = 0;
foreach $g (@{$_[0]}) {
	local @v = @{$g->{'words'}};
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=GroupPassword_n_$i size=13 value='$v[0]'></td>\n";
	$rv .= "<td><input type=radio name=GroupPassword_d_$i value='$v[1]' checked> $text{'mod_core_gpdef'}\n";
	$rv .= "<input type=radio name=GroupPassword_d_$i value=0>\n";
	$rv .= "<input name=GroupPassword_p_$i size=25></td> </tr>\n";
	$i++;
	}
$rv .= "<tr $cb>\n".
       "<td><input name=GroupPassword_n_$i size=13></td>\n".
       "<td><input name=GroupPassword_p_$i size=35></td>\n".
       "</tr> </table>\n";
return (2, $text{'mod_core_grouppassword'}, $rv);
}
sub save_GroupPassword
{
local @rv;
for($i=0; defined($in{"GroupPassword_n_$i"}); $i++) {
	next if (!$in{"GroupPassword_n_$i"});
	scalar(getgrnam($in{"GroupPassword_n_$i"})) ||
		&error($text{'mod_core_egpname'});
	if ($in{"GroupPassword_d_$i"}) {
		push(@rv, $in{"GroupPassword_n_$i"}.' '.
			  $in{"GroupPassword_d_$i"});
		}
	else {
		$salt = substr(time(), 0, 2);
		push(@rv, $in{"GroupPassword_n_$i"}.' '.
			  &unix_crypt($in{"GroupPassword_p_$i"}, $salt));
		}
	}
return ( \@rv );
}

sub edit_HiddenStor
{
return (1, $text{'mod_core_hstor'},
	&choice_input($_[0]->{'value'}, "HiddenStor", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_HiddenStor
{
return &parse_choice("HiddenStor", "");
}

sub edit_HiddenStores
{
return (1, $text{'mod_core_hstor'},
	&choice_input($_[0]->{'value'}, "HiddenStores", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_HiddenStores
{
return &parse_choice("HiddenStores", "");
}

sub edit_HideGroup
{
return (2, $text{'mod_core_hgroup'},
	sprintf "<input name=HideGroup size=50 value='%s'>",
	 join(" ", map { $_->{'value'} } @{$_[0]}));
}
sub save_HideGroup
{
local @hg = split(/\s+/, $in{'HideGroup'});
foreach $g (@hg) {
	scalar(getgrnam($g)) || &error($text{'mod_core_ehgroup'});
	}
return ( \@hg );
}

sub edit_HideNoAccess
{
return (1, $text{'mod_core_hnoaccess'},
	&choice_input($_[0]->{'value'}, "HideNoAccess", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_HideNoAccess
{
return &parse_choice("HideNoAccess", "");
}

sub edit_HideUser
{
return (2, $text{'mod_core_huser'},
	sprintf "<input name=HideUser size=50 value='%s'>",
	 join(" ", map { $_->{'value'} } @{$_[0]}));
}
sub save_HideUser
{
local @hu = split(/\s+/, $in{'HideUser'});
foreach $u (@hu) {
	defined(getpwnam($u)) || &error($text{'mod_core_ehuser'});
	}
return ( \@hu );
}

sub edit_IdentLookups
{
return (1, $text{'mod_core_ident'},
	&choice_input($_[0]->{'value'}, "IdentLookups", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_IdentLookups
{
return &parse_choice("IdentLookups", "");
}

sub edit_IgnoreHidden
{
return (1, $text{'mod_core_ihidden'},
	&choice_input($_[0]->{'value'}, "IgnoreHidden", "off",
		      "$text{'yes'},on", "$text{'no'},off"));
}
sub save_IgnoreHidden
{
return &parse_choice("IgnoreHidden", "off");
}

sub edit_MasqueradeAddress
{
return (2, $text{'mod_core_masq'},
	&opt_input($_[0]->{'value'}, "MasqueradeAddress",
		   $text{'mod_core_masq_def'}, 30));
}
sub save_MasqueradeAddress
{
$in{'MasqueradeAddress_def'} || &to_ipaddress($in{'MasqueradeAddress'}) ||
	&error($text{'mod_core_emasq'});
return &parse_opt("MasqueradeAddress");
}

sub edit_MaxClients
{
return (2, $text{'mod_core_maxc'}, &edit_max($_[0], "MaxClients"));
}
sub save_MaxClients
{
return &save_max("MaxClients");
}

sub edit_MaxClientsPerHost
{
return (2, $text{'mod_core_maxch'}, &edit_max($_[0], "MaxClientsPerHost"));
}
sub save_MaxClientsPerHost
{
return &save_max("MaxClientsPerHost");
}

sub edit_MaxClientsPerUser
{
return (2, $text{'mod_core_maxcu'}, &edit_max($_[0], "MaxClientsPerUser"));
}
sub save_MaxClientsPerUser
{
return &save_max("MaxClientsPerUser");
}

sub edit_max
{
local $m = !$_[0] ? 0 :
	   $_[0]->{'words'}->[0] eq 'none' ? 1 : 2;
local $rv = sprintf "<input type=radio name=$_[1]_m value=0 %s> %s\n",
		$m == 0 ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=$_[1]_m value=1 %s> %s\n",
		$m == 1 ? "checked" : "", $text{'mod_core_maxc1'};
$rv .= sprintf "<input type=radio name=$_[1]_m value=2 %s>\n",
		$m == 2 ? "checked" : "";
$rv .= sprintf "<input name=$_[1] size=6 value='%s'><br>\n",
		$m == 2 ? $_[0]->{'words'}->[0] : "";
$rv .= sprintf "%s <input name=$_[1]_t size=40 value='%s'>\n",
	$text{'mod_core_maxcmsg'}, $_[0]->{'words'}->[1];
return $rv;
}
sub save_max
{
if ($in{"$_[0]_m"} == 0) {
	return ( [ ] );
	}
else {
	local $n;
	if ($in{"$_[0]_m"} == 1) {
		$n = "none";
		}
	else {
		$in{$_[0]} =~ /^\d+$/ || &error($text{'mod_core_emaxc'});
		$n = $in{$_[0]};
		}
	if ($in{"$_[0]_t"}) {
		return ( [ "$n \"".$in{"$_[0]_t"}."\"" ] );
		}
	else {
		return ( [ $n ] );
		}
	}
}

sub edit_MaxInstances
{
return (1, $text{'mod_core_instances'},
	&opt_input($_[0]->{'value'}, "MaxInstances", $text{'default'}, 4));
}
sub save_MaxInstances
{
return &parse_opt("MaxInstances", '^\d+$', $text{'mod_core_einstances'});
}

sub edit_MaxLoginAttempts
{
return (1, $text{'mod_core_logins'},
	&opt_input($_[0]->{'value'}, "MaxLoginAttempts", $text{'default'}, 4));
}
sub save_MaxLoginAttempts
{
return &parse_opt("MaxLoginAttempts", '^\d+$', $text{'mod_core_elogins'});
}

sub edit_MultilineRFC2228
{
return (1, $text{'mod_core_rfc2228'},
	&choice_input($_[0]->{'value'}, "MultilineRFC2228", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_MultilineRFC2228
{
return &parse_choice("MultilineRFC2228", "");
}

sub edit_PassivePorts
{
local $rv = sprintf "<input type=radio name=PassivePorts_def value=1 %s> %s\n",
		$_[0] ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=PassivePorts_def value=0 %s> %s\n",
		$_[0] ? "checked" : "", $text{'mod_core_pasvr'};
$rv .= sprintf "<input name=PassivePorts_f size=5 value='%s'> -\n",
		$_[0]->{'words'}->[0];
$rv .= sprintf "<input name=PassivePorts_t size=5 value='%s'>\n",
		$_[0]->{'words'}->[1];
return (1, $text{'mod_core_pasv'}, $rv);
}
sub save_PassivePorts
{
if ($in{'PassivePorts_def'}) {
	return ( [ ] );
	}
else {
	$in{'PassivePorts_f'} =~ /^\d+$/ || &error($text{'mod_core_epasv'});
	$in{'PassivePorts_t'} =~ /^\d+$/ || &error($text{'mod_core_epasv'});
	return ( [ "$in{'PassivePorts_f'} $in{'PassivePorts_t'}" ] );
	}
}

sub edit_PathAllowFilter
{
return (1, $text{'mod_core_pathallow'},
	&opt_input($_[0]->{'words'}->[0], "PathAllowFilter",
		   $text{'mod_core_any'}, 20));
}
sub save_PathAllowFilter
{
return &parse_opt("PathAllowFilter");
}

sub edit_PathDenyFilter
{
return (1, $text{'mod_core_pathdeny'},
	&opt_input($_[0]->{'words'}->[0], "PathDenyFilter",
		   $text{'mod_core_none'}, 20));
}
sub save_PathDenyFilter
{
return &parse_opt("PathDenyFilter");
}

sub edit_PidFile
{
return (2, $text{'mod_core_pidfile'},
	&opt_input($_[0]->{'words'}->[0], "PidFile", $text{'default'}, 50,
		   &file_chooser_button("PidFile")));
}
sub save_PidFile
{
return &parse_opt("PidFile", '^\/\S+$', $text{'mod_core_epidfile'});
}

sub edit_Port
{
return (1, $text{'mod_core_port'},
	&opt_input($_[0]->{'value'}, "Port", $text{'default'}, 6));
}
sub save_Port
{
return &parse_opt("Port", '^\d+$', $text{'mod_core_eport'});
}

sub edit_RequireValidShell
{
return (1, $text{'mod_core_shell'},
	&choice_input($_[0]->{'value'}, "RequireValidShell", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_RequireValidShell
{
return &parse_choice("RequireValidShell", "");
}

sub edit_RLimitCPU
{
return &rlimit_input("RLimitCPU", $text{'mod_core_cpulimit'}, $_[0]);
}
sub save_RLimitCPU
{
return &parse_rlimit("RLimitCPU", $text{'mod_core_ecpulimit'});
}

sub edit_RLimitMemory
{
return &rlimit_input("RLimitMemory", $text{'mod_core_memlimit'}, $_[0]);
}
sub save_RLimitMemory
{
return &parse_rlimit("RLimitMemory", $text{'mod_core_ememlimit'});
}

sub edit_RLimitOpenFiles
{
return &rlimit_input("RLimitOpenFiles", $text{'mod_core_filelimit'}, $_[0]);
}
sub save_RLimitOpenFiles
{
return &parse_rlimit("RLimitOpenFiles", $text{'mod_core_efilelimit'});
}

# rlimit_input(name, desc, value)
sub rlimit_input
{
local @w = @{$_[2]->{'words'}};
local $rv;
$rv .= sprintf "<b>%s</b> <input type=radio name=%s_smax value=2 %s> %s\n",
		$text{'mod_core_soft'}, $_[0], $w[0] ? "" : "checked",
		$text{'default'};
$rv .= sprintf "<input type=radio name=%s_smax value=1 %s> %s\n",
		$_[0], $w[0] eq 'max' ? "checked" : "", $text{'mod_core_max'};
$rv .= sprintf "<input type=radio name=%s_smax value=0 %s>\n",
		$_[0], !$w[0] || $w[0] eq 'max' ? "" : "checked";
$rv .= sprintf "<input name=%s_soft size=6 value='%s'>\n",
		$_[0], $w[0] eq 'max' ? '' : $w[0];
$rv .= "&nbsp;&nbsp;&nbsp;";

$rv .= sprintf "<b>%s</b> <input type=radio name=%s_hmax value=2 %s> %s\n",
		$text{'mod_core_hard'}, $_[0], $w[1] ? "" : "checked",
		$text{'default'};
$rv .= sprintf "<input type=radio name=%s_hmax value=1 %s> %s\n",
		$_[0], $w[1] eq 'max' ? "checked" : "", $text{'mod_core_max'};
$rv .= sprintf "<input type=radio name=%s_hmax value=0 %s>\n",
		$_[0], !$w[1] || $w[1] eq 'max' ? "" : "checked";
$rv .= sprintf "<input name=%s_hard size=6 value='%s'>\n",
		$_[0], $w[1] eq 'max' ? '' : $w[1];
return (2, $_[1], $rv);
}

# parse_rlimit(name, desc)
sub parse_rlimit
{
if ($in{"$_[0]_smax"} == 2) {
	return ( [ ] );
	}
local @v;
if ($in{"$_[0]_smax"} == 1) {
	push(@v, "max");
	}
else {
	$in{"$_[0]_soft"} =~ /^(\d+)(G|M|K|B)?$/i ||
		&error(&text('mod_core_esoft', $_[1]));
	push(@v, $in{"$_[0]_soft"});
	}
if ($in{"$_[0]_hmax"} == 1) {
	push(@v, "max");
	}
elsif ($in{"$_[0]_hmax"} == 0) {
	$in{"$_[0]_hard"} =~ /^(\d+)(G|M|K|B)?$/i ||
		&error(&text('mod_core_ehard', $_[1]));
	push(@v, $in{"$_[0]_hard"});
	}
return ( [ join(" ", @v) ] );
}

sub edit_ScoreboardPath
{
return (2, $text{'mod_core_score'},
	&opt_input($_[0]->{'words'}->[0], "ScoreboardPath", $text{'default'},
		   50, &file_chooser_button("ScoreboardPath")));
}
sub save_ScoreboardPath
{
return &parse_opt("ScoreboardPath", '^\/\S+$', $text{'mod_core_escore'});
}

sub edit_ServerAdmin
{
return (2, $text{'mod_core_admin'},
	&opt_input($_[0]->{'words'}->[0], "ServerAdmin", $text{'default'}, 40));
}
sub save_ServerAdmin
{
return &parse_opt("ServerAdmin", '^\S+\@\S+$', $text{'mod_core_eadmin'});
}

sub edit_ServerIdent
{
local @w = @{$_[0]->{'words'}};
local $rv = sprintf "<input type=radio name=ServerIdent_m value=0 %s> %s\n",
	$_[0] ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=ServerIdent_m value=1 %s> %s\n",
	lc($w[0]) eq 'off' ? "checked" : "", $text{'mod_core_none'};
$rv .= sprintf "<input type=radio name=ServerIdent_m value=2 %s> %s\n",
	lc($w[0]) eq 'on' && !$w[1] ? "checked" : "",
	$text{'mod_core_identmsg_def'};
$rv .= sprintf "<input type=radio name=ServerIdent_m value=3 %s>\n",
	lc($w[0]) eq 'on' && $w[1] ? "checked" : "";
$rv .= sprintf "<input name=ServerIdent size=30 value='%s'>\n",
	lc($w[0]) eq 'on' ? $w[1] : "";
return (2, $text{'mod_core_identmsg'}, $rv);
}
sub save_ServerIdent
{
if ($in{'ServerIdent_m'} == 0) {
	return ( [ ] );
	}
elsif ($in{'ServerIdent_m'} == 1) {
	return ( [ "off" ] );
	}
elsif ($in{'ServerIdent_m'} == 2) {
	return ( [ "on" ] );
	}
else {
	return ( [ "on \"$in{'ServerIdent'}\"" ] );
	}
}

sub edit_ServerName
{
return (2, $text{'mod_core_servername'},
	&opt_input($_[0]->{'words'}->[0], "ServerName", $text{'default'}, 50));
}
sub save_ServerName
{
return &parse_opt("ServerName", '\S', $text{'mod_core_eservername'});
}

sub edit_ServerType
{
return (1, $text{'mod_core_type'},
	&select_input($_[0]->{'value'}, "ServerType", "",
		      "$text{'mod_core_inetd'},inetd",
		      "$text{'mod_core_stand'},standalone",
		      "$text{'default'},"));
}
sub save_ServerType
{
return &parse_choice("ServerType", "");
}

sub edit_ShowSymlinks
{
return (1, $text{'mod_core_links'},
	&choice_input($_[0]->{'value'}, "ShowSymlinks", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_ShowSymlinks
{
return &parse_choice("ShowSymlinks", "");
}

sub edit_SocketBindTight
{
return (1, $text{'mod_core_tight'},
	&choice_input($_[0]->{'value'}, "SocketBindTight", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_SocketBindTight
{
return &parse_choice("SocketBindTight", "");
}

sub edit_SyslogFacility
{
local @facils = map { "$_,$_" } ( 'auth', 'authpriv', 'cron', 'daemon', 'kern', 'lpr', 'mail', 'news', 'user', 'uucp', 'local0', 'local1', 'local2', 'local3', 'local4', 'local5', 'local6', 'local7' );
return (1, $text{'mod_core_facility'},
	&select_input($_[0]->{'value'}, "SyslogFacility", "",
		      "$text{'default'},", @facils));
}
sub save_SyslogFacility
{
return &parse_select("SyslogFacility", "");
}

sub edit_SyslogLevel
{
local @levels = map { "$_,$_" } ( 'emerg', 'alert', 'crit', 'error', 'warn', 'notice', 'info', 'debug' );
return (1, $text{'mod_core_level'},
	&select_input($_[0]->{'value'}, "SyslogLevel", "",
		      "$text{'default'},", @levels));
}
sub save_SyslogLevel
{
return &parse_select("SyslogLevel", "");
}

sub edit_TransferLog
{
local $mode = $_[0]->{'value'} eq 'NONE' ? 2 :
	      $_[0]->{'value'} ? 0 : 1;
local $rv = sprintf "<input type=radio name=TransferLog_def value=1 %s> %s\n",
		$mode == 1 ? "checked" : "", $text{'default'};
if ($_[1]->{'version'} >= 1.17) {
	$rv .= sprintf"<input type=radio name=TransferLog_def value=2 %s> %s\n",
		$mode == 2 ? "checked" : "", $text{'mod_core_nowhere'};
	}
$rv .= sprintf "<input type=radio name=TransferLog_def value=0 %s>\n",
		$mode == 0 ? "checked" : "";
$rv .= sprintf "<input name=TransferLog size=50 value='%s'>\n",
		$mode == 0 ? $_[0]->{'value'} : "";
return (2, $text{'mod_core_tlog'}, $rv);
}
sub save_TransferLog
{
if ($in{'TransferLog_def'} == 1) {
	return ( [ ] );
	}
elsif ($in{'TransferLog_def'} == 2) {
	return ( [ 'NONE' ] );
	}
else {
	$in{'TransferLog'} =~ /^\/\S+$/ || &error($text{'mod_core_etlog'}); 
	return ( [ $in{'TransferLog'} ] );
	}
}

sub edit_tcpBackLog
{
return (1, $text{'mod_core_backlog'},
	&opt_input($_[0]->{'value'}, "tcpBackLog", $text{'default'}, 6));
}
sub save_tcpBackLog
{
return &parse_opt("tcpBackLog", '^\d+$', $text{'mod_core_ebacklog'});
}

sub edit_tcpNoDelay
{
return (1, $text{'mod_core_nodelay'},
	&choice_input($_[0]->{'value'}, "tcpNoDelay", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_tcpNoDelay
{
return &parse_choice("tcpNoDelay", "");
}

sub edit_tcpReceiveWindow
{
return (1, $text{'mod_core_rwindow'},
	&opt_input($_[0]->{'value'}, "tcpReceiveWindow", $text{'default'}, 6));
}
sub save_tcpReceiveWindow
{
return &parse_opt("tcpReceiveWindow", '^\d+$', $text{'mod_core_erwindow'});
}

sub edit_tcpSendWindow
{
return (1, $text{'mod_core_swindow'},
	&opt_input($_[0]->{'value'}, "tcpSendWindow", $text{'default'}, 6));
}
sub save_tcpSendWindow
{
return &parse_opt("tcpSendWindow", '^\d+$', $text{'mod_core_eswindow'});
}

sub edit_TimesGMT
{
return (1, $text{'mod_core_gmt'},
	&choice_input($_[0]->{'value'}, "TimesGMT", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_TimesGMT
{
return &parse_choice("TimesGMT", "");
}

sub edit_TimeoutIdle
{
return (1, $text{'mod_core_tidle'},
	&opt_input($_[0]->{'value'}, "TimeoutIdle", $text{'default'}, 6,
		   $text{'mod_core_secs'}));
}
sub save_TimeoutIdle
{
return &parse_opt("TimeoutIdle", '^\d+$', $text{'mod_core_etidle'});
}

sub edit_TimeoutLogin
{
return (1, $text{'mod_core_tlogin'},
	&opt_input($_[0]->{'value'}, "TimeoutLogin", $text{'default'}, 6,
		   $text{'mod_core_secs'}));
}
sub save_TimeoutLogin
{
return &parse_opt("TimeoutLogin", '^\d+$', $text{'mod_core_etlogin'});
}

sub edit_TimeoutNoTransfer
{
return (1, $text{'mod_core_ttransfer'},
	&opt_input($_[0]->{'value'}, "TimeoutNoTransfer", $text{'default'}, 6,
		   $text{'mod_core_secs'}));
}
sub save_TimeoutNoTransfer
{
return &parse_opt("TimeoutNoTransfer", '^\d+$', $text{'mod_core_ettransfer'});
}

sub edit_TimeoutStalled
{
return (1, $text{'mod_core_tstalled'},
	&opt_input($_[0]->{'value'}, "TimeoutStalled", $text{'default'}, 6,
		   $text{'mod_core_secs'}));
}
sub save_TimeoutStalled
{
return &parse_opt("TimeoutStalled", '^\d+$', $text{'mod_core_etstalled'});
}

sub edit_Umask
{
local $rv;
$rv .= sprintf "<input type=radio name=Umask_def value=1 %s> %s\n",
	$_[0]->{'words'}->[0] ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=Umask_def value=0 %s> %s\n",
	$_[0]->{'words'}->[0] ? "checked" : "", $text{'mod_core_octal'};
$rv .= sprintf "<input name=Umask size=5 value='%s'>\n",
	$_[0]->{'words'}->[0];

$rv .= "&nbsp;&nbsp;&nbsp;<b>$text{'mod_core_umask_d'}</b>\n";
$rv .= sprintf "<input type=radio name=Umask_d_def value=1 %s> %s\n",
	$_[0]->{'words'}->[1] ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=Umask_d_def value=0 %s> %s\n",
	$_[0]->{'words'}->[1] ? "checked" : "", $text{'mod_core_octal'};
$rv .= sprintf "<input name=Umask_d size=5 value='%s'>\n",
	$_[0]->{'words'}->[1];

return (2, $text{'mod_core_umask'}, $rv);
}
sub save_Umask
{
if ($in{'Umask_def'}) {
	return ( [ ] );
	}
else {
	$in{'Umask'} =~ /^[0-7]{3}$/ || &error($text{'mod_core_eumask'});
	if ($in{'Umask_d_def'}) {
		return ( [ $in{'Umask'} ] );
		}
	else {
		$in{'Umask_d'} =~ /^[0-7]{3}$/ || &error($text{'mod_core_eumask'});
		return ( [ $in{'Umask'}." ".$in{'Umask_d'} ] );
		}
	}
}

sub edit_UseFtpUsers
{
return (1, $text{'mod_core_ftpusers'},
	&choice_input($_[0]->{'value'}, "UseFtpUsers", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_UseFtpUsers
{
return &parse_choice("UseFtpUsers", "");
}

sub edit_UseHostsAllowFile
{
return (2, $text{'mod_core_hostsallow'},
	&opt_input($_[0]->{'value'}, "UseHostsAllowFile", $text{'default'}, 50,
		   &file_chooser_button("UseHostsAllowFile")));
}
sub save_UseHostsAllowFile
{
$in{'UseHostsAllowFile_def'} || -r $in{'UseHostsAllowFile'} ||
	&error($text{'mod_core_ehostsallow'});
return &parse_opt("UseHostsAllowFile");
}

sub edit_UseHostsDenyFile
{
return (2, $text{'mod_core_hostsdeny'},
	&opt_input($_[0]->{'value'}, "UseHostsDenyFile", $text{'default'}, 50,
		   &file_chooser_button("UseHostsDenyFile")));
}
sub save_UseHostsDenyFile
{
$in{'UseHostsDenyFile_def'} || -r $in{'UseHostsDenyFile'} ||
	&error($text{'mod_core_ehostsdeny'});
return &parse_opt("UseHostsDenyFile");
}

sub edit_UseReverseDNS
{
return (1, $text{'mod_core_revdns'},
	&choice_input($_[0]->{'value'}, "UseReverseDNS", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_UseReverseDNS
{
return &parse_choice("UseReverseDNS", "");
}

sub edit_UserDirRoot
{
return (1, $text{'mod_core_userdir'},
	&choice_input($_[0]->{'value'}, "UserDirRoot", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'default'},"));
}
sub save_UserDirRoot
{
return &parse_choice("UserDirRoot", "");
}

sub edit_User
{
local($rv, @uinfo);
$rv = sprintf "<input type=radio name=User value=0 %s> $text{'default'}\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=User value=1 %s> %s\n",
        $_[0] && $_[0]->{'value'} !~ /^#/ ? "checked" : "",
	$text{'mod_core_uname'};
$rv .= sprintf "<input name=User_name size=8 value=\"%s\"> %s&nbsp;\n",
	$_[0]->{'value'} !~ /^#/ ? $_[0]->{'value'} : "",
	&user_chooser_button("User_name", 0);
$rv .= sprintf "<input type=radio name=User value=2 %s> %s\n",
        $_[0]->{'value'} =~ /^#/ ? "checked" : "",
	$text{'mod_core_uid'};
$rv .= sprintf "<input name=User_id size=6 value=\"%s\">\n",
	 $_[0]->{'value'} =~ /^#(.*)$/ ? $1 : "";
return (2, $text{'mod_core_user'}, $rv);
}
sub save_User
{
if ($in{'User'} == 0) { return ( [ ] ); }
elsif ($in{'User'} == 1) { return ( [ $in{'User_name'} ] ); }
elsif ($in{'User_id'} !~ /^\-?\d+$/) {
	&error(&text('core_egid', $in{'User_id'}));
	}
else { return ( [ "#$in{'User_id'}" ] ); }
}

sub edit_UserAlias
{
local $rv = "<table border>\n".
	    "<tr $tb> <td><b>$text{'mod_core_afrom'}</b></td> ".
	    "<td><b>$text{'mod_core_ato'}</b></td> </tr>\n";
local $i = 0;
foreach $u (@{$_[0]}, { }) {
	local @w = @{$u->{'words'}};
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=UserAlias_f_$i size=15 value='$w[0]'></td>\n";
	$rv .= "<td><input name=UserAlias_t_$i size=15 value='$w[1]'></td>\n";
	$rv .= "</tr>\n";
	$i++;
	}
$rv .= "</table>\n";
return (2, $text{'mod_core_ualias'}, $rv);
}
sub save_UserAlias
{
local @rv;
for($i=0; defined($in{"UserAlias_f_$i"}); $i++) {
	next if (!$in{"UserAlias_f_$i"});
	$in{"UserAlias_f_$i"} =~ /^\S+$/ || &error($text{'mod_core_eafrom'});
	$in{"UserAlias_t_$i"} =~ /^\S+$/ || &error($text{'mod_core_eato'});
	push(@rv, $in{"UserAlias_f_$i"}.' '.$in{"UserAlias_t_$i"});
	}
return ( \@rv );
}

sub edit_UserOwner
{
return (1, $text{'mod_core_uowner'},
	&opt_input($_[0]->{'value'}, "UserOwner", $text{'default'}, 13,
		   &user_chooser_button("UserOwner")));
}
sub save_UserOwner
{
if ($in{'UserOwner_def'}) { return ( [ ] ); }
else {
	getpwnam($in{'UserOwner'}) || &error($text{'mod_core_euowner'});
	return ( [ $in{'UserOwner'} ] );
	}
}

sub edit_UserPassword
{
local $rv = "<table border>\n";
$rv .= "<tr $tb> <td><b>$text{'mod_core_upname'}</b></td> ".
       "<td><b>$text{'mod_core_uppass'}</b></td> </tr>\n";
local $i = 0;
foreach $u (@{$_[0]}) {
	local @v = @{$u->{'words'}};
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=UserPassword_n_$i size=13 value='$v[0]'></td>\n";
	$rv .= "<td><input type=radio name=UserPassword_d_$i value='$v[1]' checked> $text{'mod_core_updef'}\n";
	$rv .= "<input type=radio name=UserPassword_d_$i value=0>\n";
	$rv .= "<input name=UserPassword_p_$i size=25></td> </tr>\n";
	$i++;
	}
$rv .= "<tr $cb>\n".
       "<td><input name=UserPassword_n_$i size=13></td>\n".
       "<td><input name=UserPassword_p_$i size=35></td>\n".
       "</tr> </table>\n";
return (2, $text{'mod_core_userpassword'}, $rv);
}
sub save_UserPassword
{
local @rv;
for($i=0; defined($in{"UserPassword_n_$i"}); $i++) {
	next if (!$in{"UserPassword_n_$i"});
	scalar(getpwnam($in{"UserPassword_n_$i"})) ||
		&error($text{'mod_core_eupname'});
	if ($in{"UserPassword_d_$i"}) {
		push(@rv, $in{"UserPassword_n_$i"}.' '.
			  $in{"UserPassword_d_$i"});
		}
	else {
		$salt = substr(time(), 0, 2);
		push(@rv, $in{"UserPassword_n_$i"}.' '.
			  &unix_crypt($in{"UserPassword_p_$i"}, $salt));
		}
	}
return ( \@rv );
}

sub edit_WtmpLog
{
return (1, $text{'mod_core_wtmp'},
	&choice_input($_[0]->{'value'}, "WtmpLog", "",
		      "$text{'yes'},on", "$text{'no'},off",
		      "$text{'mod_core_none'},NONE", "$text{'default'},"));
}
sub save_WtmpLog
{
return &parse_choice("WtmpLog", "");
}

