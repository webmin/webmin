# core.pl
# Defines the core module directives

# core_directives(version)
# Returns ar array of references to associative arrays, each containing
# information about some directive. The keys of each array are:
#  name -	The name of this directive
#  type -	What kind of directive this in. Possible values are
#		0 - Processes and limits
#		1 - Networking and addresses
#		2 - Apache Modules
#		3 - Log files
#		4 - Access control
#		5 - document options
#		6 - MIME types
#		7 - Error handling
#		8 - Users and Groups
#		9 - Miscellaneous
#		10- Aliases and redirects
#		11- CGI programs
#		12- Directory indexing
#		13- Proxying
#		14- SSL
#		15- Perl
#		16- PHP
#		17- Vhost aliases
#		18- Filters
#		19- Character Sets
#		20- Image maps
#  multiple -	Can this directive appear multiple times
#  global -	Can be used in the global server context
#  virtual -	Can be used in a VirtualHost section or in the global section
#  directory -	Can be used in a Directory section context
#  htaccess -	Can be used in a .htaccess file
sub core_directives
{
local($rv);
$rv = [	[ 'AccessFileName', 0, 5, 'virtual', undef, 5 ],
	[ 'AddDefaultCharset', 0, 19, 'virtual directory htaccess', 2.0 ],
	&can_configure_apache_modules() ? ( ) :
		( [ 'ClearModuleList AddModule', 1, 2, 'global', -2.0 ] ),
	[ 'AllowOverride', 0, 5, 'directory' ],
	[ 'AuthName', 0, 4, 'directory htaccess', undef, 10 ],
	[ 'AuthType', 0, 4, 'directory htaccess', undef, 8 ],
	[ 'BindAddress Listen Port', 1, 1, 'global', -2.0, 10 ],
	[ 'ContentDigest', 0, 5, 'virtual directory htaccess' ],
	[ 'CoreDumpDirectory', 0, 9, 'global', '1.3-2.0' ],
	[ 'DefaultType', 0, 6, 'virtual directory htaccess' ],
	[ 'DocumentRoot', 0, 5, 'virtual', undef, 10 ],
	[ 'ErrorDocument', 1, 7, 'virtual directory htaccess' ],
	[ 'ErrorLog', 0, 3, 'virtual' ],
	[ 'FileETag', 0, 5, 'virtual directory htaccess', 2.0 ],
	[ 'ForceType', 0, 6, 'directory htaccess', 2.0 ],
	[ 'Group', 0, 8, 'virtual', -2.0 ],
	[ 'HostNameLookups', 0, 1, 'virtual directory' ],
	[ 'IdentityCheck', 0, 1, 'virtual directory' ],
	[ 'KeepAlive MaxKeepAliveRequests', 0, 1, 'global' ],
	[ 'KeepAliveTimeout', 0, 1, 'global' ],
	[ 'ListenBacklog', 0, 1, 'global', '1.2-2.0' ],
	[ 'LockFile', 0, 9, 'global', -2.0 ],
	[ 'LimitRequestBody', 0, 0, 'virtual directory htaccess', 1.302 ],
	[ 'LimitRequestFields', 0, 0, 'global', 1.302 ],
	[ 'LimitRequestFieldsize', 0, 0, 'global', 1.302 ],
	[ 'LimitRequestLine', 0, 0, 'global', 1.302 ],
	[ 'LimitXMLRequestBody', 0, 0, 'virtual directory htaccess', 2.0 ],
	[ 'LogLevel', 0, 3, 'virtual', 1.3 ],
	[ 'MaxClients', 0, 0, 'global', -2.0 ],
	[ 'MaxRequestsPerChild', 0, 0, 'global', -2.0 ],
	[ 'StartServers', 0, 0, 'global', -2.0 ],
	[ 'MinSpareServers', 0, 0, 'global', -2.0 ],
	[ 'MaxSpareServers', 0, 0, 'global', -2.0 ],
	[ 'NameVirtualHost', 1, 1, 'global', '1.3-2.4', 5 ],
	[ 'Options', 0, 5, 'virtual directory htaccess', undef, 3 ],
	[ 'PidFile', 0, 9, 'global', -2.0 ],
	[ 'require', 0, 4, 'directory htaccess', undef, 6 ],
	[ 'RLimitCPU', 0, 0, 'virtual', 1.2 ],
	[ 'RLimitMEM', 0, 0, 'virtual', 1.2 ],
	[ 'RLimitNPROC', 0, 0, 'virtual', 1.2 ],
	[ 'Satisfy', 0, 4, 'directory htaccess', 1.2, 4 ],
	[ 'ScoreBoardFile', 0, 9, 'global', '1.2-2.0' ],
	[ 'SendBufferSize', 0, 1, 'global', -2.0 ],
	[ 'ServerAdmin', 0, 1, 'virtual' ],
	$access{'names'} ? (
		[ 'ServerAlias', 1, 1, 'virtual virtualonly', 1.2 ],
		[ 'ServerName', 0, 1, 'virtual' ] ) : ( ),
	[ 'ServerPath', 0, 5, 'virtual' ],
	[ 'ServerType', 0, 9, 'global', -2.0 ],
	[ 'ServerTokens', 0, 9, 'global', 1.3 ],
	[ 'ServerSignature', 0, 5, 'virtual directory htaccess', 1.3 ],
	[ 'SetOutputFilter', 0, 18, 'virtual directory htaccess', 2.0 ],
	[ 'SetInputFilter', 0, 18, 'virtual directory htaccess', 2.0 ],
	[ 'TimeOut', 0, 1, 'global' ],
	[ 'UseCanonicalName', 0, 1, 'virtual directory', 1.3 ],
	[ 'User', 0, 8, 'virtual', -2.0, 10 ] ];
return &make_directives($rv, $_[0], "core");
}

# core_handlers(config, version)
# Returns an array of all available handlers
sub core_handlers
{
return ();
}

#########################################################################
# Process and limit directives
sub edit_MaxClients
{
return (1,
	$text{'core_maxconc'},
	&opt_input($_[0]->{'value'}, "MaxClients", $text{'core_default'}, 4));
}
sub save_MaxClients
{
return &parse_opt("MaxClients", '^\d+$',
		  $text{'core_emaxconc'});
}

sub edit_MaxKeepAliveRequests
{
return (1,
	$text{'core_maxkeep'},
	&opt_input($_[0]->{'value'}, "MaxKeepAliveRequests", $text{'core_default'}, 4));
}
sub save_MaxKeepAliveRequests
{
return &parse_opt("MaxKeepAliveRequests", '^\d+$',
		  $text{'core_emaxkeep'});
}

sub edit_MaxRequestsPerChild
{
return (1,
	$text{'core_maxreq'},
	&opt_input($_[0]->{'value'}, "MaxRequestsPerChild", $text{'core_default'}, 5));
}
sub save_MaxRequestsPerChild
{
return &parse_opt("MaxRequestsPerChild", '^\d+$',
		  $text{'core_emaxreq'});
}

