# ipsec-lib.pl
# Common functions for managing the freeswan config file
# XXX check for new errors in log after applying
# XXX option to download connection as .conf file, and upload an existing
#     .conf file for addition

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_config([file])
# Returns an array of configured connections
sub get_config
{
local $file = $_[0] || $config{'file'};
local (@rv, $sect);
local $lnum = 0;
local $fh = "CONF".$get_config_fh++;
open($fh, $file);
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*([^= ]+)\s*=\s*"([^"]*)"/ ||
	    /^\s*([^= ]+)\s*=\s*'([^"]*)'/ ||
	    /^\s*([^= ]+)\s*=\s*(\S+)/) {
		# Directive within a section
		if ($sect) {
			if ($sect->{'values'}->{lc($1)}) {
				$sect->{'values'}->{lc($1)} .= "\0".$2;
				}
			else {
				$sect->{'values'}->{lc($1)} = $2;
				}
			$sect->{'eline'} = $lnum;
			}
		}
	elsif (/^\s*include\s+(\S+)/) {
		# Including possibly multiple files
		local $inc = $1;
		if ($inc !~ /^\//) {
			$file =~ /^(.*)\//;
			$inc = "$1/$inc";
			}
		local $g;
		foreach $g (glob($inc)) {
			local @inc = &get_config($g);
			map { $_->{'index'} += scalar(@rv) } @inc;
			push(@rv, @inc);
			}
		}
	elsif (/^\s*(\S+)\s+(\S+)/) {
		# Start of a section
		$sect = { 'name' => $1,
			  'value' => $2,
			  'line' => $lnum,
			  'eline' => $lnum,
			  'file' => $file,
			  'index' => scalar(@rv),
			  'values' => { } };
		push(@rv, $sect);
		}
	$lnum++;
	}
close($fh);
return @rv;
}

# create_conn(&conn)
# Add a new connection to the config file
sub create_conn
{
local $lref = &read_file_lines($_[0]->{'file'} || $config{'file'});
push(@$lref, "", &conn_lines($_[0]));
&flush_file_lines();
}

# modify_conn(&conn)
sub modify_conn
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &conn_lines($_[0]));
&flush_file_lines();
}

# delete_conn(&conn)
sub delete_conn
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

# swap_conns(&conn1, &conn2)
# Swaps two connections in the config file
sub swap_conns
{
local ($first, $second) = @_;
if ($first->{'line'} > $second->{'line'}) {
	($first, $second) = ($second, $first);
	}
local $lref1 = &read_file_lines($first->{'file'});
local $lref2 = &read_file_lines($second->{'file'});
splice(@$lref2, $second->{'line'}, $second->{'eline'} - $second->{'line'} + 1,
       @$lref1[$first->{'line'} .. $first->{'eline'}]);
splice(@$lref2, $first->{'line'}, $first->{'eline'} - $first->{'line'} + 1,
       @$lref1[$second->{'line'} .. $second->{'eline'}]);
&flush_file_lines();
}

# conn_lines(&conn)
sub conn_lines
{
local @rv;
push(@rv, $_[0]->{'name'}." ".$_[0]->{'value'});
foreach $o (sort { $a cmp $b } keys %{$_[0]->{'values'}}) {
	local $v = $_[0]->{'values'}->{$o};
	local $vv;
	foreach $vv (split(/\0/, $v)) {
		if ($vv =~ /\s|=/) {
			push(@rv, "\t".$o."=\"".$vv."\"");
			}
		else {
			push(@rv, "\t".$o."=".$vv);
			}
		}
	}
return @rv;
}

# is_ipsec_running()
sub is_ipsec_running
{
local $out = `$config{'ipsec'} auto --status 2>&1`;
return $? || $out =~ /not running/i ? 0 : 1;
}

# get_public_key()
# Returns this system's public key
sub get_public_key
{
local $out = `$config{'ipsec'} showhostkey --file '$config{'secrets'}' --left 2>&1`;
if ($out =~ /leftrsasigkey=(\S+)/) {
	return $1;
	}
return undef;
}

# get_public_key_dns()
# Returns the flags, protocol, algorithm and key data for the public key,
# suitable for creating a DNS KEY record
sub get_public_key_dns
{
local $out = `$config{'ipsec'} showhostkey --file '$config{'secrets'}' 2>&1`;
if ($out =~ /KEY\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
	return ($1, $2, $3, $4);
	}
else {
	# Try with new --key argument
	$out = `$config{'ipsec'} showhostkey --key --file '$config{'secrets'}' 2>&1`;
	if ($out =~ /KEY\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
		return ($1, $2, $3, $4);
		}
	}
return ();
}

