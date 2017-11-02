# samba-lib.pl
# Common functions for editing the samba config file
# XXX privileges for groups with 'net' command

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$has_iconv = &has_command("iconv");

# Get the samba version
if (open(VERSION, "$module_config_directory/version")) {
	chop($samba_version = <VERSION>);
	close(VERSION);
	}

$has_pdbedit = ( $samba_version >= 3 && &has_command($config{'pdbedit'}) );
$has_smbgroupedit = 1 if (&has_command($config{'smbgroupedit'}));
$has_net = 1 if ($config{'net'} =~ /^(\S+)/ && &has_command("$1"));
$has_groups = ( $samba_version >= 3 && ($has_smbgroupedit || $has_net) );

# list_shares()
# List all the shares from the samba config file
sub list_shares
{
local(@rv, $_);
&open_readfile(SAMBA, $config{smb_conf});
while(<SAMBA>) {
	chop; s/;.*$//g; s/^\s*#.*$//g;
	if (/^\s*\[([^\]]+)\]/) {
		push(@rv, $1);
		}
	}
close(SAMBA);

# Check for an include directive in the [global] share
local %global;
&get_share("global", \%global);
local $inc = &getval("include", \%global);
if ($inc && $inc !~ /\%/) {
	# XXX
	}

return @rv;
}


# get_share(share, [array])
# Fills the associative array %share with the parameters from the given share
sub get_share
{
local($found, $_, $first, $arr);
$arr = (@_==2 ? $_[1] : "share");
undef(%$arr);
&open_readfile(SAMBA, $config{smb_conf});
while(<SAMBA>) {
	chop; s/^\s*;.*$//g; s/^\s*#.*$//g;
	if (/^\s*\[([^\]]+)\]/) {
		# Start of share section
		$first = 1;
		if ($found) {
			last;
			}
		elsif ($1 eq $_[0]) {
			$found = 1;
			$$arr{share_name} = $1;
			}
		}
	elsif ($found && /^\s*([^=]*\S)\s*=\s*(.*)$/) {
		# Directives inside a section
		if (lc($1) eq "read only") {
			# bastard special case.. change to writable
			$$arr{'writable'} = $2 =~ /yes|true|1/i ? "no" : "yes";
			}
		else {
			$$arr{lc($1)} = &from_utf8("$2");
			}
		}
	elsif (!$first && /^\s*([^=]*\S)\s*=\s*(.*)$/ && $_[0] eq "global") {
		# Directives outside a section! Assume to be part of [global]
		$$arr{share_name} = "global";
		$$arr{lc($1)} = &from_utf8("$2");
		$found = 1;
		}
	}
close(SAMBA);
return $found;
}


# create_share(name)
# Add an entry to the config file
sub create_share
{
&open_tempfile(CONF, ">> $config{smb_conf}");
&print_tempfile(CONF, "\n");
&print_tempfile(CONF, "[$_[0]]\n");
foreach $k (grep {!/share_name/} (keys %share)) {
	&print_tempfile(CONF, "\t$k = $share{$k}\n");
	}
&close_tempfile(CONF);
}


# modify_share(oldname, newname)
# Change a share (and maybe it's name)
sub modify_share
{
local($_, @conf, $replacing, $first);
&open_readfile(CONF, $config{smb_conf});
@conf = <CONF>;
close(CONF);
&open_tempfile(CONF, ">$config{smb_conf}");
for($i=0; $i<@conf; $i++) {
	chop($_ = $conf[$i]); s/;.*$//g; s/#.*$//g;
	if (/^\s*\[([^\]]+)\]/) {
		$first = 1;
		if ($replacing) { $replacing = 0; }
		elsif ($1 eq $_[0]) {
			&print_tempfile(CONF, "[$_[1]]\n");
			foreach $k (grep {!/share_name/} (keys %share)) {
				&print_tempfile(CONF, "\t$k = ",
					&to_utf8($share{$k}),"\n");
				}
			#&print_tempfile(CONF, "\n");
			$replacing = 1;
			}
		}
	elsif (!$first && /^\s*([^=]*\S)\s*=\s*(.*)$/ && $_[0] eq "global") {
		# found start of directives outside any share - assume [global]
		$first = 1;
		&print_tempfile(CONF, "[$_[1]]\n");
		foreach $k (grep {!/share_name/} (keys %share)) {
			&print_tempfile(CONF, "\t$k = ",
					      &to_utf8($share{$k}),"\n");
			}
		&print_tempfile(CONF, "\n");
		$replacing = 1;
		}
	if (!$replacing || $conf[$i] =~ /^\s*[#;]/ || $conf[$i] =~ /^\s*$/) {
		&print_tempfile(CONF, $conf[$i]);
		}
	}
&close_tempfile(CONF);
}


