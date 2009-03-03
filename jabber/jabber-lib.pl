# jabber-lib.pl
# Common functions for editing the jabber config files
#
# XXX - http://prdownloads.sourceforge.net/expat/expat-1.95.2-1.i686.rpm
#     - XML::Parser  XML::Generator
# XXX - admin <read> and <write> - what do they mean?

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

if ($config{'jabber_lib'}) {
	$ENV{$gconfig{'ld_env'}} .= ':' if ($ENV{$gconfig{'ld_env'}});
	$ENV{$gconfig{'ld_env'}} .= $config{'jabber_lib'};
	}

eval "use XML::Parser; \$got_xml_parser++";
eval "use XML::Generator; \$got_xml_generator++";

# get_jabber_config()
# Parse the jabber XML config file
sub get_jabber_config
{
return $get_jabber_config_cache if (defined($get_jabber_config_cache));
local $xml = new XML::Parser('Style' => 'Tree');
eval { $get_jabber_config_cache = $xml->parsefile($config{'jabber_config'}); };
if ($@) {
	return $@;
	}
return $get_jabber_config_cache;
}

# find(name, &config)
sub find
{
local (@rv, $i);
local $list = $_[1]->[1];
for($i=1; $i<@$list; $i+=2) {
	if (lc($list->[$i]) eq lc($_[0])) {
		push(@rv, [ $list->[$i], $list->[$i+1], $i ]);
		}
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = map { &value_in($_) } &find($_[0], $_[1]);
return wantarray ? @rv : $rv[0];
}

# jabber_pid_file()
# Returns the PID file used by jabber
sub jabber_pid_file
{
local $conf = &get_jabber_config();
local $pidfile = &find_value("pidfile", $conf);
if ($pidfile =~ /^\//) {
	return $pidfile;
	}
elsif ($pidfile) {
	return "$config{'jabber_dir'}/$pidfile";
	}
else {
	return "$config{'jabber_dir'}/jabber.pid";
	}
}

# value_in(&tag)
sub value_in
{
return undef if (!$_[0]);
local $zero = &find("0", $_[0]);
return $zero ? $zero->[1] : undef;
}

# generate_config(&tree, &gen)
# Returns an XML::Generator object created from a config tree structure
sub generate_config
{
local $gen = $_[1] ? $_[1] : XML::Generator->new(escape => 'always');
local $list = $_[0]->[1];
local (@mems, $i);
for($i=1; $i<@$list-1; $i+=2) {
	if ($list->[$i] eq '0') {
		push(@mems, $list->[$i+1]);
		}
	else {
		push(@mems, &generate_config(
				[ $list->[$i], $list->[$i+1] ], $gen));
		}
	}
local $name = $_[0]->[0];
return $gen->$name($list->[0], @mems);
}

# save_jabber_config(&config)
sub save_jabber_config
{
&open_tempfile(CONFIG, ">$config{'jabber_config'}");
local $xml = &generate_config($_[0]);
&print_tempfile(CONFIG, $xml);
&print_tempfile(CONFIG, "\n");
&close_tempfile(CONFIG);
}

# save_directive(&config, name|&old, &new)
# Replaces all directives of some name with new values
sub save_directive
{
local @ov = ref($_[1]) ? @{$_[1]} : &find($_[1], $_[0]);
local @nv = @{$_[2]};
local ($i, $j);
for($i=0; $i<@ov || $i<@nv; $i++) {
	local $idx = $ov[$i]->[2] if ($ov[$i]);
	if ($ov[$i] && $nv[$i]) {
		# Updating an existing value
		$_[0]->[1]->[$idx] = $nv[$i]->[0];
		$_[0]->[1]->[$idx+1] = $nv[$i]->[1];
		}
	elsif ($ov[$i]) {
		# Deleting an old value
		splice(@{$_[0]->[1]}, $idx, 2);
		map { $_->[2] -= 2 if ($_->[2] >= $idx) } @ov;
		}
	else {
		# Adding a new value after the last non-text one
		local $nt = -1;
		for($j=1; $j<@{$_[0]->[1]}; $j+=2) {
			$nt = $j if ($_[0]->[1]->[$j] ne '0');
			}
		splice(@{$_[0]->[1]}, $nt+2, 0, $nv[$i]->[0], $nv[$i]->[1]);
		}
	}
}

# find_by_tag(name, tag, value, &config)
sub find_by_tag
{
local @m = &find($_[0], $_[3]);
@m = grep { lc($_->[1]->[0]->{lc($_[1])}) eq lc($_[2]) } @m;
return wantarray ? @m : $m[0];
}

# xml_string(name, &tree, ...)
# Converts a list of XML structures into text
sub xml_string
{
local $rv = "";
for($i=0; $i<@_; $i+=2) {
	local $xml = &generate_config([ $_[$i], $_[$i+1] ]);
	if ($xml =~ /\S/) {
		$rv .= $xml."\n";
		}
	}
return $rv;
}

# get_jabberd_version(&out)
sub get_jabberd_version
{
local $jabberd = $config{'jabber_daemon'} ? $config{'jabber_daemon'}
				    : "$config{'jabber_dir'}/bin/jabberd";
local $out = `$jabberd -v 2>&1`;
${$_[0]} = $out;
return $out =~ /\s(1\.4\S*)/ ? $1 : undef;
}

# stop_jabber()
# Stops jabber, and returns undef on success or an error message on failure
sub stop_jabber
{
if ($config{'stop_cmd'}) {
        &system_logged("$config{'stop_cmd'} </dev/null >/dev/null 2>&1");
        }
else {
	local $pid = &check_pid_file(&jabber_pid_file());
	if ($pid) {
		&kill_logged('TERM', $pid) || return $!;
		}
	else {
		return $text{'stop_epid'};
		}
        }
unlink(&jabber_pid_file());
return undef;
}

# start_jabber()
# Starts jabber, and returns undef on success or an error message on failure
sub start_jabber
{
&system_logged("$config{'start_cmd'} </dev/null >/tmp/err 2>&1");
return undef;
}

@register_fields = ( 'name', 'email' );

@karma_presets = ( { 'heartbeat' => 2,	'init' => 10,
		     'max' => 10,	'inc' => 1,
		     'dec' => 1,	'penalty' => -6,
		     'restore' => 10 },
		   { 'heartbeat' => 2,	'init' => 50,
		     'max' => 50,	'inc' => 4,
		     'dec' => 1,	'penalty' => -5,
		     'restore' => 50 },
		   { 'heartbeat' => 2,	'init' => 64,
		     'max' => 64,	'inc' => 6,
		     'dec' => 1,	'penalty' => -3,
		     'restore' => 64 }
		  );

@filter_conds = ( "ns", "unavailable", "from", "resource", "subject", "body",
		  "show", "type", "roster", "group" );

@filter_acts =  ( "error", "offline", "forward", "reply", "continue",
		  "settype" );

1;