sub edit_MinSpareServers
{
return (1,
	$text{'core_minspare'},
	&opt_input($_[0]->{'value'},"MinSpareServers",$text{'core_default'}, 4));
}
sub save_MinSpareServers
{
return &parse_opt("MinSpareServers", '^\d+$',
		  $text{'core_eminspare'});
}

sub edit_MaxSpareServers
{
return (1,
	$text{'core_maxspare'},
	&opt_input($_[0]->{'value'},"MaxSpareServers",$text{'core_default'}, 4));
}
sub save_MaxSpareServers
{
return &parse_opt("MaxSpareServers", '^\d+$',
		  $text{'core_emaxspare'});
}

sub edit_StartServers
{
return (1,
	$text{'core_initial'},
	&opt_input($_[0]->{'value'}, "StartServers", $text{'core_default'}, 4));
}
sub save_StartServers
{
return &parse_opt("StartServers", '^\d+$',
		  $text{'core_einitial'});
}

sub edit_RLimitCPU
{
return &rlimit_input("RLimitCPU", $text{'core_cpulimit'}, $_[0]);
}
sub save_RLimitCPU
{
return &parse_rlimit("RLimitCPU", $text{'core_cpulimit2'});
}

sub edit_RLimitMEM
{
return &rlimit_input("RLimitMEM", $text{'core_memlimit'}, $_[0]);
}
sub save_RLimitMEM
{
return &parse_rlimit("RLimitMEM", $text{'core_memlimit2'});
}

sub edit_RLimitNPROC
{
return &rlimit_input("RLimitNPROC", $text{'core_proclimit'}, $_[0]);
}
sub save_RLimitNPROC
{
return &parse_rlimit("RLimitNPROC", $text{'core_proclimit2'});
}

# rlimit_input(name, desc, value)
sub rlimit_input
{
local(@v, $rv);
@v = split(/\s+/, $_[2]->{'value'});
$rv = sprintf "<input type=radio name=$_[0]_mode value=0 %s> $text{'core_default'}<br>\n",
	@v ? "" : "checked";
$rv .= sprintf "<input type=radio name=$_[0]_mode value=1 %s>\n",
	@v == 1 ? "checked" : "";
$rv .= sprintf "$text{'core_slimit'}<input name=$_[0]_soft1 size=5 value=\"%s\"><br>\n",
	@v == 1 ? $v[0] : "";
$rv .= sprintf "<input type=radio name=$_[0]_mode value=2 %s>\n",
	@v == 2 ? "checked" : "";
$rv .= sprintf "$text{'core_slimit'}<input name=$_[0]_soft2 size=5 value=\"%s\">\n",
	@v == 2 ? $v[0] : "";
$rv .= sprintf "$text{'core_hlimit'}<input name=$_[0]_hard2 size=5 value=\"%s\"><br>\n",
	@v == 2 ? $v[1] : "";
return (1, $_[1], $rv);
}

# parse_rlimit(name, desc)
sub parse_rlimit
{
if ($in{"$_[0]_mode"} == 0) { return ( [ ] ); }
elsif ($in{"$_[0]_mode"} == 1) {
	$in{"$_[0]_soft1"} =~ /^(\d+|max)$/ ||
		&error(&text('core_eslimit', $in{"$_[0]_soft1"}, $_[1]));
	return ( [ $in{"$_[0]_soft1"} ] );
	}
elsif ($in{"$_[0]_mode"} == 2) {
	$in{"$_[0]_soft2"} =~ /^(\d+|max)$/ ||
		&error(&text('core_eslimit', $in{"$_[0]_soft2"}, $_[1]));
	$in{"$_[0]_hard2"} =~ /^(\d+|max)$/ ||
		&error(&text('core_ehlimit', $in{"$_[0]_hard2"}, $_[1]));
	return ( [ $in{"$_[0]_soft2"}." ".$in{"$_[0]_hard2"} ] );
	}
}