# list_policies()
# Returns a list of all policy files
sub list_policies
{
local ($f, @rv);
opendir(DIR, $config{'policies_dir'});
while($f = readdir(DIR)) {
	push(@rv, $f) if ($f !~ /^\./ && $f !~ /\.rpmsave$/);
	}
closedir(DIR);
return @rv;
}

# read_policy(name)
sub read_policy
{
local @rv;
open(FILE, "$config{'policies_dir'}/$_[0]");
while(<FILE>) {
	push(@rv, "$1/$2") if (/^\s*([0-9\.]+)\/(\d+)/);
	}
close(FILE);
return @rv;
}

# write_policy(name, &nets)
sub write_policy
{
local $lref = &read_file_lines("$config{'policies_dir'}/$_[0]");
local $l = 0;
foreach $p (@{$_[1]}) {
	while($l < @$lref && $lref->[$l] !~ /^\s*([0-9\.]+)\/(\d+)/) {
		$l++;
		}
	if ($l < @$lref) {
		# Found line to replace
		$lref->[$l] = $p;
		}
	else {
		# Add at end
		push(@$lref, $p);
		}
	$l++;
	}
while($l < @$lref) {
	if ($lref->[$l] =~ /^\s*([0-9\.]+)\/(\d+)/) {
		splice(@$lref, $l, 1);
		}
	else { $l++; }
	}
&flush_file_lines();
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
local $rest = $_[0];
local @rv;
while(length($rest) > $_[1]) {
	push(@rv, substr($rest, 0, $_[1]));
	$rest = substr($rest, $_[1]);
	}
push(@rv, $rest) if ($rest ne '');
return @rv;
}

# before_start()
# Work out which log file IPsec messages go to, and record the size
sub before_start
{
@ipsec_logfiles = ( $config{'logfile'} );
if (&foreign_check("syslog")) {
	# Find all syslog logfiles
	&foreign_require("syslog", "syslog-lib.pl");
	local $conf = &syslog::get_config();
	foreach $c (@$conf) {
		push(@ipsec_logfiles, $c->{'file'}) if ($c->{'file'} &&
							-f $c->{'file'});
		}
	}
@ipsec_logfiles = &unique(@ipsec_logfiles);
@ipsec_logfile_sizes = map { local @st = stat($_); $st[7] } @ipsec_logfiles;
}

# after_start()
# Check any new IPsec-related messages in the log for errors
sub after_start
{
# Give the server a chance to start
sleep(5);

# Look for new error messages
local $i;
for($i=0; $i<@ipsec_logfiles; $i++) {
	open(LOG, $ipsec_logfiles[$i]) || next;
	seek(LOG, $ipsec_logfile_sizes[$i], 0);
	while(<LOG>) {
		s/\r|\n//g;
		if (/ipsec/i && /error/i) {
			s/^(\S+)\s+(\d+)\s+(\d+:\d+:\d+)\s+(\S+)\s+//;
			push(@errs, $_);
			}
		}
	close(LOG);
	}

# Fail if there were any
if (@errs) {
	&error(&text('start_elog', "<p><tt>".join("<br>", @errs)."</tt><br>"));
	}
}

# get_ipsec_version(&out)
sub get_ipsec_version
{
local $out = `$config{'ipsec'} --version 2>&1`;
${$_[0]} = $out;
return $out =~ /(FreeS\/WAN|Openswan|StrongSWAN|Libreswan)\s+([^ \n\(]+)/i ? ($2,$1) : (undef);
}

# got_secret()
# Returns 1 if a valid secret key file exists, 0 if not
sub got_secret
{
local $gotkey;
open(SEC, $config{'secrets'}) || return 0;
while(<SEC>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/Modulus:\s*(\S+)/) {
		$gotkey = 1;
		}
	}
close(SEC);
return $gotkey;
}