# delete_share(share)
# Delete some share from the config file
sub delete_share
{
local($_, @conf, $deleting);
&open_readfile(CONF, $config{smb_conf});
@conf = <CONF>;
close(CONF);
&open_tempfile(CONF, "> $config{smb_conf}");
for($i=0; $i<@conf; $i++) {
	chop($_ = $conf[$i]); s/;.*$//g;
	if (/^\s*\[([^\]]+)\]/) {
		if ($deleting) { $deleting = 0; }
		elsif ($1 eq $_[0]) {
			&print_tempfile(CONF, "\n");
			$deleting = 1;
			}
		}
	if (!$deleting) {
		&print_tempfile(CONF, $conf[$i]);
		}
	}
&close_tempfile(CONF);
}


# to_utf8(string)
# Converts a string to UTF-8 if needed
sub to_utf8
{
local ($v) = @_;
if ($v =~ /^[\000-\177]*$/ || !$has_iconv) {
	return $v;
	}
else {
	my $temp = &transname();
	&open_tempfile(TEMP, ">$temp", 0, 1);
	&print_tempfile(TEMP, $v);
	&close_tempfile(TEMP);
	my $out = &backquote_command("iconv -f iso-8859-1 -t UTF-8 <$temp");
	&unlink_file($temp);
	return $? || $out eq '' ? $v : $out;
	}
}

# from_utf8(string)
# Converts a string from UTF-8 if needed
sub from_utf8
{
local ($v) = @_;
if ($v =~ /^[\000-\177]*$/ || !$has_iconv) {
	return $v;
	}
else {
	my $temp = &transname();
	&open_tempfile(TEMP, ">$temp", 0, 1);
	&print_tempfile(TEMP, $v);
	&close_tempfile(TEMP);
	my $out = &backquote_command("iconv -f UTF-8 -t iso-8859-1 <$temp");
	&unlink_file($temp);
	return $? || $out eq '' ? $v : $out;
	}
}


# list_connections([share])
# Uses the smbstatus program to return a list of connections a share. Each
# element of the returned list is of the form:
#  share, user, group, pid, hostname, date/time
sub list_connections
{
local($l, $started, @rv);
if ($samba_version >= 3) {
	# New samba status format
	local %pidmap;
	local $out;
	local $ex = &execute_command("$config{samba_status_program} -s $config{smb_conf}", undef, \$out, undef);
	if ($ex) {
		# -s option not supported
		&execute_command("$config{samba_status_program}",
				 undef, \$out, undef);
		}
	foreach $l (split(/\n/ , $out)) {
		if ($l =~ /^----/) {
			$started++;
			}
		elsif ($started == 1 &&
		       $l =~ /^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\((\S+)\)/) {
			# A line with a PID, username, group and hostname
			$pidmap{$1} = [ $1, $2, $3, $4, $5 ];
			}
		elsif ($started == 2 &&
		       $l =~ /^\s*(\S+)\s+(\d+)\s+(\S+)\s+(.*)$/) {
			# A line with a service, PID and machine. This must be
			# combined data from the first type of line to create
			# the needed information
			local $p = $pidmap{$2};
			if (!$_[0] || $1 eq $_[0] ||
			    $1 eq $p->[1] && $_[0] eq "homes") {
				push(@rv, [ $1, $p->[1], $p->[2], $2, $3, $4 ]);
				}
			}
		}
	}
else {
	# Old samba status format
	local $out;
	&execute_command("$config{samba_status_program} -S",
			 undef, \$out, undef);
	foreach $l (split(/\n/, $out)) {
		if ($l =~ /^----/) { $started++; }
		if ($started && $l =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)\s+\(\S+\)\s+(.*)$/ && (!$_[0] || $1 eq $_[0] || $1 eq $2 && $_[0] eq "homes")) {
			push(@rv, [ $1, $2, $3, $4, $5, $6 ]);
			}
		}
	}
return @rv;
}