#########################################################################
# Networking and address directives
sub edit_BindAddress_Listen_Port
{
local($bref, $lref, $pref, @blist, @plist, @slist, $inp);
$bref = $_[0]; $lref = $_[1]; $pref = $_[2];
if (@$lref) {
	# listen directives in use.. so BindAddress and Port are unused
	foreach $l (@$lref) {
		my @w = split(/\s+/, $l->{'value'});
		if ($w[0] =~ /^\[(\S+)\]:(\d+)$/) {
			# IPv6 address and port
			push(@blist, $1); push(@plist, $2);
			}
		elsif ($w[0] =~ /^\[(\S+)\]$/) {
			# IPv6 address only
			push(@blist, $1); push(@plist, undef);
			}
		elsif ($w[0] =~ /^(\S+):(\d+)$/) {
			# IPv4 address and port
			push(@blist, $1); push(@plist, $2);
			}
		elsif ($w[0] =~ /^(\d+)$/) {
			# Port only
			push(@blist, "*"); push(@plist, $1);
			}
		elsif ($w[0] =~ /^(\S+)$/) {
			# IPv4 address or hostname only
			push(@blist, $1); push(@plist, undef);
			}
		push(@slist, $w[1]);
		}
	}
else {
	# no listen directives... check for BindAddress
	if (@$bref) { push(@blist, $bref->[@$bref-1]->{'value'}); }
	else { push(@blist, "*"); }
	push(@plist, undef);
	push(@slist, undef);
	}
$port = @$pref ? $pref->[@$pref-1]->{'value'} : 80;
if ($_[3]->{'version'} < 2.0) {
	$inp = "<b>$text{'core_dport'}</b> ".
	       &ui_textbox("Port", $port, 6)."<br>\n";
	}
my @cols = ( $text{'core_address'}, $text{'core_port'} );
if ($_[3]->{'version'} >= 2.4) {
	# Apache supports a port protocol
	push(@cols, $text{'core_portname'});
	}
$inp .= &ui_columns_start(\@cols, "50%");
for($i=0; $i<@blist+1; $i++) {
	my @row;
	my $ba = $blist[$i] eq "*" ? 1 : $blist[$i] eq "" ? 2 : 0;
	push(@row, &ui_radio("BindAddress_def_$i", $ba,
			[ [ 2, $text{'core_none'} ],
			  [ 1, $text{'core_all'} ],
			  [ 0, &ui_textbox("BindAddress_$i",
				$ba == 0 ? $blist[$i] : "", 20) ] ]));
	if ($_[3]->{'version'} < 2.0) {
		push(@row, &opt_input($plist[$i], "Port_$i",
				      $text{'core_default'}, 5));
		}
	else {
		push(@row, &ui_textbox("Port_$i", $plist[$i], 5));
		}
	if ($_[3]->{'version'} >= 2.4) {
		push(@row, &ui_select("Name_$i", $slist[$i],
				      [ [ "", $text{'core_protoany'} ],
					[ "http", "HTTP" ],
					[ "https", "HTTPS" ] ]));
		}
	$inp .= &ui_columns_row(\@row);
	}
$inp .= &ui_columns_end();
return (2, $text{'core_listen'}, $inp);
}
sub save_BindAddress_Listen_Port
{
local(@blist, @plist, @slist, $bdef, $b, $p);

# build list of addresses and ports
for($i=0; defined($in{"Port_$i"}); $i++) {
	$bdef = $in{"BindAddress_def_$i"}; $b = $in{"BindAddress_$i"};
	$pdef = $in{"Port_${i}_def"}; $p = $in{"Port_$i"};
	if ($bdef == 2) { next; }

	if ($bdef) { push(@blist, "*"); }
	elsif ($b =~ /^\S+$/ &&
	       (&to_ipaddress($b) || &to_ip6address($b))) { push(@blist, $b); }
	else { &error(&text('core_eaddress', $b)); }

	if ($pdef) { push(@plist, undef); }
	elsif ($p =~ /^\d+$/) { push(@plist, $p); }
	else { &error(&text('core_eport', $p)); }

	push(@slist, $in{"Name_$i"});
	}
if (!@blist) { &error($text{'core_eoneaddr'}); }

# Return directives
if ($_[0]->{'version'} < 2.0) {
	# Older apaches have a port directive as well
	$in{'Port'} =~ /^\d+$/ || &error($text{'core_edefport'});
	if (@blist == 1 && !$plist[0]) {
		# Only one address, and the default port
		return ( $blist[0] eq "*" ? [ ] : [ $blist[0] ], [ ],
			 [ $in{'Port'} ] );
		}
	else {
		# More than one address, or a non-default port. Must use Listens
		for($i=0; $i<@blist; $i++) {
			if ($blist[$i] ne "*" && $plist[$i]) {
				push(@l, "$blist[$i]:$plist[$i]");
				}
			elsif ($blist[$i] ne "*") { push(@l, $blist[$i]); }
			elsif ($plist[$i]) { push(@l, "*:$plist[$i]"); }
			else { push(@l, $in{'Port'}); }
			}
		return ( [], \@l, [ $in{'Port'} ] );
		}
	}
else {
	# Apache 2.0 just uses Listen directives
	local %doneport;
	for($i=0; $i<@blist; $i++) {
		if (&check_ip6address($blist[$i])) {
			$blist[$i] = "[".$blist[$i]."]";
			}
		if ($blist[$i] ne "*" && $plist[$i]) {
			push(@l, "$blist[$i]:$plist[$i]");
			}
		elsif ($blist[$i] ne "*") { push(@l, $blist[$i]); }
		else { push(@l, "*:$plist[$i]"); }
		if ($doneport{$l[$#l]}++) {
			# Same listen given twice
			&error(&text('core_eduplisten', $l[$#l]));
			}
		if ($_[0]->{'version'} >= 2.4 && $slist[$i]) {
			$l[$#l] .= " ".$slist[$i];
			}
		}
	return ( [], \@l );
	}
}

sub edit_KeepAlive_MaxKeepAliveRequests
{
$kref = $_[0]; $mref = $_[1];
if ($_[2]->{'version'} >= 1.2) {
	# two separate directives for keep-alives
	$inp = sprintf
		"<input type=radio name=KeepAlive_def value=0 %s> $text{'core_none'}\n".
		"<input type=radio name=KeepAlive_def value=1 %s> $text{'core_default'}\n".
		"<input type=radio name=KeepAlive_def value=2 %s> ".
		"<input name=KeepAlive size=5 value=\"%s\">",
		$kref->{'value'} =~ /off/i ? "checked" : "",
		$kref->{'value'} !~ /off/i && !$mref ? "checked" : "",
		$mref ? "checked" : "",
		$mref ? $mref->{'value'} : "";
	}
else {
	# only one directive
	$inp = sprintf
		"<input type=radio name=KeepAlive_def value=0 %s> $text{'core_none'}\n".
		"<input type=radio name=KeepAlive_def value=1 %s> $text{'core_default'}\n".
		"<input type=radio name=KeepAlive_def value=2 %s> ".
		"<input name=KeepAlive size=5 value=\"%s\">",
		$kref->{'value'} eq "0" ? "checked" : "",
		$kref ? "" : "checked" ,
		$kref->{'value'} ? "checked" : "",
		$kref->{'value'} ? $kref->{'value'} : "";
	}
return (1, $text{'core_multi'}, $inp);
}
sub save_KeepAlive_MaxKeepAliveRequests
{
if ($_[0]->{'version'} >= 1.2) {
	# two separate directives
	if ($in{'KeepAlive_def'} == 0) { return ( [ "off" ], [ ] ); }
	elsif ($in{'KeepAlive_def'} == 1) { return ( [ "on" ], [ ] ); }
	elsif ($in{'KeepAlive'} !~ /^\d+$/) {
		&error(&text('core_ekeep', $in{'KeepAlive'}));
		}
	else { return ( [ "on" ], [ $in{'KeepAlive'} ] ); }
	}
else {
	# only one directive
	if ($in{'KeepAlive_def'} == 0) { return ( [ 0 ], [ ] ); }
	elsif ($in{'KeepAlive_def'} == 1) { return ( [ ], [ ] ); }
	elsif ($in{'KeepAlive'} !~ /^\d+$/) {
		&error(&text('core_ekeep', $in{'KeepAlive'}));
		}
	else { return ( [ $in{'KeepAlive'} ], [ ] ); }
	}
}

sub edit_KeepAliveTimeout
{
return (1,
	$text{'core_keeptout'},
	&opt_input($_[0]->{'value'}, "KeepAliveTimeout", $text{'core_default'}, 5));
}
sub save_KeepAliveTimeout
{
return &parse_opt("KeepAliveTimeout", '^\d+$',
		  $text{'core_ekeeptout'});
}

sub edit_ListenBacklog
{
return (1,
	$text{'core_lqueue'},
	&opt_input($_[0]->{'value'}, "ListenBacklog", $text{'core_default'}, 4));
}
sub save_ListenBacklog
{
return &parse_opt("ListenBacklog", '^\d+$',
		  $text{'core_elqueue'});
}

sub edit_SendBufferSize
{
return (1,
	$text{'core_bufsize'},
	&opt_input($_[0]->{'value'}, "SendBufferSize", $text{'core_osdefault'}, 4));
}
sub save_SendBufferSize
{
return &parse_opt("SendBufferSize", '^\d+$',
		  $text{'core_ebufsize'});
}

sub edit_ServerAdmin
{
return (1, $text{'core_admin'},
        &opt_input($_[0]->{'value'}, "ServerAdmin", $text{'core_noadmin'}, 25));
}
sub save_ServerAdmin
{
return &parse_opt("ServerAdmin");
}

sub edit_TimeOut
{
return (1,
	$text{'core_rtout'},
	&opt_input($_[0]->{'value'}, "TimeOut", $text{'core_default'}, 4));
}
sub save_TimeOut
{
return &parse_opt("TimeOut", '^\d+$',
		  $text{'core_ertout'});
}

sub edit_UseCanonicalName
{
return (1, $text{'core_bhostname'},
        &choice_input($_[0]->{'value'}, "UseCanonicalName",
	               "", "$text{'yes'},off", "$text{'no'},on", "$text{'core_default'},"));
}
sub save_UseCanonicalName
{
return &parse_choice("UseCanonicalName", "");
}

sub edit_HostNameLookups
{
if ($_[1]->{'version'} >= 1.3) {
	return (1, $text{'core_lookup'},
		&choice_input($_[0]->{'value'}, "HostNameLookups", "",
		       "$text{'no'},off", "$text{'yes'},on", "$text{'core_ltwice'},double", "$text{'core_default'},"));
	}
else {
	return (1, $text{'core_lookup'},
		&choice_input($_[0]->{'value'}, "HostNameLookups", "",
			      "$text{'yes'},on", "$text{'no'},off", "$text{'core_default'},"));
	}
}
sub save_HostNameLookups
{
return &parse_choice("HostNameLookups", "");
}

sub edit_IdentityCheck
{
return (1, $text{'core_useauth'},
	&choice_input($_[0]->{'value'}, "IdentityCheck", "",
		      "$text{'yes'},on", "$text{'no'},off", "$text{'core_default'},"));
}
sub save_IdentityCheck
{
return &parse_choice("IdentityCheck", "");
}

sub edit_ServerAlias
{
local($a, @al);
foreach $a (@{$_[0]}) { push(@al, split(/\s+/, $a->{'value'})); }
return (1, $text{'core_altnames'},
	sprintf "<textarea name=ServerAlias rows=3 cols=25>%s</textarea>\n",
		join("\n", @al) );
}
sub save_ServerAlias
{
local(@al);
@al = split(/\s+/, $in{'ServerAlias'});
if (@al) {
	local @spal;
	while(@al > 200) {
		push(@spal, join(" ", @al[0 .. 199]));
		@al = @al[200 .. $#al];
		}
	push(@spal, join(" ", @al)) if (@al);
	return ( \@spal );
	}
else {
	return ( [ ] );
	}
}

sub edit_ServerName
{
return (1, $text{'core_hostname'},
	&opt_input($_[0]->{'value'}, "ServerName", $text{'core_auto'}, 25));
}
sub save_ServerName
{
return &parse_opt("ServerName", '^\S+$', $text{'core_ehostname'});
}

sub edit_NameVirtualHost
{
local(@nv, $nv, $star);
foreach $nv (@{$_[0]}) {
	if ($nv->{'value'} eq "*" && $_[1]->{'version'} >= 1.312) { $star++; }
	elsif ($nv->{'value'} =~ /^\[(\S+)\]$/) { push(@nv, $1); }
	else { push(@nv, $nv->{'value'}); }
	}
if ($_[1]->{'version'} >= 1.312) {
	$starui = sprintf
	  "<input type=checkbox name=NameVirtualHost_star value=1 %s> %s<br>\n",
	  $star ? "checked" : "", $text{'core_virtaddr_star'};
	}
return (1, $text{'core_virtaddr'},
	$starui.
	"<textarea name=NameVirtualHost rows=3 cols=30>".
	join("\n", @nv)."</textarea>");
}
sub save_NameVirtualHost
{
local(@nv, $nv, $addr);
@nv = split(/\s+/, $in{'NameVirtualHost'});
@nv = ( "*", @nv ) if ($in{'NameVirtualHost_star'});
foreach $nv (@nv) {
	if ($nv =~ /^\[(\S+)\]:(\d+|\*)$/) { $addr = $1; }
	elsif ($nv =~ /^(\S+):(\d+|\*)$/) { $addr = $1; }
	else { $addr = $nv; }
	if (!&to_ipaddress($addr) &&
	    !&to_ip6address($addr) && $addr ne '*') {
		&error(&text('core_evirtaddr', $addr));
		}
	if ($nv =~ /^(\S+):(\d+|\*)$/ && &check_ip6address($1)) {
		$nv = "[$1]:$2";
		}
	elsif (&check_ip6address($nv)) {
		$nv = "[$nv]";
		}
	}
if (@nv) { return ( \@nv ); }
else { return ( [ ] ); }
}

#########################################################################
# Document directives
sub edit_AccessFileName
{
return (1,
        $text{'core_optfile'},
        &opt_input($_[0]->{'value'}, "AccessFileName", $text{'core_default'}, 20));
}
sub save_AccessFileName
{
if ($_[0]->{'version'} < 1.3) {
	return &parse_opt("AccessFileName", '^(\S+)$',
	                  $text{'core_eoptfile'});
	}
else {
	return &parse_opt("AccessFileName", '\S',
			     $text{'core_enoopt'});
	}
}

@AllowOverride_v = ("AuthConfig", "FileInfo", "Indexes", "Limit", "Options");
@AllowOverride_d = ("$text{'core_auth'}", "$text{'core_mime'}",
                    "$text{'core_indexing'}", "$text{'core_hostacc'}",
                    "$text{'core_diropts'}");
sub edit_AllowOverride
{
local($rv, @ov, %over, $rv);
$rv = &choice_input($_[0] ? 0 : 1, "AllowOverride_def", 1,
		 "$text{'core_default'},1", "$text{'core_filesel'},0");
$rv .= "<table border><tr><td>\n";
if ($_[0]) { @ov = split(/\s+/, $_[0]->{'value'}); }
else { @ov = ("All"); }
foreach $ov (@ov) { $over{$ov}++; }
if ($over{'All'}) { foreach $ov (@AllowOverride_v) { $over{$ov}++; }	}
elsif ($over{'None'}) { %over = (); }

for($i=0; $i<@AllowOverride_v; $i++) {
	$rv .= sprintf "<input type=checkbox name=AllowOverride_%s %s> %s<br>\n",
	        $AllowOverride_v[$i],
	        $over{$AllowOverride_v[$i]} ? "checked" : "",
	        $AllowOverride_d[$i];
	}
$rv .= "</td></tr></table>\n";
return (1, $text{'core_overr'}, $rv);
}
sub save_AllowOverride
{
local(@ov, $ov);
if ($in{'AllowOverride_def'}) { return ( [ ] ); }
foreach $ov (@AllowOverride_v) {
	if ($in{"AllowOverride_$ov"}) { push(@ov, $ov); }
	}
if (!@ov) { return ( [ "None" ] ); }
elsif (@ov == @AllowOverride_v) { return ( [ "All" ] ); }
else { return ( [ join(' ', @ov) ] ); }
}

sub edit_ContentDigest
{
return (1,
	$text{'core_genmd5'},
	&choice_input($_[0]->{'value'}, "ContentDigest", "",
		      "$text{'yes'},on", "$text{'no'},off", "$text{'core_default'},"));
}
sub save_ContentDigest
{
return &parse_choice("ContentDigest", "");
}

sub edit_DocumentRoot
{
return (2, $text{'core_docroot'},
	&opt_input($_[0]->{'words'}->[0], "DocumentRoot", $text{'core_default'}, 40).
	&file_chooser_button("DocumentRoot", 1));
}
sub save_DocumentRoot
{
if (!$in{'DocumentRoot_def'}) {
	-d $in{'DocumentRoot'} ||
		&error(&text('core_enodoc', $in{'DocumentRoot'}));
	&allowed_doc_dir($in{'DocumentRoot'}) ||
		&error(&text('core_ecandoc', $in{'DocumentRoot'}));
	}
return &parse_opt("DocumentRoot");
}

sub edit_Options
{
local(@po, @o, $o, %opts, $opts, $po, @pon, $i);
@po = ("ExecCGI", "FollowSymLinks", "Includes", "IncludesNOEXEC",
       "Indexes", "MultiViews", "SymLinksIfOwnerMatch");
@pon = ("$text{'core_execcgi'}", "$text{'core_flink'}",
	"$text{'core_inclexe'}", "$text{'core_incl'}",
	"$text{'core_genind'}", "$text{'core_genmview'}",
	"$text{'core_flinkmatch'}");
$opts = &choice_input($_[0] ? 0 : 1, "Options_def", 1, "$text{'core_default'},1",
		      "$text{'core_optsel'},0")."<br>\n";
@o = split(/\s+/, $_[0]->{'value'});
foreach $o (split(/\s+/, $_[0]->{'value'})) {
	if ($o =~ /^\+(.*)$/) { $opts{$1} = 2; }
	elsif ($o =~ /^\-(.*)$/) { $opts{$1} = 3; }
	else { $opts{$o} = 1; }
	}
if ($opts{'All'}) {
	local($all); $all = $opts{'All'};
	undef(%opts);
	foreach $o (grep {!/MultiViews/} @po) {
		$opts{$o} = $all;
		}
	}
$opts .= "<table border>\n";
$opts .= "<tr $tb> <td><b>$text{'core_option'}</b></td> <td><b>$text{'core_setdir'}</b></td>\n";
$opts .= "<td><b>$text{'core_merge'}</b></td> </tr>\n";
for($i=0; $i<@po; $i++) {
	$po = $po[$i];
	$opts .= "<tr $cb> <td><b>$pon[$i]</b></td> <td>\n";
	$opts .= sprintf "<input type=radio name=$po value=1 %s> $text{'yes'}\n",
			$opts{$po}==1 ? "checked" : "";
	$opts .= sprintf "<input type=radio name=$po value=0 %s> $text{'no'}\n",
			$opts{$po}==0 ? "checked" : "";
	$opts .= "</td> <td>\n";
	$opts .= sprintf "<input type=radio name=$po value=2 %s> $text{'core_enable'}\n",
			$opts{$po}==2 ? "checked" : "";
	$opts .= sprintf "<input type=radio name=$po value=3 %s> $text{'core_disable'}\n",
			$opts{$po}==3 ? "checked" : "";
	$opts .= "</td> </tr>\n";
	}
$opts .= "</table>\n";
return (2, $text{'core_diropts'}, $opts);
}
sub save_Options
{
local(@po, $po, @rv);
if ($in{'Options_def'}) { return ( [ ] ); }
@po = ("ExecCGI", "FollowSymLinks", "Includes", "IncludesNOEXEC",
       "Indexes", "MultiViews", "SymLinksIfOwnerMatch");
foreach $po (@po) {
	if ($in{$po} == 1) { push(@rv, $po); }
	elsif ($in{$po} == 2) { push(@rv, "+$po"); }
	elsif ($in{$po} == 3) { push(@rv, "-$po"); }
	}
return @rv ? ( [ join(' ', @rv) ] ) : ( [ "None" ] );
}

sub edit_ServerPath
{
return (2,
	$text{'core_virtpath'},
	&opt_input($_[0]->{'value'}, "ServerPath", $text{'core_default'}, 40).
	&file_chooser_button("ServerPath", 1));
}
sub save_ServerPath
{
return &parse_opt("ServerPath", '^\/\S*$',
		  $text{'core_evirtpath'});
}

sub edit_ServerSignature
{
return (1, $text{'core_footer'},
	&select_input($_[0]->{'value'}, "ServerSignature", undef,
		      "$text{'core_sigemail'},Email", "$text{'core_signame'},On",
		      "$text{'core_signone'},Off", "$text{'core_default'},"));
}
sub save_ServerSignature
{
return &parse_select("ServerSignature", undef);
}

sub edit_FileETag
{
local (%et, $rv);
map { $et{lc($_)}++ } @{$_[0]->{'words'}} if ($_[0]);
$rv .= sprintf "<input type=radio name=FileETag_def value=1 %s> %s\n",
			$_[0] ? "" : "checked", $text{'default'};
$rv .= sprintf "<input type=radio name=FileETag_def value=0 %s> %s\n",
			$_[0] ? "checked" : "", $text{'core_fileetag_sel'};
foreach $e ('INode', 'MTime', 'Size') {
	$rv .= sprintf "<input type=checkbox name=FileETag value=%s %s> %s\n",
			$e, $et{lc($e)} || $et{'all'} ? "checked" : "",
			$text{'core_fileetag_'.lc($e)};
	}
return (2, $text{'core_fileetag'}, $rv);
}
sub save_FileETag
{
if ($in{'FileETag_def'}) {
	return ( [ ] );
	}
else {
	local @e = split(/\0/, $in{'FileETag'});
	return @e ? ( [ join(" ", @e) ] ) : ( [ "None" ] );
	}
}

#########################################################################
# MIME directives directives
sub edit_DefaultType
{
return (1,
	$text{'core_defmime'},
	&opt_input($_[0]->{'value'}, "DefaultType", $text{'core_default'}, 20));
}
sub save_DefaultType
{
return &parse_opt("DefaultType", '^(\S+)\/(\S+)$',
		  $text{'core_edefmime'});
}

sub edit_ForceType
{
return (1, $text{'mod_mime_defmime'},
	&opt_input($_[0]->{'value'}, "ForceType", $text{'mod_mime_real'}, 15));
}
sub save_ForceType
{
return &parse_opt("ForceType", '^\S+\/\S+$', $text{'mod_mime_etype'});
}

sub edit_SetOutputFilter
{
local @vals = split(/[\s;]+/, $_[0]->{'value'});
return (2, $text{'core_outfilter'},
	&filters_input(\@vals, "SetOutputFilter"));
}
sub save_SetOutputFilter
{
return &parse_filters("SetOutputFilter");
}

sub edit_SetInputFilter
{
local @vals = split(/[\s;]+/, $_[0]->{'value'});
return (2, $text{'core_infilter'},
	&filters_input(\@vals, "SetInputFilter"));
}
sub save_SetInputFilter
{
return &parse_filters("SetInputFilter");
}

sub edit_AddDefaultCharset
{
local $rv;
local $m = lc($_[0]->{'value'}) eq 'off' ? 2 :
	   $_[0]->{'value'} ? 0 : 1;
$rv .= sprintf "<input type=radio name=AddDefaultCharset_def value=1 %s> %s\n",
		$m == 1 ? "checked" : "", $text{'default'};
$rv .= sprintf "<input type=radio name=AddDefaultCharset_def value=2 %s> %s\n",
		$m == 2 ? 'checked' : "", $text{'core_none'};
$rv .= sprintf "<input type=radio name=AddDefaultCharset_def value=0 %s>\n",
		$m == 0 ? "checked" : "";
$rv .= sprintf "<input name=AddDefaultCharset size=12 value='%s'>\n",
		$m == 0 ? $_[0]->{'value'} : "";
return (1, $text{'core_defchar'}, $rv);
}
sub save_AddDefaultCharset
{
if ($in{'AddDefaultCharset_def'} == 1) {
	return ( [ ] );
	}
elsif ($in{'AddDefaultCharset_def'} == 2) {
	return ( [ "Off" ] );
	}
else {
	$in{'AddDefaultCharset'} =~ /^\S+$/ || &error($text{'core_edefchar'});
	return ( [ $in{'AddDefaultCharset'} ] );
	}
}

#########################################################################
# Access control directives
sub edit_AuthName
{
my $val = $_[1]->{'version'} >= 1.3 ? $_[0]->{'words'}->[0]
				    : $_[0]->{'value'};
return (1, $text{'core_realm'},
        &opt_input($val, "AuthName", $text{'core_default'}, 25));
}
sub save_AuthName
{
return $in{'AuthName_def'}	 ? ( [ ] ) :
       $_[0]->{'version'} >= 1.3 ? ( [ "\"$in{'AuthName'}\"" ] ) :
				   ( [ $in{'AuthName'} ] );
}

sub edit_AuthType
{
local($rv, $a);
$rv = "<select name=AuthType>\n";
foreach $a ("", "Basic", "Digest") {
	$rv .= sprintf "<option %s>$a</option>\n",
	        lc($_[0]->{'value'}) eq lc($a) ? "selected" : "";
	}
$rv .= "</select>";
return (1, $text{'core_authtype'}, $rv);
}
sub save_AuthType
{
if ($in{'AuthType'}) { return ( [ $in{'AuthType'} ] ); }
else { return ( [ ] ); }
}

sub edit_require
{
local($rv, $mode, $list);
local @w = @{$_[0]->{'words'}};
$mode = shift(@w);
$list = join(" ", map { $_ =~ /\s/ ? "\"$_\"" : $_ } @w);

# All users
$rv = sprintf
      "<input type=radio name=require_mode value=0 %s> $text{'default'}<br>\n",
      $mode ? "" : "checked";

# Only some users
$rv .= sprintf
      "<input type=radio name=require_mode value=1 %s> $text{'core_users'}:\n",
      $mode eq "user" ? "checked" : "";
$rv .= sprintf
      "<input name=require_user size=20 value=\"%s\"><br>\n",
      $mode eq "user" ? &html_escape($list) : "";

# Only members of groups
$rv .= sprintf
      "<input type=radio name=require_mode value=2 %s> $text{'core_groups'}:\n",
      $mode eq "group" ? "checked" : "";
$rv .= sprintf
      "<input name=require_group size=20 value=\"%s\"><br>\n",
      $mode eq "group" ? &html_escape($list) : "";

# All users
$rv .= sprintf
      "<input type=radio name=require_mode value=3 %s> $text{'core_allusers'}<br>\n",
      $mode eq "valid-user" ? "checked" : "";

if ($httpd_modules{'mod_authz_owner'} >= 2.2) {
	# File owner / group matches
	$rv .= sprintf
	      "<input type=radio name=require_mode value=4 %s> $text{'core_fileowner'}<br>\n",
	      $mode eq "file-owner" ? "checked" : "";
	$rv .= sprintf
	      "<input type=radio name=require_mode value=5 %s> $text{'core_filegroup'}<br>\n",
	      $mode eq "file-group" ? "checked" : "";

	}
return (1, $text{'core_authlog'}, $rv);
}
sub save_require
{
if ($in{'require_mode'} == 0) { return ( [ ] ); }
elsif ($in{'require_mode'} == 1) { return ( [ "user $in{'require_user'}" ] ); }
elsif ($in{'require_mode'} == 2) { return ( [ "group $in{'require_group'}" ] ); }
elsif ($in{'require_mode'} == 3) { return ( [ "valid-user" ] ); }
elsif ($in{'require_mode'} == 4) { return ( [ "file-owner" ] ); }
elsif ($in{'require_mode'} == 5) { return ( [ "file-group" ] ); }
else { return ( [ ] ); }	# huh?
}

sub edit_Satisfy
{
return (1, $text{'core_satisfy'},
	&choice_input_vert($_[0]->{'value'}, "Satisfy", "", "$text{'core_default'},",
			   "$text{'core_authall'},all","$text{'core_authany'},any"));
}
sub save_Satisfy
{
return &parse_choice("Satisfy", "");
}

#########################################################################
# Misc. directives
sub edit_CoreDumpDirectory
{
return (1, $text{'core_coredir'},
	 &opt_input($_[0]->{'words'}->[0], "CoreDumpDirectory", $text{'core_sroot'}, 20).
	 &file_chooser_button("CoreDumpDirectory", 1));
}
sub save_CoreDumpDirectory
{
return &parse_opt("CoreDumpDirectory", '^\S+$', $text{'core_ecore'});
}

sub edit_LockFile
{
return (1, $text{'core_lockfile'},
        &opt_input($_[0]->{'words'}->[0], "LockFile", $text{'core_default'}, 20).
        &file_chooser_button("LockFile", 0));
}
sub save_LockFile
{
return &parse_opt("LockFile", '^\S+', $text{'core_elock'});
}

sub edit_LimitRequestBody
{
return (1, $text{'core_maxbody'},
	&opt_input($_[0]->{'value'}, "LimitRequestBody", $text{'core_default'}, 8)
		.$text{'bytes'});
}
sub save_LimitRequestBody
{
return &parse_opt("LimitRequestBody", '^\d+$', $text{'core_ebody'});
}

sub edit_LimitXMLRequestBody
{
return (1, $text{'core_maxxml'},
	&opt_input($_[0]->{'value'}, "LimitXMLRequestBody",
		   $text{'core_default'}, 8).$text{'bytes'});
}
sub save_LimitXMLRequestBody
{
return &parse_opt("LimitXMLRequestBody", '^\d+$', $text{'core_exml'});
}



sub edit_LimitRequestFields
{
return (1, $text{'core_maxhead'},
	&opt_input($_[0]->{'value'}, "LimitRequestFields", $text{'core_default'}, 6));
}
sub save_LimitRequestFields
{
return &parse_opt("LimitRequestFields", '^\d+$', $text{'core_ehead'});
}

sub edit_LimitRequestFieldsize
{
return (1, $text{'core_maxshead'},
	&opt_input($_[0]->{'value'}, "LimitRequestFieldsize", $text{'core_default'}, 6));
}
sub save_LimitRequestFieldsize
{
return &parse_opt("LimitRequestFieldsize", '^\d+$', $text{'core_eshead'});
}

sub edit_LimitRequestLine
{
return (1, $text{'core_maxline'},
	&opt_input($_[0]->{'value'}, "LimitRequestLine", $text{'core_default'}, 6));
}
sub save_LimitRequestLine
{
return &parse_opt("LimitRequestLine", '^\d+$', $text{'core_eline'});
}

sub edit_PidFile
{
return (1, $text{'core_pid'},
        &opt_input($_[0]->{'words'}->[0], "PidFile", $text{'core_default'}, 20).
        &file_chooser_button("PidFile", 0));
}
sub save_PidFile
{
return &parse_opt("PidFile", '^\S+$', $text{'core_epid'});
}

sub edit_ScoreBoardFile
{
return (1, $text{'core_memsco'},
        &opt_input($_[0]->{'words'}->[0], "ScoreBoardFile", $text{'core_default'}, 20).
        &file_chooser_button("ScoreBoardFile", 0));
}
sub save_ScoreBoardFile
{
return &parse_opt("ScoreBoardFile", '^\S+$', $text{'core_escore'});
}

sub edit_ServerType
{
return (1, $text{'core_exec'},
        &choice_input($_[0]->{'value'}, "ServerType", "standalone",
                      "$text{'core_salone'},standalone", "$text{'core_inetd'},inetd"));
}
sub save_ServerType
{
return &parse_choice("ServerType", "standalone");
}

sub edit_ServerTokens
{
local $v = $_[0]->{'value'};
$v = "ProductOnly" if ($v eq "Prod");
$v = "Min" if ($v eq "Minimal");
return (1, $text{'core_header'},
	&select_input($v, "ServerTokens", "Full",
		      "$text{'core_verosmod'},Full",
		      "$text{'core_veros'},OS",
		      "$text{'core_ver'},Min",
		      "$text{'core_minor'},Minor",
		      $_[1]->{'version'} >= 1.313 ?
			("$text{'core_product'},ProductOnly") : (),
		      $_[1]->{'version'} >= 2.041 ?
			("$text{'core_major'},Major") : ()
			));
}
sub save_ServerTokens
{
return &parse_select("ServerTokens", "Full");
}

#########################################################################
# User/group directives
sub edit_Group
{
local($rv, @ginfo);
$rv = sprintf "<input type=radio name=Group value=0 %s>$text{'core_default'}&nbsp;\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=Group value=1 %s>$text{'core_group'}\n",
        $_[0] && $_[0]->{'words'}->[0] !~ /^#/ ? "checked" : "";
$rv .= sprintf "<input name=Group_name size=8 value=\"%s\"> %s&nbsp;\n",
	$_[0]->{'words'}->[0] !~ /^#/ ? $_[0]->{'words'}->[0] : "",
	&group_chooser_button("Group_name", 0);
$rv .= sprintf "<input type=radio name=Group value=2 %s>$text{'core_gid'}\n",
        $_[0]->{'words'}->[0] =~ /^#/ ? "checked" : "";
$rv .= sprintf "<input name=Group_id size=6 value=\"%s\">\n",
	 $_[0]->{'words'}->[0] =~ /^#(.*)$/ ? $1 : "";
return (2, $text{'core_asgroup'}, $rv);
}
sub save_Group
{
if ($in{'Group'} == 0) { return ( [ ] ); }
elsif ($in{'Group'} == 1) { return ( [ $in{'Group_name'} ] ); }
elsif ($in{'Group_id'} !~ /^\-?\d+$/) {
	&error(&text('core_euid', $in{'Group_id'}));
	}
else { return ( [ "\"#$in{'Group_id'}\"" ] ); }
}

sub edit_User
{
local($rv, @uinfo);
$rv = sprintf "<input type=radio name=User value=0 %s>$text{'core_default'}&nbsp;\n",
       $_[0] ? "" : "checked";
$rv .= sprintf "<input type=radio name=User value=1 %s>$text{'core_user'}\n",
        $_[0] && $_[0]->{'words'}->[0] !~ /^#/ ? "checked" : "";
$rv .= sprintf "<input name=User_name size=8 value=\"%s\"> %s&nbsp;\n",
	$_[0]->{'words'}->[0] !~ /^#/ ? $_[0]->{'words'}->[0] : "",
	&user_chooser_button("User_name", 0);
$rv .= sprintf "<input type=radio name=User value=2 %s>$text{'core_uid'}\n",
        $_[0]->{'words'}->[0] =~ /^#/ ? "checked" : "";
$rv .= sprintf "<input name=User_id size=6 value=\"%s\">\n",
	 $_[0]->{'words'}->[0] =~ /^#(.*)$/ ? $1 : "";
return (2, $text{'core_asuser'}, $rv);
}
sub save_User
{
if ($in{'User'} == 0) { return ( [ ] ); }
elsif ($in{'User'} == 1) { return ( [ $in{'User_name'} ] ); }
elsif ($in{'User_id'} !~ /^\-?\d+$/) {
	&error(&text('core_egid', $in{'User_id'}));
	}
else { return ( [ "\"#$in{'User_id'}\"" ] ); }
}

#########################################################################
# Error handling directives
sub edit_ErrorDocument
{
local($rv, $len, $i);
$rv = "<table border width=100%>\n";
$rv .= "<tr $tb> <td><b>$text{'core_error'}</b></td> <td><b>$text{'core_resp'}</b></td> ".
       "<td><b>$text{'core_urlmsg'}</b></td> </tr>\n";
$len = @{$_[0]} + 1;
for($i=0; $i<$len; $i++) {
	$v = $_[0]->[$i]->{'value'};
	if ($v =~ /^(\d+)\s+((http|https|ftp|gopher):\S+)$/)
		{ $code = $1; $type = 0; $url = $2; }
	elsif ($v =~ /^(\d+)\s+(\/.*)$/) { $code = $1; $type = 0; $url = $2; }
	elsif ($v =~ /^(\d+)\s+"(.*)"$/) { $code = $1; $type = 1; $url = $2; }
	elsif ($v =~ /^(\d+)\s+"?(.*)$/) { $code = $1; $type = 1; $url = $2; }
	else { $code = ""; $type = 0; $url = ""; }
	$rv .= "<tr $cb>\n";
	$rv .= "<td><input name=ErrorDocument_code_$i size=3 value=$code></td>\n";
	$rv .= "<td><input type=radio name=ErrorDocument_type_$i value=0 ".
	       ($type==0 ? "checked" : "").">$text{'core_tourl'}\n";
	$rv .= "<input type=radio name=ErrorDocument_type_$i value=1 ".
	       ($type==1 ? "checked" : "").">$text{'core_mesg'}</td>\n";
	$rv .= "<td><input name=ErrorDocument_url_$i size=40 value=\"$url\"></td>\n";
	$rv .= "</tr>\n";
	}
$rv .= "</table>\n";
return (2, $text{'core_custom'}, $rv);
}
sub save_ErrorDocument
{
local($i, $code, $url, @rv);
for($i=0; defined($in{"ErrorDocument_code_$i"}); $i++) {
	$code = $in{"ErrorDocument_code_$i"}; $url = $in{"ErrorDocument_url_$i"};
	if ($code !~ /\S/ || $url !~ /\S/) { next; }
	$code =~ /^\d\d\d$/ || &error(&text('core_eerror', $code));
	if ($in{"ErrorDocument_type_$i"} == 0) {
		$url =~ /^\S+$/ || &error(&text('core_eurl', $url));
		push(@rv, "$code $url");
		}
	elsif ($_[0]->{'version'} >= 2.0) { push(@rv, "$code \"$url\""); }
	elsif ($_[0]->{'version'} >= 1.2) { push(@rv, "$code \"$url"); }
	else { push(@rv, "$code $url"); }
	}
return ( \@rv );
}

#########################################################################
# Logging directives
sub edit_ErrorLog
{
if ($_[1]->{'version'} < 1.3) {
	return (1, $text{'core_errfile'},
		&opt_input($_[0]->{'value'}, "ErrorLog", $text{'core_default'}, 20).
		&file_chooser_button("ErrorLog", 0));
	}
else {
	local $v = $_[0]->{'words'}->[0];
	local $t = !$v ? 3 :
		   $v eq 'syslog' ? 2 :
		   $v =~ /^\|/ ? 1 : 0;
	$rv = sprintf "<input type=radio name=ErrorLog_type value=3 %s>\n",
		$t == 3 ? "checked" : "";
	$rv .= "$text{'core_default'}";
	$rv .= sprintf "<input type=radio name=ErrorLog_type value=2 %s>\n",
		$t == 2 ? "checked" : "";
	$rv .= "$text{'core_syslog'}<br>\n";
	$rv .= sprintf "<input type=radio name=ErrorLog_type value=0 %s>\n",
		$t == 0 ? "checked" : "";
	$rv .= sprintf "$text{'core_filelog'}<input name=ErrorLog_file size=25 value='%s'>\n",
		$t == 0 ? $v : "";
	$rv .= sprintf "<input type=radio name=ErrorLog_type value=1 %s>\n",
		$t == 1 ? "checked" : "";
	$rv .= sprintf "$text{'core_proglog'}<input name=ErrorLog_prog size=25 value='%s'><br>\n",
		$t == 1 ? substr($v, 1) : "";
	return (2, $text{'core_logto'}, $rv);
	}
}
sub save_ErrorLog
{
if ($_[0]->{'version'} < 1.3) {
	$in{'ErrorLog_def'} || &allowed_auth_file($in{'ErrorLog'}) ||
		&error($text{'core_edirlog'});
	$in{'ErrorLog_def'} || &directory_exists($in{'ErrorLog'}) ||
		    &error($text{'core_eerrordir'});
	return &parse_opt("ErrorLog", '^\S+$', $text{'core_efilelog'});
	}
else {
	if ($in{'ErrorLog_type'} == 3) {
		return ( [ ] );
		}
	elsif ($in{'ErrorLog_type'} == 0) {
		$in{'ErrorLog_file'} =~ /\S/ ||
		    &error($text{'core_efilemiss'});
		&allowed_auth_file($in{'ErrorLog_file'}) ||
		    &error($text{'core_edirlog'});
		&directory_exists($in{'ErrorLog_file'}) ||
		    &error($text{'core_eerrordir'});
		return ( [ $in{'ErrorLog_file'} ] );
		}
	elsif ($in{'ErrorLog_type'} == 1) {
		$in{'ErrorLog_prog'} =~ /\S/ ||
		    &error($text{'core_eprogmiss'});
		$access{'pipe'} ||
		    &error($text{'core_eperm'});
		return ( [ "\"|$in{'ErrorLog_prog'}\"" ] );
		}
	else {
		return ( [ "syslog" ] );
		}
	}
}

sub edit_LogLevel
{
return (1, $text{'core_loglevel'},
	&select_input($_[0]->{'value'}, "LogLevel", "",
		      "$text{'core_log_emerg'} (emerg),emerg",
		      "$text{'core_log_alert'} (alert),alert",
		      "$text{'core_log_crit'} (crit),crit",
		      "$text{'core_log_error'} (error),error",
		      "$text{'core_log_warn'} (warn),warn",
		      "$text{'core_log_notice'} (notice),notice",
		      "$text{'core_log_info'} (info),info",
		      "$text{'core_log_debug'} (debug),debug"));
}
sub save_LogLevel
{
return &parse_select("LogLevel", "");
}

#########################################################################
# Module directives
# This isn't shown if the distro has a way of managing these, such as Debian's
# /etc/apache/mods-enabled
sub edit_ClearModuleList_AddModule
{
local($mods, @allmods, $d, %mods, $m, $i, $rv);
local $httpd = &find_httpd();
($ver, $mods) = &httpd_info($httpd);
@allmods = grep { !/^core$/ } @$mods;
local $conf = &get_config();
foreach $d (&find_directive_struct("LoadModule", $conf)) {
	# Add mod_ like modules
	if ($d->{'words'}->[1] =~ /(mod_\S+)\.(so|dll)/) {
		push(@allmods, $1);
		}
	# nodo50 v0.1 - Change 000002 - Bug fixed: Apache-ssl module detected as mod_ssl. Now Apache-ssl module included as mod_apachessl
	# nodo50 v0.1 - Change 000002 - Bug corregido: El modulo Apache-ssl se detecta como mod_ssl. Ahora Apache-ssl se incluye como mod_apachessl
	# Add apache-ssl libssl.so as mod_apachessl module
	elsif ($d->{'words'}->[1] =~ /libssl\.so/) {
		push(@allmods, "mod_apachessl");
		}
	# Add others lib* like as mod_ modules
	# nodo50 v0.1 - Change 000002 - End
	elsif ($d->{'words'}->[1] =~ /lib([^\/\s]+)\.(so|dll)/) {
		push(@allmods, "mod_$1");
		}
	}

if (@{$_[0]}) {
	# Only selected modules have been enabled
	foreach $d (@{$_[1]}) {
		local $modc = $d->{'value'};
		$modc =~ s/\.c$//;
		$mods{$modc} = "checked";
		}
	}
else { foreach $m (@allmods) { $mods{$m} = "checked"; } }
$rv = &choice_input(@{$_[0]} ? 1 : 0, "ClearModuleList", 1,
		    "$text{'core_allmod'},0", "$text{'core_selmod'},1")."<br>\n";
$rv .= "<table>\n";
foreach $m (@allmods) {
	if ($i%4 == 0) { $rv .= "<tr>\n"; }
	$rv .= "<td><input name=AddModule type=checkbox value=$m $mods{$m}> $m</td>\n";
	if ($i++%4 == 3) { $rv .= "</tr>\n"; }
	}
$rv .= "</table>\n";
return (2, $text{'core_actmod'}, $rv);
}
sub save_ClearModuleList_AddModule
{
if ($in{'ClearModuleList'}) {
	local @mods = split(/\0/, $in{'AddModule'});
	return ( [ "" ], [ map { $_.".c" } @mods ] );
	}
else { return ( [ ], [ ] ); }
}

1;