# expand_conf(&config)
sub expand_conf
{
my $conf = shift;
for my $n (0..scalar(@$conf)-1) {
	$conn = @$conf[$n];
	foreach my $key (keys(%{$conn->{'values'}})) {
		$expanded{$conn->{'value'}}->{$key} = $conn->{'values'}->{$key};
		}
	}
# now go through and expand alsos
foreach my $k (keys(%expanded)) {
	$conn = \%{$expanded{$k}};
	# XXX - only supporing a single level of redirection
	#     - this should be moved into a function that could be called
	#       recursively
	if ($$conn{'also'}) {
		foreach my $also (split(/\000/, $$conn{'also'})) {
			foreach my $i (keys(%{$expanded{$also}})) {
				$$conn{$i} = $expanded{$also}{$i};
				}
			}
		# there is only one also key
		next;
		}
	}
return %expanded;
}

# restart_ipsec()
# Apply the current configuration, and return an error message on failure or
# undef on success
sub restart_ipsec
{
local $cmd = $config{'restart_cmd'} ||
       "($config{'stop_cmd'} && $config{'start_cmd'})";
&before_start();
local $out = &backquote_logged("$cmd 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
&after_start();
return undef;
}

# list_secrets()
# Returns a list of IPsec secret keys
sub list_secrets
{
if (!scalar(@list_secrets_cache)) {
	local (@lines);
	local $lnum = 0;
	open(SEC, $config{'secrets'});
	while(<SEC>) {
		s/\r|\n//g;
		s/^\s*#.*$//;
		if (/^(\S.*)$/) {
			push(@lines, { 'value' => $1,
				       'line' => $lnum,
				       'eline' => $lnum });
			}
		elsif (/^\s+(.*)/ && @lines) {
			$lines[$#rv]->{'value'} .= "\n".$1;
			$lines[$#rv]->{'eline'} = $lnum;
			}
		$lnum++;
		}
	close(SEC);

	# Turn joined lines into secrets
	local $l;
	foreach $l (@lines) {
		$l->{'value'} =~ /^([^:]*)\s*:\s+(\S+)\s+((.|\n)*)$/ || next;
		local $sec = { 'type' => $2,
			       'name' => $1,
			       'value' => $3,
			       'line' => $l->{'line'},
			       'eline' => $l->{'eline'},
			       'idx' => scalar(@list_secrets_cache),
			      };
		$sec->{'name'} =~ s/\n/ /g;
		$sec->{'name'} =~ s/\s+$//;
		push(@list_secrets_cache, $sec);
		}
	}
return @list_secrets_cache;
}

# delete_secret(&sec)
# Removes one secret from the file
sub delete_secret
{
local $lref = &read_file_lines($config{'secrets'});
local $lines = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $lines);
&flush_file_lines();
local $s;
splice(@list_secrets_cache, $_[0]->{'idx'}, 1);
foreach $s (@list_secrets_cache) {
	if ($s->{'line'} > $_[0]->{'line'}) {
		$s->{'line'} -= $lines;
		$s->{'eline'} -= $lines;
		}
	if ($s->{'idx'} > $_[0]->{'idx'}) {
		$s->{'idx'}--;
		}
	}
}

# create_secret(&sec)
# Add one secret to the file
sub create_secret
{
&list_secrets();	# force cache init
local $lref = &read_file_lines($config{'secrets'});
$_[0]->{'line'} = scalar(@$lref);
local @lines = &secret_lines($_[0]);
push(@$lref, @lines);
&flush_file_lines();
$_[0]->{'eline'} = scalar(@$lref)-1;
$_[0]->{'idx'} = scalar(@list_secrets_cache);
push(@list_secrets_cache, $_[0]);
}

# modify_secret(&sec)
# Update one secret in the file
sub modify_secret
{
local $lref = &read_file_lines($config{'secrets'});
local @newlines = &secret_lines($_[0]);
local $oldlines = $_[0]->{'eline'} - $_[0]->{'line'} + 1;
splice(@$lref, $_[0]->{'line'}, $oldlines, @newlines);
&flush_file_lines();
local $s;
foreach $s (@list_secrets_cache) {
	if ($s ne $_[0] && $s->{'line'} > $_[0]->{'line'}) {
		$s->{'line'} += @newlines - $oldlines;
		$s->{'eline'} += @newlines - $oldlines;
		}
	}
$_[0]->{'eline'} += @newlines - $oldlines;
}

sub secret_lines
{
local $str = $_[0]->{'name'} ? $_[0]->{'name'}." : " : ": ";
$str .= uc($_[0]->{'type'});
$str .= " ".$_[0]->{'value'};
return split(/\n/, $str);
}

@rsa_attribs = ( "Modulus", "PublicExponent", "PrivateExponent",
		 "Prime1", "Prime2", "Exponent1", "Exponent2", "Coefficient" );

1;