# list_locks()
# Returns a list of locked files as an array, in the form:
#  pid, mode, rw, oplock, file, date
sub list_locks
{
local($l, $started, @rv);
local $out;
&clean_language();
&execute_command("$config{samba_status_program} -L", undef, \$out, undef);
&reset_environment();
foreach $l (split(/\n/, $out)) {
	if ($l =~ /^----/) { $started = 1; }
	if ($started && $l =~ /^(\d+)\s+(\d+)\s+(\S+)\s+(0x\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S.*)\s\s((Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s.*)/i) {
		# New-style line
		push(@rv, [ $1, $3, $5, $6, $7.'/'.$8, $9 ]);
		}
	elsif ($started && $l =~ /^(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)\s+(\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+)/) {
		# Old-style line
		push(@rv, [ $1, $2, $3, $4, $5, $6 ]);
		}
	}
return @rv;
}


# istrue(key)
# Checks if the value of this key (or it's synonyms) in %share is true
sub istrue
{
return &getval($_[0]) =~ /yes|true|1/i;
}


# isfalse(key)
# Checks if the value of this key (or it's synonyms) in %share is false
sub isfalse
{
return &getval($_[0]) =~ /no|false|0/i;
}


# getval(name, [&hash])
# Given the name of a key in %share, return the value. Also looks for synonyms.
# If the value is not found, a default is looked for.. this can come from
# a copied section, the [global] configuration section, or from the SAMBA
# defaults. This means that getval() always returns something..
sub getval
{
local $hash = $_[1] || \%share;
local($_, $copy);
if ($synon{$_[0]}) {
	foreach (split(/,/, $synon{$_[0]})) {
		if (defined($hash->{$_})) { return $hash->{$_}; }
		}
	}
if (defined($hash->{$_[0]})) {
	return $hash->{$_[0]};
	}
elsif ($_[0] ne "copy" && ($copy = $hash->{"copy"})) {
	# this share is a copy.. get the value from the source
	local(%share);
	&get_share($copy);
	return &getval($_[0]);
	}
else {
	# return the default value...
	return &default_value($_[0]);
	}
return undef;
}


# setval(name, value, [default])
# Sets some value in %share. Synonyms with the same meaning are removed.
# If the value is the same as the share or given default, don't store it
sub setval
{
local($_);
if (@_ == 3) {
	# default was given..
	$def = $_[2];
	}
elsif ($_[0] ne "copy" && ($copy = $share{"copy"})) {
	# get value from copy source..
	local(%share);
	&get_share($copy);
	$def = &getval($_[0]);
	}
else {
	# get global/samba default
	$def = &default_value($_[0]);
	}
if ($_[1] eq $def || ($def !~ /\S/ && $_[1] !~ /\S/) ||
    ($def =~ /^(true|yes|1)$/i && $_[1] =~ /^(true|yes|1)$/i) ||
    ($def =~ /^(false|no|0)$/i && $_[1] =~ /^(false|no|0)$/i)) {
	# The value is the default.. delete this entry
	&delval($_[0]);
	}
else {
	if ($synon{$_[0]}) {
		foreach (split(/,/, $synon{$_[0]})) {
			delete($share{$_});
			}
		}
	$share{$_[0]} = $_[1];
	}
}


# delval(name)
# Delete a value from %share (and it's synonyms)
sub delval
{
local($_);
if ($synon{$_[0]}) {
	foreach (split(/,/, $synon{$_[0]})) {
		delete($share{$_});
		}
	}
else { delete($share{$_[0]}); }
}


# default_value(name)
# Returns the default value for a parameter
sub default_value
{
local($_, %global);

# First look in the [global] section.. (unless this _is_ the global section)
if ($share{share_name} ne "global") {
	&get_share("global", "global");
	if ($synon{$_[0]}) {
		foreach (split(/,/, $synon{$_[0]})) {
			if (defined($global{$_})) { return $global{$_}; }
			}
		}
	if (defined($global{$_[0]})) { return $global{$_[0]}; }
	}

# Else look in the samba defaults
if ($synon{$_[0]}) {
	foreach (split(/,/, $synon{$_[0]})) {
		if (exists($default_values{$_})) {
			return $default_values{$_};
			}
		}
	}
return $default_values{$_[0]};
}


# The list of synonyms used by samba for parameter names
@synon = (	"writeable,write ok,writable",
		"public,guest ok",
		"printable,print ok",
		"allow hosts,hosts allow",
		"deny hosts,hosts deny",
		"create mode,create mask",
		"directory mode,directory mask",
		"path,directory",
		"exec,preexec",
		"group,force group",
		"only guest,guest only",
		"user,username,users",
		"default,default service",
		"auto services,preload",
		"lock directory,lock dir",
		"max xmit,max packet",
		"root directory,root dir,root",
		"case sensitive,case sig names",
		"idmap uid,winbind uid",
		"idmap gid,winbind gid",
	 );
foreach $s (@synon) {
	foreach $ss (split(/,/ , $s)) {
		$synon{$ss} = $s;
		}
	}


# Default values for samba configuration parameters
%default_values = (	"allow hosts",undef,
			"alternate permissions","no",
			"available","yes",
			"browseable","yes",
			"comment",undef,
			"create","yes",
			"create mode","755",
			"directory mode","755",
			"default case","lower",
			"case sensitive","no",
			"mangle case","no",
			"preserve case","yes",
			"short preserve case","yes",
			"delete readonly","no",
			"deny hosts",undef,
			"dont descend",undef,
			"force group",undef,
			"force user",undef,
			"force create mode","000",
			"force directory mode","000",
			"guest account","nobody",	# depends
			"guest only","no",
			"hide dot files","yes",
			"invalid users",undef,
			"locking","yes",
			"lppause command",undef,	# depends
			"lpq command",undef,		# depends
			"lpresume command",undef,	# depends
			"lprm command",undef,		#depends
			"magic output",undef,		# odd..
			"magic script",undef,
			"mangled map",undef,
			"mangled names","yes",
			"mangling char","~",
			"map archive","yes",
			"map system","no",
			"map hidden","no",
			"max connections",0,
			"only user","no",
			"fake oplocks","no",
			"oplocks","yes",
			"os level",20,
			"level2 oplocks","no",
			"load printers","yes",
			"min print space",0,
			"path",undef,
			"postscript","no",
			"preexec",undef,
			"print command",undef,
#			"print command","lpr -r -P %p %s",
			"printer",undef,
			"printer driver",undef,
			"public","no",
			"read list",undef,
			"revalidate","no",
			"root preexec",undef,
			"root postexec",undef,
			"set directory","no",
			"share modes","yes",
			"socket options","TCP_NODELAY",
			"strict locking","no",
			"sync always","no",
			"unix password sync","no",
			"user",undef,
			"valid chars",undef,
			"volume",undef,		# depends
			"wide links","yes",
			"wins support","no",
			"writable","no",
			"write list",undef,
			"winbind cache time",300,
			"winbind enable local accounts","yes",
			"winbind trusted domains only","no",
			"winbind enum users","yes",
			"winbind enum groups","yes",
		);
$default_values{'encrypt passwords'} = 'yes' if ($samba_version >= 3);

# user_list(list)
# Convert a samba unix user list into a more readable form
sub user_list
{
local($u, @rv);
foreach $u (split(/[ \t,]+/ , $_[0])) {
	if ($u =~ /^\@(.*)$/) {
		push(@rv, "group <tt>".&html_escape($1)."</tt>");
		}
	else {
		push(@rv, "<tt>".&html_escape($u)."</tt>");
		}
	}
return join("," , @rv);
}


# yesno_input(config-name, [input-name])
# Returns a true / false selector
sub yesno_input
{
local ($c, $n) = @_;
if (!$n) {
	($n = $c) =~ s/ /_/g;
	}
return &ui_radio($n, &istrue($c) ? "yes" : "no",
		 [ [ "yes", $text{'yes'} ],
		   [ "no", $text{'no'} ] ]);
}

# username_input(name)
# Outputs HTML for an username field
sub username_input
{
local $n;
($n = $_[0]) =~ s/ /_/g;
return &ui_user_textbox($n, &getval($_[0]));
}

# username_input(name, default)
sub groupname_input
{
local $n;
($n = $_[0]) =~ s/ /_/g;
return &ui_group_textbox($n, &getval($_[0]));
}

@sock_opts = ("SO_KEEPALIVE", "SO_REUSEADDR", "SO_BROADCAST", "TCP_NODELAY",
	      "IPTOS_LOWDELAY", "IPTOS_THROUGHPUT", "SO_SNDBUF*", "SO_RCVBUF*",
	      "SO_SNDLOWAT*", "SO_RCVLOWAT*");

@protocols = ("CORE", "COREPLUS", "LANMAN1", "LANMAN2", "NT1");


# list_users()
# Returns an array of all the users from the samba password file
sub list_users
{
local(@rv, @b, $_, $lnum);
if ($has_pdbedit) {
	# Get list of users from the pdbedit command, which uses a configurable
	# back-end for storage
	&open_execute_command(PASS, "cd / && $config{'pdbedit'} -L -w -s $config{'smb_conf'}", 1);
	}
else {
	# Read the password file directly
	&open_readfile(PASS, $config{'smb_passwd'});
	}
while(<PASS>) {
	$lnum++;
	chop;
	s/#.*$//g;
	local @b = split(/:/, $_);
	next if (@b < 4 || $b[1] !~ /^\d+$/);
	local $u = { 'name' => $b[0],  'uid' => $b[1],
		     'pass1' => $b[2], 'pass2' => $b[3],
		     'oldname' => $b[0] };
	if ($samba_version >= 2 && $b[4] =~ /^\[/) {
		$b[4] =~ s/[\[\] ]//g;
		$u->{'opts'} = [ split(//, $b[4]) ];
		$u->{'change'} = $b[5];
		}
	else {
		$u->{'real'} = $b[4];
		$u->{'home'} = $b[5];
		$u->{'shell'} = $b[6];
		}
	$u->{'index'} = scalar(@rv);
	$u->{'line'} = $lnum-1;
	push(@rv, $u);
	}
close(PASS);
return @rv;
}

# smbpasswd_cmd(args)
# Returns the full smbpasswd command with extra args
sub smbpasswd_cmd
{
my ($args) = @_;
return $config{'samba_password_program'}.
       ($samba_version >= 3 ? " -c " : " -s ").
       $config{'smb_conf'}." ".$args;
}

# create_user(&user)
# Add a user to the samba password file
sub create_user
{
if ($has_pdbedit) {
	# Use the pdbedit command
	local $ws = &indexof("W", @{$_[0]->{'opts'}}) >= 0 ? "-m" : "";
	local @opts = grep { $_ ne "U" && $_ ne "W" } @{$_[0]->{'opts'}};
	local $temp = &transname();
	&open_tempfile(TEMP, ">$temp", 0, 1);
	&print_tempfile(TEMP, "\n\n");
	&close_tempfile(TEMP);
	local $out = &backquote_logged(
		"cd / && $config{'pdbedit'} -a -s $config{'smb_conf'} -t -u ".
		quotemeta($_[0]->{'name'}).
		($config{'sync_gid'} ? " -G $config{'sync_gid'}" : "").
		" -c '[".join("", @opts)."]' $ws <$temp 2>&1");
	$? && &error("$config{'pdbedit'} failed : <pre>$out</pre>");
	}
else {
	# Try using smbpasswd -a
	local $out = &backquote_logged(
		"cd / && ".&smbpasswd_cmd(
		  "-a ".
		  (&indexof("D", @{$_[0]->{'opts'}}) >= 0 ? "-d " : "").
		  (&indexof("N", @{$_[0]->{'opts'}}) >= 0 ? "-n " : "").
		  (&indexof("W", @{$_[0]->{'opts'}}) >= 0 ? "-m " : "").
		  quotemeta($_[0]->{'name'})));
	if ($?) {
		# Add direct to Samba password file
		&open_tempfile(PASS, ">>$config{'smb_passwd'}");
		&print_tempfile(PASS, &user_string($_[0]));
		&close_tempfile(PASS);
		chown(0, 0, $config{'smb_passwd'});
		chmod(0600, $config{'smb_passwd'});
		}
	}
}

# modify_user(&user)
# Change an existing samba user
sub modify_user
{
if ($has_pdbedit) {
	# Use the pdbedit command
	if ($_[0]->{'oldname'} ne "" && $_[0]->{'oldname'} ne $_[0]->{'name'}) {
		# Username changed! Have to delete and re-create
		local $out = &backquote_logged(
		    "cd / && $config{'pdbedit'} -x -s $config{'smb_conf'} -u ".
		    quotemeta($_[0]->{'oldname'}));
		$? && &error("$config{'pdbedit'} failed : <pre>$out</pre>");
		&create_user($_[0]);
		}
	else {
		# Just update user
		local @opts = grep { $_ ne "U" } @{$_[0]->{'opts'}};
		&indexof("W", @{$_[0]->{'opts'}}) >= 0 && &error($text{'saveuser_ews'});
		$out = &backquote_logged(
			"cd / && $config{'pdbedit'} -r -s $config{'smb_conf'} -u ".
			quotemeta($_[0]->{'name'}).
			" -c '[".join("", @opts)."]' 2>&1");
		$? && &error("$config{'pdbedit'} failed : <pre>$out</pre>");
		}
	}
else {
	if (!$_[0]->{'oldname'} || $_[0]->{'oldname'} eq $_[0]->{'name'}) {
		# Try using smbpasswd command
		local $out = &backquote_logged(
			"cd / && ".&smbpasswd_cmd(
			  (&indexof("D", @{$_[0]->{'opts'}}) >= 0 ? "-d "
			  					  : "-e ").
			  quotemeta($_[0]->{'name'})));
		}

	# Also directly update the Samba password file
	&replace_file_line($config{'smb_passwd'}, $_[0]->{'line'},
			   &user_string($_[0]));
	}
}

# delete_user(&user)
# Delete a samba user
sub delete_user
{
if ($has_pdbedit) {
	# Use the pdbedit command
	local $out = &backquote_logged(
		"cd / && $config{'pdbedit'} -x -s $config{'smb_conf'} -u ".
		quotemeta($_[0]->{'name'}));
	$? && &error("$config{'pdbedit'} failed : <pre>$out</pre>");
	}
else {
	# Try the smbpasswd command
	local $out = &backquote_logged(
		"cd / && ".&smbpasswd_cmd("-x ".quotemeta($_[0]->{'name'})));
	if ($?) {
		# Just remove from the Samba password file
		&replace_file_line($config{'smb_passwd'}, $_[0]->{'line'});
		}
	}
}

sub user_string
{
local @u = ($_[0]->{'name'}, $_[0]->{'uid'},
	    $_[0]->{'pass1'}, $_[0]->{'pass2'});
if ($_[0]->{'opts'}) {
	push(@u, sprintf "[%-11s]", join("", @{$_[0]->{'opts'}}));
	push(@u, sprintf "LCT-%X", time());
	push(@u, "");
	}
else {
	push(@u, $_[0]->{'real'}, $_[0]->{'home'}, $_[0]->{'shell'});
	}
return join(":", @u)."\n";
}

# set_password(user, password, [&output])
# Changes the password of a user in the encrypted password file
sub set_password
{
local $qu = quotemeta($_[0]);
local $qp = quotemeta($_[1]);
if ($samba_version >= 2) {
	local $passin = "$_[1]\n$_[1]\n";
	local $ex = &execute_command(
		&smbpasswd_cmd("-s $qu"), \$passin, $_[2], $_[2]);
	unlink($temp);
	return !$rv;
	}
else {
	local $out;
	&execute_command("$config{'samba_password_program'} $qu $qp",
			 undef, $_[2], $_[2]);
	return $out =~ /changed/i;
	}
}

# is_samba_running()
# Returns 0 if not, 1 if it is, or 2 if run from (x)inetd
sub is_samba_running
{
local ($found_inet, @smbpids, @nmbpids);
if (&foreign_check("inetd")) {
	&foreign_require("inetd", "inetd-lib.pl");
	foreach $inet (&foreign_call("inetd", "list_inets")) {
		$found_inet++ if (($inet->[8] =~ /smbd/ ||
				   $inet->[9] =~ /smbd/) && $inet->[1]);
		}
	}
elsif (&foreign_check("xinetd")) {
	&foreign_require("xinetd", "xinetd-lib.pl");
	foreach $xi (&foreign_call("xinetd", "get_xinetd_config")) {
		local $q = $xi->{'quick'};
		$found_inet++ if ($q->{'disable'}->[0] ne 'yes' &&
				  $q->{'server'}->[0] =~ /smbd/);
		}
	}
@smbpids = &find_byname("smbd");
@nmbpids = &find_byname("nmbd");
return !$found_inet && !@smbpids && !@nmbpids ? 0 :
       !$found_inet ? 1 : 2;
}

# is_winbind_running()
# Returns 0 if not, 1 if it is
sub is_winbind_running
{
local (@wbpids);
@wbpids = &find_byname("winbindd");
return !@wbpids ? 0 : 1;
}

# can($permissions_string, \%access, [$sname])
# check global and per-share permissions:
#
# $permissions_string = any exists permissions except 'c' (creation).
# \%access = ref on what get_module_acl() returns.
sub can
{
local ($acl, $stype, @perm);
local ($perm, $acc, $sname) = @_;
@perm  = split(//, $perm);
$sname = $in{'old_name'} || $in{'share'} unless $sname;

{	local %share;
	&get_share($sname); # use local %share
	$stype = &istrue('printable') ? 'ps' : 'fs';
	}

# check global acl (r,w)
foreach (@perm) {
	next if ($_ ne 'r') && ($_ ne 'w');
	return 0 unless $acc->{$_ . '_' . $stype};
	}

# check per-share acl
if ($acc->{'per_' . $stype . '_acls'}) {
    $acl = $acc->{'ACL' . $stype . '_' . $sname};
    foreach (@perm) {
#        next if $_ eq 'c'; # skip creation perms for per-share acls
		return 0 if index($acl, $_) == -1;
		}
	}
return 1;
}

# save_samba_acl($permissions_string, \%access, $share_name)
sub save_samba_acl
{
local ($p, $a, $s)=@_;
%share || &get_share($s); # use global %share
local $t=&istrue('printable') ? 'ps' : 'fs';
$a->{'ACL'. $t .'_'. $s} = $p;
#undef($can_cache);
return &save_module_acl($a);
}

# drop_samba_acl(\%access, $share_name)
sub drop_samba_acl
{
local ($a, $s)=@_;
%share || &get_share($s); # use global %share
local $t=&istrue('printable') ? 'ps' : 'fs';
delete($a->{'ACL'. $t .'_' . $s});
#undef($can_cache);
return &save_module_acl($a);
}

# list_groups()
# Returns an array containing details of Samba groups
sub list_groups
{
local (@rv, $group, $cmd);
if ($has_smbgroupedit) {
	$cmd = "$config{'smbgroupedit'} -v -l";
	}
else {
	$cmd = "$config{'net'} -s $config{'smb_conf'} groupmap list verbose";
	}
&open_execute_command(GROUPS, $cmd, 1);
while(<GROUPS>) {
	s/\r|\n//g;
	if (/^(\S.*)/) {
		$group = { 'name' => $1,
			   'index' => scalar(@rv) };
		push(@rv, $group);
		}
	elsif (/^\s+SID\s*:\s+(.*)/i) {
		$group->{'sid'} = $1;
		}
	elsif (/^\s+Unix group\s*:\s*(.*)/i) {
		$group->{'unix'} = $1;
		}
	elsif (/^\s+Group type\s*:\s*(.*)/i) {
		$group->{'type'} = lc($1) eq 'domain group' ? 'd' :
				   lc($1) eq 'nt builtin' ? 'b' :
				   lc($1) eq 'unknown type' ? 'u' :
				   lc($1) eq 'local group' ? 'l' : $1;
		}
	elsif (/^\s+Comment\s*:\s*(.*)/i) {
		$group->{'desc'} = $1;
		}
	elsif (/^\s+Privilege\s*:\s*(.*)/i) {
		$group->{'priv'} = lc($1) eq 'no privilege' ? undef : $1;
		}
	}
close(GROUPS);
return @rv;
}

# delete_group(&group)
# Delete an existing Samba group
sub delete_group
{
local $out;
if ($has_smbgroupedit) {
	$out = &backquote_logged("$config{'smbgroupedit'} -x ".quotemeta($_[0]->{'name'})." 2>&1");
	$? && &error("$config{'smbgroupedit'} failed : <pre>$out</pre>");
	}
else {
	$out = &backquote_logged("$config{'net'} -s $config{'smb_conf'} groupmap delete ntgroup=".quotemeta($_[0]->{'name'})." 2>&1");
	$? && &error("$config{'net'} failed : <pre>$out</pre>");
	}
}

# modify_group(&group)
# Update the details of an existing Samba group
sub modify_group
{
local $out;
if ($has_smbgroupedit) {
	$out = &backquote_logged(
		$config{'smbgroupedit'}.
		" -c ".quotemeta($_[0]->{'sid'}).
		($_[0]->{'unix'} == -1 ? "" :" -u ".quotemeta($_[0]->{'unix'})).
		($_[0]->{'desc'} ? " -d ".quotemeta($_[0]->{'desc'}) :" -d ''").
		" -t ".$_[0]->{'type'}.
		" 2>&1");
	$? && &error("$config{'smbgroupedit'} failed : <pre>$out</pre>");
	}
else {
	$out = &backquote_logged(
		"$config{'net'} -s $config{'smb_conf'} groupmap modify".
		" sid=".quotemeta($_[0]->{'sid'}).
		($_[0]->{'unix'} == -1 ? "" :
				" unixgroup=".quotemeta($_[0]->{'unix'})).
		($_[0]->{'desc'} ? " comment=".quotemeta($_[0]->{'desc'})
				 : " 'comment= '").
		" type=".quotemeta($_[0]->{'type'})." 2>&1");
	$? && &error("$config{'net'} failed : <pre>$out</pre>");
	}
}

# create_group(&group)
# Add a Samba new group
sub create_group
{
local $out;
if ($has_smbgroupedit) {
	$out = &backquote_logged(
		$config{'smbgroupedit'}.
		" -a ".quotemeta($_[0]->{'unix'}).
		" -n ".quotemeta($_[0]->{'name'}).
		($_[0]->{'priv'} ? " -p ".quotemeta($_[0]->{'priv'}) : "").
		($_[0]->{'desc'} ? " -d ".quotemeta($_[0]->{'desc'}) :" -d ''").
		" -t ".$_[0]->{'type'}." 2>&1");
	$? && &error("$config{'smbgroupedit'} failed : <pre>$out</pre>");
	}
else {
	$out = &backquote_logged("$config{'net'} -s $config{'smb_conf'} maxrid 2>&1");
	local $maxrid = $out =~ /rid:\s+(\d+)/ ? $1 + 1 : undef;
	$maxrid = 1000 if ($maxrid < 1000);	# Should be >1000
	if (&foreign_check("useradmin")) {
		&foreign_require("useradmin");
		local %taken;
		&useradmin::build_user_used(\%taken);
		while($taken{$maxrid}) {
			$maxrid++;
			}
		}
	$out = &backquote_logged(
		"$config{'net'} -s $config{'smb_conf'} groupmap add".
		" rid=$maxrid".
		" unixgroup=".quotemeta($_[0]->{'unix'}).
		" ntgroup=".quotemeta($_[0]->{'name'}).
		" type=".quotemeta($_[0]->{'type'})." 2>&1");
	$? && &error("<pre>$out</pre>");
	$out = &backquote_logged(
		"$config{'net'} groupmap modify".
		" ntgroup=".quotemeta($_[0]->{'name'}).
		($_[0]->{'desc'} ? " comment=".quotemeta($_[0]->{'desc'})
				 : " 'comment= '").
		" type=".quotemeta($_[0]->{'type'})." 2>&1");
	$? && &error("$config{'net'} failed : <pre>$out</pre>");
	}
}

# get_samba_version(&out, [keep-original-format])
# Returns the Samba version
sub get_samba_version
{
local $flag;
foreach $flag ("-V", "-v") {
	&execute_command("$config{'samba_server'} $flag", undef, $_[0], $_[0]);
	if (${$_[0]} =~ /(Version|Samba)\s+(CVS\s+)?[^0-9 ]*(\d+)\.(\S+)/i) {
		local $v1 = $3;
		local $v2 = $4;
		if (!$_[1]) {
			$v2 =~ s/[^0-9]//g;
			}
		return "$v1.$v2";
		}
	}
return undef;
}

sub check_user_enabled
{
local %share;
&get_share("global");
if (!&istrue("encrypt passwords")) {
	$err = &text('check_user1', $_[0], "conf_pass.cgi");
	}
elsif (!$config{'smb_passwd'} && !$has_pdbedit) {
	$err = &text('check_user2', $_[0], "../config.cgi?$module_name");
	}
if ($err) {
	print "<p>$err<p>\n";
	print "<hr>\n";
	&footer("", $text{'index_sharelist'});
	exit;
	}
}

sub check_group_enabled
{
if ($samba_version < 3) {
	$err = &text('check_groups1', $_[0]);
	}
elsif (!$has_groups) {
	$err = &text('check_groups2', $_[0], "../config.cgi?$module_name");
	}
if ($err) {
	print "<p>$err<p>\n";
	print "<hr>\n";
	&footer("", $text{'index_sharelist'});
	exit;
	}
}

1;

