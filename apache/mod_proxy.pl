# mod_proxy.pl
# Editors for proxy directives

sub mod_proxy_directives
{
local $rv;
$rv = [ [ 'ProxyRequests', 0, 13, 'virtual', undef, 11 ],
        [ 'ProxyRemote', 1, 13, 'virtual', undef, 7 ],
        [ 'ProxyPass', 1, 10, 'virtual', undef, 0 ],
        [ 'ProxyPassReverse', 1, 10, 'virtual', 1.306, 0 ],
        [ 'ProxyBlock', 1, 13, 'virtual', 1.2, 9 ],
        [ 'NoProxy', 1, 13, 'virtual', 1.3, 5 ],
        [ 'ProxyDomain', 0, 13, 'virtual', 1.3, 4 ],
	[ 'AllowCONNECT', 0, 13, 'virtual', 1.302, 2 ],
        [ 'CacheRoot', 0, 13, 'virtual', -2.0, 10 ],
        [ 'CacheSize', 0, 13, 'virtual', -2.0 ],
        [ 'CacheGcInterval', 0, 13, 'virtual', -2.0 ],
        [ 'CacheMaxExpire', 0, 13, 'virtual', -2.0 ],
        [ 'CacheLastModifiedFactor', 0, 13, 'virtual', -2.0 ],
        [ 'CacheDirLevels', 0, 13, 'virtual', -2.0 ],
        [ 'CacheDirLength', 0, 13, 'virtual', -2.0 ],
        [ 'CacheDefaultExpire', 0, 13, 'virtual', -2.0 ],
        [ 'CacheForceCompletion', 0, 13, 'virtual', '1.301-2.0' ],
        [ 'NoCache', 1, 13, 'virtual', -2.0, 3 ],
	[ 'ProxyMaxForwards', 0, 13, 'virtual', 2.0 ],
	[ 'ProxyPreserveHost', 0, 13, 'virtual', 2.031 ],
	[ 'ProxyTimeout', 0, 13, 'virtual', 2.031 ],
	[ 'ProxyVia', 0, 13, 'virtual', 2.0 ] ];
return &make_directives($rv, $_[0], "mod_proxy");
}

require 'cache.pl';

sub edit_ProxyRequests
{
return (1, $text{'mod_proxy_proxy'},
        &choice_input($_[0]->{'value'}, "ProxyRequests", "off",
                      "$text{'yes'},on", "$text{'no'},off"));
}
sub save_ProxyRequests
{
return &parse_choice("ProxyRequests", "off");
}

sub edit_ProxyRemote
{
local($rv, $i, $match, $proxy, $max);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_proxy_req'}</b></td> <td><b>$text{'mod_proxy_forw'}</b></td> </tr>\n";
$max = @{$_[0]}+1;
for($i=0; $i<$max; $i++) {
	if ($_[0]->[$i]->{'value'} =~ /^(\S+)\s+(\S+)$/) {
		$match = $1; $proxy = $2;
		}
	else {
		$match = "*"; $proxy = "";
		}
	$rv .= "<tr $cb>\n";
	$rv .= sprintf
	        "<td><input type=radio name=ProxyRemote_match_all_$i value=1 %s> $text{'mod_proxy_all'}\n",
	        $match eq "*" ? "checked" : "";
	$rv .= sprintf
	        "<input type=radio name=ProxyRemote_match_all_$i value=0 %s> $text{'mod_proxy_match'}\n",
	        $match eq "*" ? "" : "checked";
	$rv .= sprintf
	        "<input name=ProxyRemote_match_$i size=20 value=\"%s\"></td>\n",
	        $match eq "*" ? "" : $match;
	$rv .= "<td><input name=ProxyRemote_proxy_$i size=20 ".
	       "value=\"$proxy\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, $text{'mod_proxy_pass'}, $rv);
}
sub save_ProxyRemote
{
local($i, $match, $match_all, $proxy, @rv);
for($i=0; defined($proxy = $in{"ProxyRemote_proxy_$i"}); $i++) {
	$match = $in{"ProxyRemote_match_$i"};
	$match_all = $in{"ProxyRemote_match_all_$i"};
	if ($match !~ /\S/ && $proxy !~ /\S/) { next; }
	if ($match_all) { $match = "*"; }
	elsif ($match !~ /^\S+$/) { &error(&text('mod_proxy_erequest', $match)); }
	$proxy =~ /^http:\/\/\S+$/ || &error(&text('mod_proxy_epurl', $proxy));
	push(@rv, "$match $proxy");
	}
return ( \@rv );
}

sub edit_ProxyPass
{
return (2, $text{'mod_proxy_map'},
	&proxy_pass_input($_[0], "ProxyPass", $_[1]));
}
sub save_ProxyPass
{
return &parse_proxy_pass("ProxyPass");
}

sub edit_ProxyPassReverse
{
return (2, $text{'mod_proxy_headers'},
	&proxy_pass_input($_[0], "ProxyPassReverse", $_[1]));
}
sub save_ProxyPassReverse
{
return &parse_proxy_pass("ProxyPassReverse");
}

# proxy_pass_input(&directives, name, &config)
sub proxy_pass_input
{
local($rv, $i, $path, $url, $max);
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_proxy_local'}</b></td> <td><b>$text{'mod_proxy_remote'}</b></td> </tr>\n";
$max = @{$_[0]} + 1;
for($i=0; $i<$max; $i++) {
	if ($_[0]->[$i]->{'value'} =~ /^(\S+)\s+(\S+)$/) {
		$path = $1; $url = $2;
		}
	else { $path = $url = ""; }
	$rv .= "<tr $cb>\n";
	$rv .= "<td>".&ui_textbox("$_[1]_path_$i", $path, 20)."</td>\n";
	if ($_[2]->{'version'} >= 2.0) {
		$rv .= "<td>".&ui_opt_textbox("$_[1]_url_$i",
				$url eq "!" ? undef : $url, 30,
				$text{'mod_proxy_not'})."</td>\n";
		}
	else {
		$rv .= "<td>".&ui_textbox("$_[1]_url_$i", $url, 30),"</td>";
		}
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return $rv;
}

# parse_proxy_pass(name)
sub parse_proxy_pass
{
local($i, $url, $path, @rv, @notrv);
for($i=0; defined($path = $in{"$_[0]_path_$i"}); $i++) {
	$url = $in{"$_[0]_url_${i}_def"} ? "!" : $in{"$_[0]_url_$i"};
	next if (!$path);
	$path =~ /^\/\S*$/ || &error(&text('mod_proxy_elurl', $path));
	$url =~ /^(http|https|balancer|ajp):\/\/(\S+)$/ || $url eq "!" ||
		&error(&text('mod_proxy_erurl', $url));
	if ($url eq "!") {
		push(@notrv, "$path $url");
		}
	else {
		push(@rv, "$path $url");
		}
	}
return ( [ @notrv, @rv ] );
}

sub edit_ProxyBlock
{
local($b, @b);
foreach $b (@{$_[0]}) { push(@b, split(/\s+/, $b->{'value'})); }
return (2, $text{'mod_proxy_block'},
        &opt_input(@b ? join(' ', @b) : undef, "ProxyBlock", $text{'mod_proxy_none3'}, 50));
}
sub save_ProxyBlock
{
return &parse_opt("ProxyBlock", '\S', $text{'mod_proxy_eblock'});
}

sub edit_NoProxy
{
local($n, @n, $i, $rv);
foreach $n (@{$_[0]}) { push(@n, split(/\s+/, $n->{'value'})); }
$rv = "<table border>\n".
      "<tr $tb> <td><b>$text{'mod_proxy_type'}</b></td> <td><b>$text{'mod_proxy_noproxy'}</b></td> </tr>\n";
for($i=0; $i<=@n; $i++) {
	$rv .= "<tr $cb>\n";
	if ($i>=@n) { $type = 0; }
	elsif ($n[$i] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
		if ($4 == 0) { $type = 3; }
		else { $type = 0; }
		}
	elsif ($n[$i] =~ /^([0-9\.]+)\/(\d+)$/) { $type = 4; }
	elsif ($n[$i] =~ /^([0-9\.]+)$/) { $type = 3; }
	elsif ($n[$i] =~ /^\.(\S+)$/) { $type = 2; }
	else { $type = 1; }
	$rv .= "<td>".&select_input($type, "NoProxy_type_$i", 0,
		"$text{'mod_proxy_ip'},0", "$text{'mod_proxy_host'},1",
		"$text{'mod_proxy_domain'},2", "$text{'mod_proxy_net'},3",
		"$text{'mod_proxy_netbit'},4")."</td>\n";
	$rv .= "<td><input name=NoProxy_for_$i size=30 value=\"$n[$i]\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, $text{'mod_proxy_nopass'}, $rv);
}
sub save_NoProxy
{
local($i, $type, $for, @rv);
for($i=0; defined($type = $in{"NoProxy_type_$i"}); $i++) {
	$for = $in{"NoProxy_for_$i"};
	if ($for !~ /\S/) { next; }
	if ($type == 0) {
		&check_ipaddress($for) || 
		    &check_ip6address($for) || 
			&error(&text('mod_proxy_eip', $for));
		}
	elsif ($type == 1) {
		$for =~ /^[A-z0-9\-][A-z0-9\-\.]+[A-z0-9\-]$/ ||
			&error(&text('mod_proxy_ehost', $for));
		}
	elsif ($type == 2) {
		$for =~ /^\.[A-z0-9\-\.]+[A-z0-9\-]$/ ||
			&error(&text('mod_proxy_edomain', $for));
		}
	elsif ($type == 3) {
		if ($for =~ /^(\d+)$/) { $for .= ".0.0.0"; }
		elsif ($for =~ /^(\d+)\.(\d+)$/) { $for .= ".0.0"; }
		elsif ($for =~ /^(\d+)\.(\d+)\.(\d+)$/) { $for .= ".0"; }
		&check_ipaddress($for) || &error(&text('mod_proxy_enet', $for));
		}
	elsif ($type == 4) {
		($for =~ /^(\S+)\/(\d+)$/ &&
	          (&check_ipaddress($1) || &check_ip6address($1)) && $2 < 32) ||
			&error(&text('mod_proxy_enetbit', $for));
		}
	push(@rv, $for);
	}
return @rv ? ( [ join(' ', @rv) ] ) : ( [ ] );
}

sub edit_ProxyDomain
{
return (1, $text{'mod_proxy_nodomain'},
        &opt_input($_[0]->{'value'}, "ProxyDomain", $text{'mod_proxy_none'}, 20));
}
sub save_ProxyDomain
{
return &parse_opt("ProxyDomain", '^[A-z0-9\-]+$', $text{'mod_proxy_enodomain'});
}

sub edit_AllowCONNECT
{
return (1, $text{'mod_proxy_connect'},
        &opt_input($_[0]->{'value'}, "AllowCONNECT", $text{'mod_proxy_default'}, 10));
}
sub save_AllowCONNECT
{
return &parse_opt("AllowCONNECT", '^[\d ]+$', $text{'mod_proxy_econnect'});
}

sub edit_ProxyMaxForwards
{
return (1, $text{'mod_proxy_maxfw'},
	&opt_input($_[0]->{'value'}, "ProxyMaxForwards", $text{'default'}, 5));
}
sub save_ProxyMaxForwards
{
return &parse_opt("ProxyMaxForwards", '^\d+$', $text{'mod_proxy_emaxfw'});
}

sub edit_ProxyPreserveHost
{
return (1, $text{'mod_proxy_preserve'},
	&choice_input($_[0]->{'value'}, "ProxyPreserveHost", "",
	      "$text{'yes'},on", "$text{'no'},off", "$text{'default'},"));
}
sub save_ProxyPreserveHost
{
return &parse_choice("ProxyPreserveHost", "");
}

sub edit_ProxyTimeout
{
return (1, $text{'mod_proxy_timeout'},
	&opt_input($_[0]->{'value'}, "ProxyTimeout", $text{'default'}, 5));
}
sub save_ProxyTimeout
{
return &parse_opt("ProxyTimeout", '^\d+$', $text{'mod_proxy_etimeout'});
}

sub edit_ProxyVia
{
return (1, $text{'mod_proxy_via'},
	&choice_input($_[0]->{'value'}, "ProxyVia", "",
	      "$text{'yes'},on", "$text{'no'},off", "$text{'default'},"));
}
sub save_ProxyVia
{
return &parse_choice("ProxyVia", "");
}



1;

