# bind8-lib.pl
# Common functions for bind8 config files

BEGIN { push(@INC, ".."); };
use WebminCore;
my $dnssec_tools_minver = 1.13;
my $have_dnssec_tools = eval "require Net::DNS::SEC::Tools::dnssectools;";

if ($have_dnssec_tools) {
	eval "use Net::DNS::SEC::Tools::dnssectools;
	      use Net::DNS::SEC::Tools::rollmgr;
	      use Net::DNS::SEC::Tools::rollrec;
	      use Net::DNS::SEC::Tools::keyrec;
	      use Net::DNS;";
	}

&init_config();
do 'records-lib.pl';
@extra_forward = split(/\s+/, $config{'extra_forward'});
@extra_reverse = split(/\s+/, $config{'extra_reverse'});
%is_extra = map { $_, 1 } (@extra_forward, @extra_reverse);
%access = &get_module_acl();
$zone_names_cache = "$module_config_directory/zone-names";
$zone_names_version = 3;

# Where to find root zones file
$internic_ftp_host = "rs.internic.net";
$internic_ftp_ip = "198.41.0.6";
$internic_ftp_file = "/domain/named.root";
$internic_ftp_gzip = "/domain/root.zone.gz";

# Get the version number
if (open(VERSION, "$module_config_directory/version")) {
	chop($bind_version = <VERSION>);
	close(VERSION);
	}
else {
	$bind_version = &get_bind_version();
	}

$dnssec_cron_cmd = "$module_config_directory/resign.pl";

# For automatic DLV setup
$dnssec_dlv_zone = "dlv.isc.org.";
@dnssec_dlv_key = ( 257, 3, 5, '"BEAAAAPHMu/5onzrEE7z1egmhg/WPO0+juoZrW3euWEn4MxDCE1+lLy2brhQv5rN32RKtMzX6Mj70jdzeND4XknW58dnJNPCxn8+jAGl2FZLK8t+1uq4W+nnA3qO2+DL+k6BD4mewMLbIYFwe0PG73Te9fZ2kJb56dhgMde5ymX4BI/oQ+cAK50/xvJv00Frf8kw6ucMTwFlgPe+jnGxPPEmHAte/URkY62ZfkLoBAADLHQ9IrS2tryAe7mbBZVcOwIeU/Rw/mRx/vwwMCTgNboMQKtUdvNXDrYJDSHZws3xiRXF1Rf+al9UmZfSav/4NWLKjHzpT59k/VStTDN0YUuWrBNh"' );

if ($gconfig{'os_type'} =~ /-linux$/ && -r "/dev/urandom") {
	$rand_flag = "-r /dev/urandom";
	}

# have_dnssec_tools_support()
# Returns 1 if dnssec-tools support is available and we meet minimum version
sub have_dnssec_tools_support
{
	if ($have_dnssec_tools &&
	    $Net::DNS::SEC::Tools::rollrec::VERSION >= $dnssec_tools_minver) {
		# check that the location for the following essential
		# parameters have been defined :
		# dnssectools_conf
		# dnssectools_rollrec
		# dnssectools_keydir
		# dnssectools_rollmgr_pidfile
		return undef if (!$config{'dnssectools_conf'} ||
				 !$config{'dnssectools_rollrec'} ||
				 !$config{'dnssectools_keydir'} ||
				 !$config{'dnssectools_rollmgr_pidfile'});
		return 1;
	}
	return undef;
}

# get_bind_version()
# Returns the BIND verison number, or undef if unknown
sub get_bind_version
{
my $out = `$config{'named_path'} -v 2>&1`;
if ($out =~ /(bind|named)\s+([0-9\.]+)/i) {
	return $2;
	}
return undef;
}

# get_config()
# Returns an array of references to assocs, each containing the details of
# one directive
sub get_config
{
if (!@get_config_cache) {
	@get_config_cache = &read_config_file($config{'named_conf'});
	}
return \@get_config_cache;
}

# get_config_parent([file])
# Returns a structure containing the top-level config as members
sub get_config_parent
{
local $file = $_[0] || $config{'named_conf'};
if (!defined($get_config_parent_cache{$file})) {
	local $conf = &get_config();
	if (!defined($lines_count{$file})) {
		local $lref = &read_file_lines($file);
		$lines_count{$file} = @$lref;
		}
	$get_config_parent_cache{$file} =
	       { 'file' => $file,
		 'type' => 1,
		 'line' => -1,
		 'eline' => $lines_count{$file},
		 'members' => $conf };
	}
return $get_config_parent_cache{$file};
}

# read_config_file(file, [expand includes])
# Reads a config file and returns an array of values
sub read_config_file
{
local($lnum, $line, $cmode, @ltok, @lnum, @tok,
      @rv, $i, $t, $j, $ifile, @inc, $str);
$lnum = 0;
open(FILE, &make_chroot($_[0]));
while($line = <FILE>) {
	# strip comments
	$line =~ s/\r|\n//g;
	$line =~ s/#.*$//g;
	$line =~ s/\/\*.*\*\///g;
	$line =~ s/\/\/.*$//g if ($line !~ /".*\/\/.*"/);
	while(1) {
		if (!$cmode && $line =~ /\/\*/) {
			# start of a C-style comment
			$cmode = 1;
			$line =~ s/\/\*.*$//g;
			}
		elsif ($cmode) {
			if ($line =~ /\*\//) {
				# end of comment
				$cmode = 0;
				$line =~ s/^.*\*\///g;
				}
			else { $line = ""; last; }
			}
		else { last; }
		}

	# split line into tokens
	undef(@ltok);
	while(1) {
		if ($line =~ /^\s*\"([^"]*)"(.*)$/) {
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*([{};])(.*)$/) {
			push(@ltok, $1); $line = $2;
			}
		elsif ($line =~ /^\s*([^{}; \t]+)(.*)$/) {
			push(@ltok, $1); $line = $2;
			}
		else { last; }
		}
	foreach $t (@ltok) {
		push(@tok, $t); push(@lnum, $lnum);
		}
	$lnum++;
	}
close(FILE);
$lines_count{$_[0]} = $lnum;

# parse tokens into data structures
$i = 0; $j = 0;
while($i < @tok) {
	$str = &parse_struct(\@tok, \@lnum, \$i, $j++, $_[0]);
	if ($str) { push(@rv, $str); }
	}
if (!@rv) {
	# Add one dummy directive, so that the file is known
	push(@rv, { 'name' => 'dummy',
		    'line' => 0,
		    'eline' => 0,
		    'index' => 0,
		    'file' => $_[0] });
	}

if (!$_[1]) {
	# expand include directives
	while(&recursive_includes(\@rv, &base_directory(\@rv))) {
		# This is done repeatedly to handle includes within includes
		}
	}

return @rv;
}

# recursive_includes(&dirs, base)
sub recursive_includes
{
local ($i, $j);
local $any = 0;
for($i=0; $i<@{$_[0]}; $i++) {
	if (lc($_[0]->[$i]->{'name'}) eq "include") {
		# found one.. replace the include directive with it
		$ifile = $_[0]->[$i]->{'value'};
		if ($ifile !~ /^\//) {
			$ifile = "$_[1]/$ifile";
			}
		local @inc = &read_config_file($ifile, 1);

		# update index of included structures
		local $j;
		for($j=0; $j<@inc; $j++) {
			$inc[$j]->{'index'} += $_[0]->[$i]->{'index'};
			}

		# update index of structures after include
		for($j=$i+1; $j<@{$_[0]}; $j++) {
			$_[0]->[$j]->{'index'} += scalar(@inc) - 1;
			}
		splice(@{$_[0]}, $i--, 1, @inc);
		$any++;
		}
	elsif ($_[0]->[$i]->{'type'} == 1) {
		# Check sub-structures too
		$any += &recursive_includes($_[0]->[$i]->{'members'}, $_[1]);
		}
	}
return $any;
}


# parse_struct(&tokens, &lines, &line_num, index, file)
# A structure can either have one value, or a list of values.
# Pos will end up at the start of the next structure
sub parse_struct
{
local (%str, $i, $j, $t, @vals);
$i = ${$_[2]};
$str{'line'} = $_[1]->[$i];
if ($_[0]->[$i] ne '{') {
	# Has a name
	$str{'name'} = lc($_[0]->[$i]);
	}
else {
	# No name, so need to move token pointer back one
	$i--;
	}
$str{'index'} = $_[3];
$str{'file'} = $_[4];
if ($str{'name'} eq 'inet') {
	# The inet directive doesn't have sub-structures, just multiple
	# values with { } in them
	$str{'type'} = 2;
	$str{'members'} = { };
	while(1) {
		$t = $_[0]->[++$i];
		if ($_[0]->[$i+1] eq "{") {
			# Start of a named sub-structure ..
			$i += 2;	# skip {
			$j = 0;
			while($_[0]->[$i] ne "}") {
				my $substr = &parse_struct(
						$_[0], $_[1], \$i, $j++, $_[4]);
				if ($substr) {
					$substr->{'parent'} = \%str;
					push(@{$str{'members'}->{$t}}, $substr);
					}
				}
			next;
			}
		elsif ($t eq ";") { last; }
		push(@vals, $t);
		}
	$i++;	# skip trailing ;
	$str{'values'} = \@vals;
	$str{'value'} = $vals[0];
	}
else {
	# Normal directive, like foo bar; or foo bar { smeg; };
	while(1) {
		$t = $_[0]->[++$i];
		if ($t eq "{" || $t eq ";" || $t eq "}") { last; }
		elsif (!defined($t)) { ${$_[2]} = $i; return undef; }
		else { push(@vals, $t); }
		}
	$str{'values'} = \@vals;
	$str{'value'} = $vals[0];
	if ($t eq "{") {
		# contains sub-structures.. parse them
		local(@mems, $j);
		$i++;		# skip {
		$str{'type'} = 1;
		$j = 0;
		while($_[0]->[$i] ne "}") {
			if (!defined($_[0]->[$i])) { ${$_[2]} = $i; return undef; }
			my $substr = &parse_struct(
				$_[0], $_[1], \$i, $j++, $_[4]);
			if ($substr) {
				$substr->{'parent'} = \%str;
				push(@mems, $substr);
				}
			}
		$str{'members'} = \@mems;
		$i += 2;	# skip trailing } and ;
		}
	else {
		# only a single value..
		$str{'type'} = 0;
		if ($t eq ";") {
			$i++;	# skip trailing ;
			}
		}
	}
$str{'eline'} = $_[1]->[$i-1];	# ending line is the line number the trailing
				# ; is on
${$_[2]} = $i;
return \%str;
}

# find(name, &array)
sub find
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &array)
sub find_value
{
local(@v);
@v = &find($_[0], $_[1]);
if (!@v) { return undef; }
elsif (wantarray) { return map { $_->{'value'} } @v; }
else { return $v[0]->{'value'}; }
}

# base_directory([&config], [no-cache])
# Returns the base directory for named files
sub base_directory
{
if ($_[1] || !-r $zone_names_cache) {
	# Actually work out base
	local ($opts, $dir, $conf);
	$conf = $_[0] ? $_[0] : &get_config();
	if (($opts = &find("options", $conf)) &&
	    ($dir = &find("directory", $opts->{'members'}))) {
		return $dir->{'value'};
		}
	if ($config{'named_conf'} =~ /^(.*)\/[^\/]+$/ && $1) {
		return $1;
		}
	return "/etc";
	}
else {
	# Use cache
	local %znc;
	&read_file_cached($zone_names_cache, \%znc);
	return $znc{'base'} || &base_directory($_[0], 1);
	}
}

# save_directive(&parent, name|&olds, &values, indent, [structonly])
# Given a structure containing a directive name, type, values and members
# add, update or remove that directive in config structure and data files.
# Updating of files assumes that there is no overlap between directives -
# each line in the config file must contain part or all of only one directive.
sub save_directive
{
local(@oldv, @newv, $pm, $i, $o, $n, $lref, @nl);
$pm = $_[0]->{'members'};
@oldv = ref($_[1]) ? @{$_[1]} : &find($_[1], $pm);
@newv = @{$_[2]};
for($i=0; $i<@oldv || $i<@newv; $i++) {
	local $oldeline = $i<@oldv ? $oldv[$i]->{'eline'} : undef;
	if ($i < @newv) {
		# Make sure new directive has 'value' set
		local @v = @{$newv[$i]->{'values'}};
		$newv[$i]->{'value'} = @v ? $v[0] : undef;
		}
	if ($i >= @oldv && !$_[5]) {
		# a new directive is being added.. put it at the end of
		# the parent
		if (!$_[4]) {
			local $addfile = $newv[$i]->{'file'} || $_[0]->{'file'};
			local $parent = &get_config_parent($addfile);
			$lref = &read_file_lines(&make_chroot($addfile));
			@nl = &directive_lines($newv[$i], $_[3]);
			splice(@$lref, $_[0]->{'eline'}, 0, @nl);
			$newv[$i]->{'file'} = $_[0]->{'file'};
			$newv[$i]->{'line'} = $_[0]->{'eline'};
			$newv[$i]->{'eline'} =
				$_[0]->{'eline'} + scalar(@nl) - 1;
			&renumber($parent, $_[0]->{'eline'}-1,
				  $_[0]->{'file'}, scalar(@nl));
			}
		push(@$pm, $newv[$i]);
		}
	elsif ($i >= @oldv && $_[5]) {
		# a new directive is being added.. put it at the start of
		# the parent
		if (!$_[4]) {
			local $parent = &get_config_parent($newv[$i]->{'file'} ||
							   $_[0]->{'file'});
			$lref = &read_file_lines(
				&make_chroot($newv[$i]->{'file'} ||
					     $_[0]->{'file'}));
			@nl = &directive_lines($newv[$i], $_[3]);
			splice(@$lref, $_[0]->{'line'}+1, 0, @nl);
			$newv[$i]->{'file'} = $_[0]->{'file'};
			$newv[$i]->{'line'} = $_[0]->{'line'}+1;
			$newv[$i]->{'eline'} =
				$_[0]->{'line'} + scalar(@nl);
			&renumber($parent, $_[0]->{'line'},
				  $_[0]->{'file'}, scalar(@nl));
			}
		splice(@$pm, 0, 0, $newv[$i]);
		}
	elsif ($i >= @newv) {
		# a directive was deleted
		if (!$_[4]) {
			local $parent = &get_config_parent($oldv[$i]->{'file'});
			$lref = &read_file_lines(
					&make_chroot($oldv[$i]->{'file'}));
			$ol = $oldv[$i]->{'eline'} - $oldv[$i]->{'line'} + 1;
			splice(@$lref, $oldv[$i]->{'line'}, $ol);
			&renumber($parent, $oldeline,
				  $oldv[$i]->{'file'}, -$ol);
			}
		splice(@$pm, &indexof($oldv[$i], @$pm), 1);
		}
	else {
		# updating some directive
		if (!$_[4]) {
			local $parent = &get_config_parent($oldv[$i]->{'file'});
			$lref = &read_file_lines(
					&make_chroot($oldv[$i]->{'file'}));
			@nl = &directive_lines($newv[$i], $_[3]);
			$ol = $oldv[$i]->{'eline'} - $oldv[$i]->{'line'} + 1;
			splice(@$lref, $oldv[$i]->{'line'}, $ol, @nl);
			$newv[$i]->{'file'} = $_[0]->{'file'};
			$newv[$i]->{'line'} = $oldv[$i]->{'line'};
			$newv[$i]->{'eline'} =
				$oldv[$i]->{'line'} + scalar(@nl) - 1;
			&renumber($parent, $oldeline,
				  $oldv[$i]->{'file'}, scalar(@nl) - $ol);
			}
		$pm->[&indexof($oldv[$i], @$pm)] = $newv[$i];
		}
	}
}

# directive_lines(&directive, tabs)
# Renders some directive into a number of lines of text
sub directive_lines
{
local(@rv, $v, $m, $i);
$rv[0] = "\t" x $_[1];
$rv[0] .= "$_[0]->{'name'}";
foreach $v (@{$_[0]->{'values'}}) {
	if ($need_quote{$_[0]->{'name'}} && !$i) { $rv[0] .= " \"$v\""; }
	else { $rv[0] .= " $v"; }
	$i++;
	}
if ($_[0]->{'type'} == 1) {
	# multiple values.. include them as well
	$rv[0] .= " {";
	foreach $m (@{$_[0]->{'members'}}) {
		push(@rv, &directive_lines($m, $_[1]+1));
		}
	push(@rv, ("\t" x ($_[1]+1))."}");
	}
elsif ($_[0]->{'type'} == 2) {
	# named sub-structures .. include them too
	foreach my $sn (sort { $a cmp $b } (keys %{$_[0]->{'members'}})) {
		$rv[0] .= " ".$sn." {";
		foreach $m (@{$_[0]->{'members'}->{$sn}}) {
			$rv[0] .= " ".join(" ", &directive_lines($m, 0));
			}
		$rv[0] .= " }";
		}
	}
$rv[$#rv] .= ";";
return @rv;
}

# renumber(&parent, line, file, count)
# Runs through the given array of directives and increases the line numbers
# of all those greater than some line by the given count
sub renumber
{
if ($_[0]->{'file'} eq $_[2]) {
	if ($_[0]->{'line'} > $_[1]) { $_[0]->{'line'} += $_[3]; }
	if ($_[0]->{'eline'} > $_[1]) { $_[0]->{'eline'} += $_[3]; }
	}
if ($_[0]->{'type'} == 1) {
	# Do sub-members
	local $d;
	foreach $d (@{$_[0]->{'members'}}) {
		&renumber($d, $_[1], $_[2], $_[3]);
		}
	}
elsif ($_[0]->{'type'} == 2) {
	# Do sub-members
	local ($sm, $d);
	foreach $sm (keys %{$_[0]->{'members'}}) {
		foreach $d (@{$_[0]->{'members'}->{$sm}}) {
			&renumber($d, $_[1], $_[2], $_[3]);
			}
		}
	}
}

# choice_input(text, name, &config, [display, option]+)
# Returns a table row for a multi-value BIND option
sub choice_input
{
my $v = &find_value($_[1], $_[2]);
my @opts;
for(my $i=3; $i<@_; $i+=2) {
	push(@opts, [ $_[$i+1], $_[$i] ]);
	}
return &ui_table_row($_[0], &ui_radio($_[1], $v, \@opts));
}

# save_choice(name, &parent, indent)
# Updates the config from a multi-value option
sub save_choice
{
local($nd);
if ($in{$_[0]}) { $nd = { 'name' => $_[0], 'values' => [ $in{$_[0]} ] }; }
&save_directive($_[1], $_[0], $nd ? [ $nd ] : [ ], $_[2]);
}

# addr_match_input(text, name, &config)
# A field for editing a list of addresses, ACLs and partial IP addresses
sub addr_match_input
{
my @av;
my $v = &find($_[1], $_[2]);
if ($v) {
	foreach my $av (@{$v->{'members'}}) {
		push(@av, join(" ", $av->{'name'}, @{$av->{'values'}}));
		}
	}
return &ui_table_row($_[0],
	&ui_radio("$_[1]_def", $v ? 0 : 1, [ [ 1, $text{'default'} ],
					     [ 0, $text{'listed'} ] ])."<br>".
	&ui_textarea($_[1], join("\n", @av), 3, 50));
}

# save_addr_match(name, &parent, indent)
sub save_addr_match
{
local($addr, @vals, $dir);
if ($in{"$_[0]_def"}) { &save_directive($_[1], $_[0], [ ], $_[2]); }
else {
	$in{$_[0]} =~ s/\r//g;
	foreach $addr (split(/\n+/, $in{$_[0]})) {
		local ($n, @v) = split(/\s+/, $addr);
		push(@vals, { 'name' => $n, 'values' => \@v });
		}
	$dir = { 'name' => $_[0], 'type' => 1, 'members' => \@vals };
	&save_directive($_[1], $_[0], [ $dir ], $_[2]);
	}
}

# address_port_input(addresstext, portlabeltext, portnametext, defaulttext,
#                    addressname, portname, &config, size, type)
# Returns table fields for address and a port number
sub address_port_input
  {
    # Address, using existing function
    my $rv = &address_input($_[0], $_[4], $_[6], $_[8]);
    my $v = &find($_[4], $_[6]);

    my $port;
    for ($i = 0; $i < @{$v->{'values'}}; $i++) {
      if ($v->{'values'}->[$i] eq $_[5]) {
	$port = $v->{'values'}->[$i+1];
	last;
      }
    }

    # Port part
    my $n;
    ($n = $_[5]) =~ s/[^A-Za-z0-9_]/_/g;
    $rv .= &ui_table_row($_[1],
		&ui_opt_textbox($n, $port, $_[7], $_[3], $_[2]));
    return $rv;
  }

# address_input(text, name, &config, type)
sub address_input
{
local($v, $av, @av);
$v = &find($_[1], $_[2]);
foreach $av (@{$v->{'members'}}) {
	push(@av, join(" ", $av->{'name'}, @{$av->{'values'}}));
	}
if ($_[3] == 0) {
	# text area
	return &ui_table_row($_[0],
		&ui_textarea($_[1], join("\n", @av), 3, 50));
	}
else {
	# text row
	return &ui_table_row($_[0],
		&ui_textbox($_[1], join(' ',@av), 50));
	}
}

# save_port_address(name, portname, &config, indent)
sub save_port_address {
  local($addr, $port, @vals, $dir);
  foreach $addr (split(/\s+/, $in{$_[0]})) {
    $addr =~ /^\S+$/ || &error(&text('eipacl', $addr));
    push(@vals, { 'name' => $addr });
  }
  $dir = { 'name' => $_[0], 'type' => 1, 'members' => \@vals };
  ($n = $_[1]) =~ s/[^A-Za-z0-9_]/_/g;
  $dir->{'values'} = [ $_[1], $in{$_[1]} ] if (!$in{"${n}_def"});
  &save_directive($_[2], $_[0], @vals ? [ $dir ] : [ ], $_[3]);
}

# save_address(name, &parent, indent, ips-only)
sub save_address
{
local ($addr, @vals, $dir, $i);
local @sp = split(/\s+/, $in{$_[0]});
for($i=0; $i<@sp; $i++) {
	!$_[3] || &check_ipaddress($sp[$i]) || &error(&text('eip', $sp[$i]));
	if (lc($sp[$i]) eq "key") {
		push(@vals, { 'name' => $sp[$i],
			      'values' => [ $sp[++$i] ] });
		}
	else {
		push(@vals, { 'name' => $sp[$i] });
		}
	}
$dir = { 'name' => $_[0], 'type' => 1, 'members' => \@vals };
&save_directive($_[1], $_[0], @vals ? [ $dir ] : [ ], $_[2]);
}

# forwarders_input(text, name, &config)
# Returns a form field containing a table of forwarding IPs and ports
sub forwarders_input
{
my $v = &find($_[1], $_[2]);
my (@ips, @prs);
foreach my $av (@{$v->{'members'}}) {
	push(@ips, $av->{'name'});
	if ($av->{'values'}->[0] eq 'port') {
		push(@prs, $av->{'values'}->[1]);
		}
	else {
		push(@prs, undef);
		}
	}
my @table;
for(my $i=0; $i<@ips+3; $i++) {
	push(@table, [ &ui_textbox("$_[1]_ip_$i", $ips[$i], 20),
		       &ui_opt_textbox("$_[1]_pr_$i", $prs[$i], 5,
				       $text{'default'}),
		     ]);
	}
return &ui_table_row($_[0],
	&ui_columns_table([ $text{'forwarding_ip'}, $text{'forwarding_port'} ],
			  undef, \@table, undef, 1), 3);
}

# save_forwarders(name, &parent, indent)
sub save_forwarders
{
local ($i, $ip, $pr, @vals);
for($i=0; defined($ip = $in{"$_[0]_ip_$i"}); $i++) {
	next if (!$ip);
	&check_ipaddress($ip) || &check_ip6address($ip) ||
		&error(&text('eip', $ip));
	$pr = $in{"$_[0]_pr_${i}_def"} ? undef : $in{"$_[0]_pr_$i"};
	!$pr || $pr =~ /^\d+$/ || &error(&text('eport', $pr));
	push(@vals, { 'name' => $ip,
		      'values' => $pr ? [ "port", $pr ] : [ ] });
	}
local $dir = { 'name' => $_[0], 'type' => 1, 'members' => \@vals };
&save_directive($_[1], $_[0], @vals ? [ $dir ] : [ ], $_[2]);
}

# opt_input(text, name, &config, default, size, units)
# Returns a table row with an optional text field
sub opt_input
{
my $v = &find($_[1], $_[2]);
my $n;
($n = $_[1]) =~ s/[^A-Za-z0-9_]/_/g;
return &ui_table_row($_[0],
	&ui_opt_textbox($n, $v ? $v->{'value'} : "", $_[4], $_[3])." ".$_[5],
	$_[4] > 30 ? 3 : 1);
}

sub save_opt
{
local($dir, $n);
($n = $_[0]) =~ s/[^A-Za-z0-9_]/_/g;
if ($in{"${n}_def"}) { &save_directive($_[2], $_[0], [ ], $_[3]); }
elsif ($err = &{$_[1]}($in{$n})) {
	&error($err);
	}
else {
	$dir = { 'name' => $_[0], 'values' => [ $in{$n} ] };
	&save_directive($_[2], $_[0], [ $dir ], $_[3]);
	}
}

# directives that need their value to be quoted
@need_quote = ( "file", "zone", "view", "pid-file", "statistics-file",
	        "dump-file", "named-xfer", "secret" );
foreach $need (@need_quote) {
	$need_quote{$need}++;
	}

1;

# find_reverse(address, [view])
# Returns the zone and record structures for the PTR record for some address
sub find_reverse
{
local($conf, @zl, $rev, $z, $revconf, $revfile, $revrec, @revrecs, $addr, $rr,
      @octs, $i, @hexs, $ipv6, @zero);

# find reverse domain
local @zl = grep { $_->{'type'} ne 'view' } &list_zone_names();
if ($_[1] ne '') {
	@zl = grep { $_->{'view'} && $_->{'viewindex'} == $_[1] } @zl;
	}
else {
	@zl = grep { !$_->{'view'} } @zl;
	}
$ipv6 = $config{'support_aaaa'} && &check_ip6address($_[0]);
if ($ipv6) {
	@zero = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
	$addr = &expandall_ip6($_[0]);
	$addr =~ s/://g;
	@hexs = split('', $addr);
	DOMAIN: for($i=30; $i>=0; $i--) {
		$addr = join(':',split(/(.{4})/,join('', (@hexs[0..$i],@zero[$i..30]))));
		$addr =~ s/::/:/g;
		$addr =~ s/(^:|:$)//g;
		$rev = &net_to_ip6int($addr, 4*($i+1));
		$rev =~ s/\.$//g;
		foreach $z (@zl) {
			if (lc($z->{'name'}) eq $rev && $z->{'type'} eq 'master') {
				# found the reverse master domain
				$revconf = $z;
				last DOMAIN;
				}
			}
		}
	}
else {
	@octs = split(/\./, $_[0]);
	DOMAIN: for($i=2; $i>=-1; $i--) {
		$rev = $i<0 ? "in-addr.arpa"
			    : &ip_to_arpa(join('.', @octs[0..$i]));
		$rev =~ s/\.$//g;
		foreach $z (@zl) {
			if ((lc($z->{'name'}) eq $rev ||
			     lc($z->{'name'}) eq "$rev.") &&
			    $z->{'type'} eq "master") {
				# found the reverse master domain
				$revconf = $z;
				last DOMAIN;
				}
			}
		}
	}

# find reverse record
if ($revconf) {
	$revfile = &absolute_path($revconf->{'file'});
	@revrecs = &read_zone_file($revfile, $revconf->{'name'});
	if ($ipv6) {
		$addr = &net_to_ip6int($_[0], 128);
		}
	else {
		$addr = &ip_to_arpa($_[0]);
		}
	foreach $rr (@revrecs) {
		if ($rr->{'type'} eq "PTR" &&
		    lc($rr->{'name'}) eq lc($addr)) {
			# found the reverse record
			$revrec = $rr;
			last;
			}
		}
	}
return ($revconf, $revfile, $revrec);
}

# find_forward(address, [view])
# Returns the zone and record structures for the A record for some address
sub find_forward
{
local ($fwdconf, $i, $fwdfile, $fwdrec, $fr, $ipv6);

# find forward domain
local $host = $_[0]; $host =~ s/\.$//;
local @zl = grep { $_->{'type'} ne 'view' } &list_zone_names();
if ($_[1] ne '') {
	@zl = grep { $_->{'view'} && $_->{'viewindex'} == $_[1] } @zl;
	}
else {
	@zl = grep { !$_->{'view'} } @zl;
	}
local @parts = split(/\./, $host);
DOMAIN: for($i=1; $i<@parts; $i++) {
	local $fwd = join(".", @parts[$i .. @parts-1]);
	foreach $z (@zl) {
		local $typed;
		if ((lc($z->{'name'}) eq $fwd ||
		     lc($z->{'name'}) eq "$fwd.") &&
		    $z->{'type'} eq "master") {
			# Found the forward master!
			$fwdconf = $z;
			last DOMAIN;
			}
		}
	}

# find forward record
if ($fwdconf) {
	$fwdfile = &absolute_path($fwdconf->{'file'});
	local @fwdrecs = &read_zone_file($fwdfile, $fwdconf->{'name'});
	foreach $fr (@fwdrecs) {
		if ($ipv6 ? $fr->{'type'} eq "AAAA" : $fr->{'type'} eq "A" &&
		    $fr->{'name'} eq $_[0]) {
			# found the forward record!
			$fwdrec = $fr;
			last;
			}
		}
	}

return ($fwdconf, $fwdfile, $fwdrec);
}

# can_edit_zone(&zone, [&view] | &cachedzone)
# Returns 1 if some zone can be edited
sub can_edit_zone
{
local %zcan;
local ($zn, $vn, $file);
if ($_[0]->{'members'}) {
	# A full zone structure
	$zn = $_[0]->{'value'};
	$vn = $_[1] ? 'view_'.$_[1]->{'value'} : undef;
	$file = &find_value("file", $_[0]->{'members'});
	}
else {
	# A cached zone object
	$zn = $_[0]->{'name'};
	$vn = $_[0]->{'view'} eq '*' ? undef : $_[0]->{'view'};
	$file = $_[0]->{'file'};
	}

# Check zone name
if ($access{'zones'} eq '*') {
	# Always can
	}
elsif ($access{'zones'} =~ /^\!/) {
	# List of denied zones
	foreach (split(/\s+/, $access{'zones'})) {
		return 0 if ($_ eq $zn || ($vn && $_ eq $vn));
		}
	}
else {
	# List of allowed zones
	local $ok;
	foreach (split(/\s+/, $access{'zones'})) {
		$ok++ if ($_ eq $zn || ($vn && $_ eq $vn));
		}
	return 0 if (!$ok);
	}

if ($access{'dironly'}) {
	# Check directory access control 
	return 1 if (!$file);
	$file = &absolute_path($file);
	return 0 if (!&allowed_zone_file(\%access, $file));
	}
return 1;
}

# can_edit_reverse(&zone)
sub can_edit_reverse
{
return $access{'reverse'} || &can_edit_zone($_[0]);
}

# record_input(zoneindex, view, type, file, origin, [num], [record],
#	       [new-name, new-value])
# Display a form for editing or creating a DNS record
sub record_input
{
local(%rec, @recs, $ttl, $ttlunit);
local $type = $_[6] ? $_[6]->{'type'} : $_[2];
print &ui_form_start("save_record.cgi");
print &ui_hidden("index", $_[0]);
print &ui_hidden("view", $_[1]);
print &ui_hidden("file", $_[3]);
print &ui_hidden("origin", $_[4]);
print &ui_hidden("sort", $in{'sort'});
if (defined($_[5])) {
	print &ui_hidden("num", $_[5]);
	%rec = %{$_[6]};
	print &ui_hidden("id", &record_id(\%rec));
	}
else {
	print &ui_hidden("new", 1);
	$rec{'name'} = $_[7] if ($_[7]);
	$rec{'values'} = [ $_[8] ] if ($_[8]);
	}
print &ui_hidden("type", $type);
print &ui_hidden("redirtype", $_[2]);
print &ui_table_start(&text(defined($_[5]) ? 'edit_edit' : 'edit_add',
			    $text{"edit_".$type}));

# Record name field(s)
if ($type eq "PTR") {
	print &ui_table_row($text{'edit_addr'},
		&ui_textbox("name",
		  !%rec && $_[4] =~ /^(\d+)\.(\d+)\.(\d+)\.in-addr/ ?
			"$3.$2.$1." :
			&ip6int_to_net(&arpa_to_ip($rec{'name'})), 30));
	}
elsif ($type eq "NS") {
	print &ui_table_row($text{'edit_zonename'},
		&ui_textbox("name", $rec{'name'}, 30));
	}
elsif ($type eq "SRV") {
	local ($serv, $proto, $name) =
		$rec{'name'} =~ /^([^\.]+)\.([^\.]+)\.(\S+)/ ? ($1, $2, $3) :
			(undef, undef, undef);
	$serv =~ s/^_//;
	$proto =~ s/^_//;
	print &ui_table_row($text{'edit_name'},
		&ui_textbox("name", $name, 30));

	print &ui_table_row($text{'edit_proto'},
		&ui_select("proto", $proto,
			   [ [ "tcp", "TCP" ],
			     [ "udp", "UDP" ],
			     [ "tls", "TLS" ] ], undef, undef, 1));

	print &ui_table_row($text{'edit_serv'},
		&ui_textbox("serv", $serv, 20));
	}
else {
	print &ui_table_row($text{'edit_name'},
		&ui_textbox("name", $rec{'name'}, 30));
	}

# Show canonical name too, if not auto-converted
if ($config{'short_names'} && defined($_[5])) {
	print &ui_table_row($text{'edit_canon'}, "<tt>$rec{'canon'}</tt>");
	}

# TTL field
if ($rec{'ttl'} =~ /^(\d+)([SMHDW]?)$/i) {
	$ttl = $1; $ttlunit = $2;
	}
else {
	$ttl = $rec{'ttl'}; $ttlunit = "";
	}
print &ui_table_row($text{'edit_ttl'},
	&ui_opt_textbox("ttl", $ttl, 8, $text{'default'})." ".
	&time_unit_choice("ttlunit", $ttlunit));

# Value(s) fields
@v = @{$rec{'values'}};
if ($type eq "A" || $type eq "AAAA") {
	print &ui_table_row($text{'value_A1'},
	    &ui_textbox("value0", $v[0], 20)." ".
	    (!defined($_[5]) && $type eq "A" ?
	     &free_address_button("value0") : ""), 3);
	if (defined($_[5])) {
		print &ui_hidden("oldname", $rec{'name'});
		print &ui_hidden("oldvalue0", $v[0]);
		}
	}
elsif ($type eq "NS") {
	print &ui_table_row($text{'value_NS1'},
	    &ui_textbox("value0", $v[0], 30)." ($text{'edit_cnamemsg'})", 3);
	}
elsif ($type eq "CNAME") {
	print &ui_table_row($text{'value_CNAME1'},
	    &ui_textbox("value0", $v[0], 30)." ($text{'edit_cnamemsg'})", 3);
	}
elsif ($type eq "MX") {
	print &ui_table_row($text{'value_MX2'},
	    &ui_textbox("value1", $v[1], 30));
	print &ui_table_row($text{'value_MX1'},
	    &ui_textbox("value0", $v[0], 8));
	}
elsif ($type eq "HINFO") {
	print &ui_table_row($text{'value_HINFO1'},
	    &ui_textbox("value0", $v[0], 20));
	print &ui_table_row($text{'value_HINFO2'},
	    &ui_textbox("value1", $v[1], 20));
	}
elsif ($type eq "TXT") {
	print &ui_table_row($text{'value_TXT1'},
	    &ui_textbox("value0", $v[0], 40), 3);
	}
elsif ($type eq "WKS") {
	# Well known server
	print &ui_table_row($text{'value_WKS1'},
		&ui_textbox("value0", $v[0], 15));

	print &ui_table_row($text{'value_WKS2'},
		&ui_select("value1", lc($v[1]),
			   [ [ "tcp", "TCP" ], [ "udp", "UDP" ] ]));

	print &ui_table_row($text{'value_WKS3'},
		&ui_textarea("value2", join(' ', @v[2..$#v]), 3, 20));
	}
elsif ($type eq "RP") {
	# Responsible person
	print &ui_table_row($text{'value_RP1'},
		&ui_textbox("value0", &dotted_to_email($v[0]), 20));

	print &ui_table_row($text{'value_RP2'},
		&ui_textbox("value1", $v[1], 30));
	}
elsif ($type eq "PTR") {
	# Reverse address
	print &ui_table_row($text{'value_PTR1'},
		&ui_textbox("value0", $v[0], 30), 3);
	if (defined($_[5])) {
		print &ui_hidden("oldname", $rec{'name'});
		print &ui_hidden("oldvalue0", $v[0]);
		}
	}
elsif ($type eq "SRV") {
	print &ui_table_row($text{'value_SRV1'},
		&ui_textbox("value0", $v[0], 8));

	print &ui_table_row($text{'value_SRV2'},
		&ui_textbox("value1", $v[1], 8));

	print &ui_table_row($text{'value_SRV3'},
		&ui_textbox("value2", $v[2], 8));

	print &ui_table_row($text{'value_SRV4'},
		&ui_textbox("value3", $v[3], 30));
	}
elsif ($type eq "LOC") {
	print &ui_table_row($text{'value_LOC1'},
		&ui_textbox("value0", join(" ", @v), 40), 3);
	}
elsif ($type eq "KEY") {
	print &ui_table_row($text{'value_KEY1'},
		&ui_textbox("value0", $v[0], 8));

	print &ui_table_row($text{'value_KEY2'},
		&ui_textbox("value1", $v[1], 8));

	print &ui_table_row($text{'value_KEY3'},
		&ui_textbox("value2", $v[2], 8));

	print &ui_table_row($text{'value_KEY4'},
		&ui_textarea("value3", join("\n", &wrap_lines($v[3], 80)),
			     5, 80), 3);
	}
elsif ($type eq "SPF") {
	# SPF records are complex, as they have several attributes encoded
	# in the TXT value
	local $spf = &parse_spf(@v);
	print &ui_table_row($text{'value_spfa'},
		&ui_yesno_radio("spfa", $spf->{'a'} ? 1 : 0), 3);

	print &ui_table_row($text{'value_spfmx'},
		&ui_yesno_radio("spfmx", $spf->{'mx'} ? 1 : 0), 3);

	print &ui_table_row($text{'value_spfptr'},
		&ui_yesno_radio("spfptr", $spf->{'ptr'} ? 1 : 0), 3);

	print &ui_table_row($text{'value_spfas'},
		&ui_textarea("spfas", join("\n", @{$spf->{'a:'}}), 3, 40), 3);

	print &ui_table_row($text{'value_spfmxs'},
		&ui_textarea("spfmxs", join("\n", @{$spf->{'mx:'}}), 3, 40), 3);

	print &ui_table_row($text{'value_spfip4s'},
		&ui_textarea("spfip4s", join("\n", @{$spf->{'ip4:'}}),
		  	     3, 40), 3);

	if (&supports_ipv6()) {
		print &ui_table_row($text{'value_spfip6s'},
			&ui_textarea("spfip6s", join("\n", @{$spf->{'ip6:'}}),
				     3, 40), 3);
		}

	print &ui_table_row($text{'value_spfincludes'},
		&ui_textarea("spfincludes", join("\n", @{$spf->{'include:'}}),
		  	     3, 40), 3);

	print &ui_table_row($text{'value_spfall'},
		&ui_select("spfall", int($spf->{'all'}),
			[ [ 3, $text{'value_spfall3'} ],
			  [ 2, $text{'value_spfall2'} ],
			  [ 1, $text{'value_spfall1'} ],
			  [ 0, $text{'value_spfall0'} ],
			  [ undef, $text{'value_spfalldef'} ] ]), 3);

	print &ui_table_row($text{'value_spfredirect'},
		&ui_opt_textbox("spfredirect", $spf->{'redirect'}, 40,
			    $text{'value_spfnoredirect'}), 3);

	print &ui_table_row($text{'value_spfexp'},
		&ui_opt_textbox("spfexp", $spf->{'exp'}, 40,
			    $text{'value_spfnoexp'}), 3);
	}
else {
	# All other types just have a text box
	print &ui_table_row($text{'value_other'},
		&ui_textarea("values", join("\n", @v), 3, 40), 3);
	}

# Comment field
if ($type ne "WKS") {
	if ($config{'allow_comments'}) {
		print &ui_table_row($text{'edit_comment'},
			&ui_textbox("comment", $rec{'comment'}, 40), 3);
		}
	else {
		print &ui_hidden("comment", $rec{'comment'});
		}
	}

# Update reverse/forward option
if ($type eq "A" || $type eq "AAAA") {
	print &ui_table_row($text{'edit_uprev'},
		&ui_radio("rev", $config{'rev_def'} == 0 ? 1 :
				 $config{'rev_def'} == 2 ? 2 : 0,
		   [ [ 1, $text{'yes'} ],
		     defined($_[5]) ? ( ) : ( [ 2, $text{'edit_over'} ] ),
		     [ 0, $text{'no'} ] ]));
	}
elsif ($type eq "PTR") {
	print &ui_table_row($text{'edit_upfwd'},
		&ui_radio("fwd", $config{'rev_def'} ? 0 : 1,
		   [ [ 1, $text{'yes'} ],
		     [ 0, $text{'no'} ] ]));
	}
print &ui_table_end();

# End buttons
if (!$access{'ro'}) {
	if (defined($_[5])) {
		print &ui_form_end([ [ undef, $text{'save'} ],
				     [ "delete", $text{'delete'} ] ]);
		}
	else {
		print &ui_form_end([ [ undef, $text{'create'} ] ]);
		}
	}
}

# zones_table(&links, &titles, &types, &deletes, &status)
# Returns a table of zones, with checkboxes to delete
sub zones_table
{
local($i);
local @tds = ( "width=5" );
local $rv;
if (&have_dnssec_tools_support()) {
$rv .= &ui_columns_start([ "", $text{'index_zone'}, $text{'index_type'}, $text{'index_status'} ],
			100, 0, \@tds);
} else {
$rv .= &ui_columns_start([ "", $text{'index_zone'}, $text{'index_type'} ],
			100, 0, \@tds);
}

for($i=0; $i<@{$_[0]}; $i++) {
	local @cols;
	if (&have_dnssec_tools_support()) {
		@cols = ( "<a href=\"$_[0]->[$i]\">$_[1]->[$i]</a>",
			$_[2]->[$i], $_[4]->[$i]);
	} else {
		@cols = ( "<a href=\"$_[0]->[$i]\">$_[1]->[$i]</a>",
			$_[2]->[$i]);
	}
	if (defined($_[3]->[$i])) {
		$rv .= &ui_checked_columns_row(\@cols, \@tds, "d", $_[3]->[$i]);
		}
	else {
		$rv .= &ui_columns_row(\@cols, \@tds);
		}
	}
$rv .= &ui_columns_end();
return $rv;
}

# convert_illegal(text)
# Convert text containing special HTML characters to properly display it.
sub convert_illegal
{
$_[0] =~ s/&/&amp;/g;
$_[0] =~ s/>/&gt;/g;
$_[0] =~ s/</&lt;/g;
$_[0] =~ s/"/&quot;/g;
$_[0] =~ s/ /&nbsp;/g;
return $_[0];
}

sub check_net_ip
{
local($j, $arg = $_[0]);
if ($arg !~ /^(\d{1,3}\.){0,3}([0-9\-\/]+)$/) {
	return 0;
	}
foreach $j (split(/\./, $arg)) {
	$j =~ /^(\d+)-(\d+)$/ && $1 < 255 && $2 < 255 ||
	$j =~ /^(\d+)\/(\d+)$/ && $1 < 255 && $2 <= 32 ||
		$j <= 255 || return 0;
	}
return 1;
}

# expand_ip6(ip)
# Transform compact (with ::) IPv6 address to the unique expanded form
# (without :: and leading zeroes in all parts) 
sub expand_ip6
{
my ($ip) = @_;
for(my $n = 6 - ($ip =~ s/([^:]):(?=[^:])/$1:/g); $n > 0; $n--) {
	$ip =~ s/::/:0::/;
	}
$ip =~ s/::/:/;
$ip =~ s/^:/0:/;
$ip =~ s/:$/:0/;
$ip =~ s/(:|^)0(?=\w)/$1/;
$ip =~ tr/[A-Z]/[a-z]/;
return $ip;
}

# expandall_ip6(ip)
# Transform IPv6 address to the expanded form containing all internal 0's 
sub expandall_ip6
{
my ($ip) = @_;
$ip = &expand_ip6($ip);
$ip =~ s/(:|^)(\w{3})(?=:|$)/:0$2/g;
$ip =~ s/(:|^)(\w{2})(?=:|$)/:00$2/g;
$ip =~ s/(:|^)(\w)(?=:|$)/:000$2/g;
return $ip;
}

# check_ip6address(ip)
# Check if some IPv6 address is properly formatted
sub check_ip6address
{
local($ip6);
$ip6 = $_[0];
$ip6 = &expand_ip6($ip6);
return ($ip6 =~ /^([\da-f]{1,4}:){7}([\da-f]{1,4})$/i);
}

sub time_unit_choice 
{
local ($name, $value) = @_;
return &ui_select($name, $value =~ /^(S?)$/i ? "" :
			 $value =~ /M/i ? "M" :
			 $value =~ /H/i ? "H" :
			 $value =~ /D/i ? "D" :
			 $value =~ /W/i ? "W" : $value,
		  [ [ "", $text{'seconds'} ],
		    [ "M", $text{'minutes'} ],
		    [ "H", $text{'hours'} ],
		    [ "D", $text{'days'} ],
		    [ "W", $text{'weeks'} ] ], 1, 0, 1);
}

sub extract_time_units
{
local(@ret);
foreach $j (@_) {
	if ($j =~ /^(\d+)([SMHDW]?)$/is) {
		push(@ret, $2); $j = $1;
		}
	}
return @ret;
}

sub email_to_dotted
{
local $v = $_[0];
$v =~ s/\.$//;
if ($v =~ /^([^.]+)\@(.*)$/) {
	return "$1.$2.";
	}
elsif ($v =~ /^(.*)\@(.*)$/) {
	local ($u, $d) = ($1, $2);
	$u =~ s/\./\\\./g;
	return "\"$u.$d.\"";
	}
else {
	return $v;
	}
}

sub dotted_to_email
{
local $v = $_[0];
if ($v ne ".") {
	$v =~ s/([^\\])\./$1\@/;
	$v =~ s/\\\./\./g;
	$v =~ s/\.$//;
	}
return $v;
}

# set_ownership(file)
# Sets the BIND ownership and permissions on some file
sub set_ownership
{
local ($user, $group, $perms);
if ($config{'file_owner'}) {
	# From config
	($user, $group) = split(/:/, $config{'file_owner'});
	}
elsif ($_[0] =~ /^(.*)\/([^\/]+)$/) {
	# Match parent dir
	my @st = stat($1);
	($user, $group) = ($st[4], $st[5]);
	}
if ($config{'file_perms'}) {
	$perms = oct($config{'file_perms'});
	}
&set_ownership_permissions($user, $group, $perms, $_[0]);
}

if ($bind_version >= 9) {
	@cat_list = ( 'default', 'general', 'database', 'security', 'config',
		      'resolver', 'xfer-in', 'xfer-out', 'notify', 'client',
		      'unmatched', 'network', 'update', 'queries', 'dispatch',
		      'dnssec', 'lame-servers' );
	}
else {
	@cat_list = ( 'default', 'config', 'parser', 'queries',
		      'lame-servers', 'statistics', 'panic', 'update',
		      'ncache', 'xfer-in', 'xfer-out', 'db',
		      'eventlib', 'packet', 'notify', 'cname', 'security',
		      'os', 'insist', 'maintenance', 'load', 'response-checks');
	}

@syslog_levels = ( 'kern', 'user', 'mail', 'daemon', 'auth', 'syslog',
		   'lpr', 'news', 'uucp', 'cron', 'authpriv', 'ftp',
		   'local0', 'local1', 'local2', 'local3',
		   'local4', 'local5', 'local6', 'local7' );

@severities = ( 'critical', 'error', 'warning', 'notice', 'info',
		'debug', 'dynamic' );

# can_edit_view(&view | &viewcache)
# Returns 1 if some view can be edited
sub can_edit_view
{
local %vcan;
local $vn = $_[0]->{'members'} ? $_[0]->{'value'} : $_[0]->{'name'};

if ($access{'vlist'} eq '*') {
	return 1;
	}
elsif ($access{'vlist'} =~ /^\!/) {
	foreach (split(/\s+/, $access{'vlist'})) {
		return 0 if ($_ eq $vn);
		}
	return 1;
	}
else {
	foreach (split(/\s+/, $access{'vlist'})) {
		return 1 if ($_ eq $vn);
		}
	return 0;
	}
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

# add_zone_access(domain)
# Add a new zone to the current user's access list
sub add_zone_access
{
if ($access{'zones'} ne '*' && $access{'zones'} !~ /^\!/) {
	$access{'zones'} = join(" ", &unique(
				split(/\s+/, $access{'zones'}), $_[0]));
	&save_module_acl(\%access);
	}
}

# is_config_valid()
sub is_config_valid
{
local $conf = &get_config();
local ($opts, $dir);
if (($opts = &find("options", $conf)) &&
    ($dir = &find("directory", $opts->{'members'})) &&
    !(-d &make_chroot($dir->{'value'}))) {
	return 0;
	}
return 1;
}

# check_bind_8()
# Returns the --help output if non BIND 8/9, or undef if is
sub check_bind_8
{
local $fflag = $gconfig{'os_type'} eq 'windows' ? '-f' : '';
local $out = `$config{'named_path'} -help $fflag 2>&1`;
return $out !~ /\[-f\]/ && $out !~ /\[-f\|/ ? $out : undef;
}

# get_chroot()
# Returns the chroot directory BIND is running under
sub get_chroot
{
if (!defined($get_chroot_cache)) {
	if ($gconfig{'real_os_type'} eq 'CentOS Linux' &&
	    $gconfig{'real_os_version'} >= 6 &&
	    $config{'auto_chroot'} =~ /\/etc\/sysconfig\/named/) {
		# Special case hack - on CentOS 6, chroot path in
		# /etc/sysconfig/named isn't really used
		$config{'auto_chroot'} = undef;
		}
	if ($config{'auto_chroot'}) {
		local $out = &backquote_command(
			"$config{'auto_chroot'} 2>/dev/null");
		if (!$?) {
			$out =~ s/\r|\n//g;
			$get_chroot_cache = $out || "";
			}
		}
	if (!defined($get_chroot_cache)) {
		$get_chroot_cache = $config{'chroot'};
		if ($gconfig{'real_os_type'} eq 'CentOS Linux' &&
		    $gconfig{'real_os_version'} >= 6 &&
		    $get_chroot_cache eq "/var/named/chroot") {
			# On CentOS 6.x, no chroot is needed
			$get_chroot_cache = undef;
			}
		}
	}
return $get_chroot_cache;
}

# make_chroot(file, [is-pid])
# Given a path that is relative to the chroot directory, return the real path
sub make_chroot
{
local $chroot = &get_chroot();
return $_[0] if (!$chroot);
return $_[0] if ($_[0] eq $config{'named_conf'} && $config{'no_chroot'});
return $_[0] if ($_[0] eq $config{'rndc_conf'});	# don't chroot rndc.conf
if ($config{'no_pid_chroot'} && $_[1]) {
	return $_[0];
	}
return $chroot.$_[0];
}

# has_ndc(exclude-mode)
# Returns 2 if rndc is installed, 1 if ndc is instaled, or 0
sub has_ndc
{
if ($config{'rndc_cmd'} =~ /^(\S+)/ && &has_command("$1") && $_[0] != 2) {
	return 2;
	}
if ($config{'ndc_cmd'} =~ /^(\S+)/ && &has_command("$1") && $_[0] != 1) {
	return 1;
	}
return 0;
}

# get_pid_file([no-cache])
# Returns the BIND pid file path, relative to any chroot
sub get_pid_file
{
if ($_[0] || !-r $zone_names_cache) {
	# Read real config
	local $conf = &get_config();
	local ($opts, $pidopt);
	if (($opts = &find("options", $conf)) &&
	    ($pidopt = &find("pid-file", $opts->{'members'}))) {
		# read from PID file
		local $pidfile = $pidopt->{'value'};
		if ($pidfile !~ /^\//) {
			local $dir = &find("directory", $opts->{'members'});
			$pidfile = $dir->{'value'}."/".$pidfile;
			}
		return $pidfile;
		}

	# use default file
	local $p;
	foreach $p (split(/\s+/, $config{'pid_file'})) {
		if (-r &make_chroot($p, 1)) {
			return $p;
			}
		}
	return "/var/run/named.pid";
	}
else {
	# Use cache if possible
	local %znc;
	&read_file_cached($zone_names_cache, \%znc);
	if ($znc{'pidfile'} && -r $znc{'pidfile'}) {
		return $znc{'pidfile'};
		}
	else {
		return &get_pid_file(1);
		}
	}
}

# can_edit_type(record-type)
sub can_edit_type
{
return 1 if (!$access{'types'});
local $t;
foreach $t (split(/\s+/, $access{'types'})) {
	return 1 if (lc($t) eq lc($_[0]));
	}
return 0;
}

# add_to_file()
# Returns the filename to which new zones should be added (possibly relative to
# a chroot directory)
sub add_to_file
{
if ($config{'zones_file'}) {
	local $conf = &get_config();
	local $f;
	foreach $f (&get_all_config_files($conf)) {
		if (&same_file($f, $config{'zones_file'})) {
			return $config{'zones_file'};
			}
		}
	}
return $config{'named_conf'};
}

# get_all_config_files(&conf)
# Returns a list of all config files used by named.conf, including includes
sub get_all_config_files
{
local ($conf) = @_;
local @rv = ( $config{'named_conf'} );
foreach my $c (@$conf) {
	push(@rv, $c->{'file'});
	if ($c->{'type'} == 1) {
		push(@rv, &get_all_config_files($c->{'members'}));
		}
	}
return &unique(@rv);
}

# free_address_button(name)
sub free_address_button
{
return &popup_window_button("free_chooser.cgi", 200, 500, 1,
			    [ [ "ifield", $_[0] ] ]);
}

# create_slave_zone(name, master-ip, [view], [file], [&other-ips])
# A convenience function for creating a new slave zone, if it doesn't exist
# yet. Mainly useful for Virtualmin, to avoid excessive transfer of BIND
# configuration data.
# Returns 0 on success, 1 if BIND is not setup, 2 if the zone already exists,
# or 3 if the view doesn't exist, or 4 if the slave file couldn't be created
sub create_slave_zone
{
local $parent = &get_config_parent();
local $conf = $parent->{'members'};
local $opts = &find("options", $conf);
if (!$opts) {
	return 1;
	}

# Check if exists in the view
if ($_[2]) {
	local ($v) = grep { $_->{'value'} eq $_[2] } &find("view", $conf);
	@zones = &find("zone", $v->{'members'});
	}
else {
	@zones = &find("zone", $conf);
	}
local ($z) = grep { $_->{'value'} eq $_[0] } @zones;
return 2 if ($z);

# Create it
local @mips = &unique($_[1], @{$_[4]});
local $masters = { 'name' => 'masters',
                   'type' => 1,
                   'members' => [ map { { 'name' => $_ } } @mips ] };
local $dir = { 'name' => 'zone',
               'values' => [ $_[0] ],
               'type' => 1,
               'members' => [ { 'name' => 'type',
                                'values' => [ 'slave' ] },
                                $masters
                            ]
	     };
local $base = $config{'slave_dir'} || &base_directory();
if ($base !~ /^([a-z]:)?\//) {
	# Slave dir is relative .. make absolute
	$base = &base_directory()."/".$base;
	}
local $file;
if (!$_[3]) {
	# File has default name and is under default directory
	$file = &automatic_filename($_[0], $_[0] =~ /in-addr/i ? 1 : 0, $base,
				    $_[2]);
	push(@{$dir->{'members'}}, { 'name' => 'file',
				     'values' => [ $file ] } );
	}
elsif ($_[3] ne "none") {
	# File was specified
	$file = $_[3] =~ /^\// ? $_[3] : $base."/".$_[3];
	push(@{$dir->{'members'}}, { 'name' => 'file',
				     'values' => [ $file ] } );
	}

# Create the slave file, so that BIND can write to it
if ($file) {
	&open_tempfile(ZONE, ">".&make_chroot($file), 1, 1) || return 4;
	&close_tempfile(ZONE);
        &set_ownership(&make_chroot($file));
	}

# Get and validate view(s)
local @views;
if ($_[2]) {
	foreach my $vn (split(/\s+/, $_[2])) {
		my ($view) = grep { $_->{'value'} eq $vn }
				    &find("view", $conf);
		push(@views, $view);
		}
	return 3 if (!@views);
	}
else {
	# Top-level only
	push(@views, undef);
	}

# Create the zone in all views
foreach my $view (@views) {
	&create_zone($dir, $conf, $view ? $view->{'index'} : undef);
	}

return 0;
}

# create_master_zone(name, &slave-ips, [view], [file], &records)
# A convenience function for creating a new master zone, if it doesn't exist
# yet. Mainly useful for Virtualmin, to avoid excessive transfer of BIND
# configuration data.
# Returns 0 on success, 1 if BIND is not setup, 2 if the zone already exists,
# or 3 if the view doesn't exist, or 4 if the zone file couldn't be created
sub create_master_zone
{
local ($name, $slaves, $viewname, $file, $records) = @_;
local $parent = &get_config_parent();
local $conf = $parent->{'members'};
local $opts = &find("options", $conf);
if (!$opts) {
	return 1;
	}

# Check if exists in the view
if ($viewname) {
	local ($v) = grep { $_->{'value'} eq $viewname } &find("view", $conf);
	@zones = &find("zone", $v->{'members'});
	}
else {
	@zones = &find("zone", $conf);
	}
local ($z) = grep { $_->{'value'} eq $name } @zones;
return 2 if ($z);

# Create it
local $dir = { 'name' => 'zone',
               'values' => [ $name ],
               'type' => 1,
               'members' => [ { 'name' => 'type',
                                'values' => [ 'master' ] },
                            ]
	     };
local $base = $config{'master_dir'} || &base_directory();
if ($base !~ /^([a-z]:)?\//) {
	# Master dir is relative .. make absolute
	$base = &base_directory()."/".$base;
	}
if (!$file) {
	# File has default name and is under default directory
	$file = &automatic_filename($name, $_[0] =~ /in-addr/i ? 1 : 0, $base,
				    $viewname);
	}
push(@{$dir->{'members'}}, { 'name' => 'file',
			     'values' => [ $file ] } );

# Add slave IPs
if (@$slaves) {
	my $also = { 'name' => 'also-notify',
		     'type' => 1,
		     'members' => [ ] };
	my $allow = { 'name' => 'allow-transfer',
		      'type' => 1,
		      'members' => [ ] };
	foreach my $s (@$slaves) {
		push(@{$also->{'members'}}, { 'name' => $s });
		push(@{$allow->{'members'}}, { 'name' => $s });
		}
	push(@{$dir->{'members'}}, $also, $allow);
	push(@{$dir->{'members'}}, { 'name' => 'notify',
				     'values' => [ 'yes' ] });
	}

# Create the zone file, with records
&open_tempfile(ZONE, ">".&make_chroot($file), 1, 1) || return 4;
&close_tempfile(ZONE);
&set_ownership(&make_chroot($file));
foreach my $r (@$records) {
	if ($r->{'defttl'}) {
		&create_defttl($file, $r->{'defttl'});
		}
	elsif ($r->{'generate'}) {
		&create_generator($file, @{$r->{'generate'}});
		}
	elsif ($r->{'type'}) {
		&create_record($file, $r->{'name'}, $r->{'ttl'}, $r->{'class'},
				      $r->{'type'}, &join_record_values($r),
				      $r->{'comment'});
		}
	}

# Get and validate view(s)
local @views;
if ($viewname) {
	foreach my $vn (split(/\s+/, $viewname)) {
		my ($view) = grep { $_->{'value'} eq $vn }
				    &find("view", $conf);
		push(@views, $view);
		}
	return 3 if (!@views);
	}
else {
	# Top-level only
	push(@views, undef);
	}

# Create the zone in all views
foreach my $view (@views) {
	&create_zone($dir, $conf, $view ? $view->{'index'} : undef);
	}

return 0;
}

# get_master_zone_file(name, [chroot])
# Returns the absolute path to a master zone records file
sub get_master_zone_file
{
local ($name, $chroot) = @_;
local $conf = &get_config();
local @zones = &find("zone", $conf);
local ($v, $z);
foreach $v (&find("view", $conf)) {
        push(@zones, &find("zone", $v->{'members'}));
        }
local ($z) = grep { lc($_->{'value'}) eq lc($name) } @zones;
return undef if (!$z);
local $file = &find("file", $z->{'members'});
return undef if (!$file);
local $filename = &absolute_path($file->{'values'}->[0]);
$filename = &make_chroot($filename) if ($chroot);
return $filename;
}

# get_master_zone_records(name)
# Returns a list of all the records in a master zone, each of which is a hashref
sub get_master_zone_records
{
local ($name) = @_;
local $filename = &get_master_zone_file($name, 0);
return ( ) if (!$filename);
return &read_zone_file($filename, $name);
}

# save_master_zone_records(name, &records)
# Update all the records in the master zone, based on a list of hashrefs
sub save_master_zone_records
{
local ($name, $records) = @_;
local $filename = &get_master_zone_file($name, 0);
return 0 if (!$filename);
&open_tempfile(ZONE, ">".&make_chroot($filename), 1, 1) || return 0;
&close_tempfile(ZONE);
foreach my $r (@$records) {
	if ($r->{'defttl'}) {
		&create_defttl($filename, $r->{'defttl'});
		}
	elsif ($r->{'generate'}) {
		&create_generator($filename, @{$r->{'generate'}});
		}
	elsif ($r->{'type'}) {
		&create_record($filename, $r->{'name'}, $r->{'ttl'},
			       $r->{'class'}, $r->{'type'},
			       &join_record_values($r), $r->{'comment'});
		}
	}
return 1;
}

# delete_zone(name, [view], [file-too])
# Delete one zone from named.conf
# Returns 0 on success, 1 if the zone was not found, or 2 if the view was not
# found.
sub delete_zone
{
local $parent = &get_config_parent();
local $conf = $parent->{'members'};
local @zones;

if ($_[1]) {
	# Look in one or more views
	foreach my $vn (split(/\s+/, $_[1])) {
		local ($v) = grep { $_->{'value'} eq $vn }
				  &find("view", $conf);
		if ($v) {
			push(@zones, &find("zone", $v->{'members'}));
			}
		}
	return 2 if (!@zones);
	$parent = $v;
	}
else {
	# Look in all views
	push(@zones, &find("zone", $conf));
	foreach my $v (&find("view", $conf)) {
		push(@zones, &find("zone", $v->{'members'}));
		}
	}

# Delete all zones in the list
local $found = 0;
foreach my $z (grep { $_->{'value'} eq $_[0] } @zones) {
	$found++;

	# Remove from config file
	&lock_file($z->{'file'});
	&save_directive($z->{'parent'} || $parent, [ $z ], [ ]);
	&unlock_file($z->{'file'});
	&flush_file_lines();

	if ($_[2]) {
		# Remove file
		local $f = &find("file", $z->{'members'});
		if ($f) {
			&unlink_logged(&make_chroot(
				&absolute_path($f->{'value'})));
			}
		}
	}

&flush_zone_names();
return $found ? 0 : 1;
}

# rename_zone(oldname, newname, [view])
# Changes the name of some zone, and perhaps it's file
# Returns 0 on success, 1 if the zone was not found, or 2 if the view was
# not found.
sub rename_zone
{
local $parent = &get_config_parent();
local $conf = $parent->{'members'};
local @zones;
if ($_[2]) {
	# Look in one view
	local ($v) = grep { $_->{'value'} eq $_[2] } &find("view", $conf);
	return 2 if (!$v);
	@zones = &find("zone", $v->{'members'});
	$parent = $v;
	}
else {
	# Look in all views
	@zones = &find("zone", $conf);
	local $v;
	foreach $v (&find("view", $conf)) {
		push(@zones, &find("zone", $v->{'members'}));
		}
	}
local ($z) = grep { $_->{'value'} eq $_[0] } @zones;
return 1 if (!$z);

$z->{'values'} = [ $_[1] ];
$z->{'value'} = $_[1];
local $file = &find("file", $z->{'members'});
if ($file) {
	# Update the file too
	local $newfile = $file->{'values'}->[0];
	$newfile =~ s/$_[0]/$_[1]/g;
	if ($newfile ne $file->{'values'}->[0]) {
		rename(&make_chroot($file->{'values'}->[0]),
		       &make_chroot($newfile));
		$file->{'values'}->[0] = $newfile;
		$file->{'value'} = $newfile;
		}
	}

&save_directive($parent, [ $z ], [ $z ]);
&flush_file_lines();
&flush_zone_names();
return 0;
}

# restart_bind()
# A convenience function for re-starting BIND. Returns undef on success, or
# an error message on failure.
sub restart_bind
{
if ($config{'restart_cmd'} eq 'restart') {
	# Stop and start again
	&stop_bind();
	return &start_bind();
	}
elsif ($config{'restart_cmd'}) {
	# Custom command
	local $out = &backquote_logged(
		"$config{'restart_cmd'} 2>&1 </dev/null");
	if ($?) {
		return &text('restart_ecmd', "<pre>$out</pre>");
		}
	}
else {
	# Use signal
	local $pidfile = &get_pid_file();
	local $pid = &check_pid_file(&make_chroot($pidfile, 1));
	if (!$pid) {
		return &text('restart_epidfile', $pidfile);
		}
	elsif (!&kill_logged('HUP', $pid)) {
		return &text('restart_esig', $pid, $!);
		}
	}
&refresh_nscd();
return undef;
}

# restart_zone(domain, [view])
# Call ndc or rndc to apply a single zone. Returns undef on success or an error
# message on failure.
sub restart_zone
{
local ($dom, $view) = @_;
local ($out, $ex);
if ($view) {
	# Reload a zone in a view
	&try_cmd("freeze ".quotemeta($dom)." IN ".quotemeta($view).
		 " 2>&1 </dev/null");
	$out = &try_cmd("reload ".quotemeta($dom)." IN ".quotemeta($view).
			" 2>&1 </dev/null");
	$ex = $?;
	&try_cmd("thaw ".quotemeta($dom)." IN ".quotemeta($view).
		 " 2>&1 </dev/null");
	}
else {
	# Just reload one top-level zone
	&try_cmd("freeze ".quotemeta($dom)." 2>&1 </dev/null");
	$out = &try_cmd("reload ".quotemeta($dom)." 2>&1 </dev/null");
	$ex = $?;
	&try_cmd("thaw ".quotemeta($dom)." 2>&1 </dev/null");
	}
if ($out =~ /not found/i) {
	# Zone is not known to BIND yet - do a total reload
	local $err = &restart_bind();
	return $err if ($err);
	if ($access{'remote'}) {
		# Restart all slaves too
		&error_setup();
		local @slaveerrs = &restart_on_slaves();
		if (@slaveerrs) {
			return &text('restart_errslave',
			     "<p>".join("<br>",
					map { "$_->[0]->{'host'} : $_->[1]" }
					    @slaveerrs));
			}
		}
	}
elsif ($ex || $out =~ /failed|not found|error/i) {
	return &text('restart_endc', "<tt>".&html_escape($out)."</tt>");
	}
&refresh_nscd();
return undef;
}

# start_bind()
# Attempts to start the BIND DNS server, and returns undef on success or an
# error message on failure
sub start_bind
{
local $chroot = &get_chroot();
local $user;
local $cmd;
if ($config{'named_user'}) {
	$user = "-u $config{'named_user'}";
	if (&get_bind_version() < 9) {
		# Only version 8 takes the -g flag
		if ($config{'named_group'}) {
			$user .= " -g $config{'named_group'}";
			}
		else {
			local @u = getpwnam($config{'named_user'});
			local @g = getgrgid($u[3]);
			$user .= " -g $g[0]";
			}
		}
	}
if ($config{'start_cmd'}) {
	$cmd = $config{'start_cmd'};
	}
elsif (!$chroot) {
	$cmd = "$config{'named_path'} -c $config{'named_conf'} $user </dev/null 2>&1";
	}
elsif (`$config{'named_path'} -help 2>&1` =~ /\[-t/) {
	# use named's chroot option
	$cmd = "$config{'named_path'} -c $config{'named_conf'} -t $chroot $user </dev/null 2>&1";
	}
else {
	# use the chroot command
	$cmd = "chroot $chroot $config{'named_path'} -c $config{'named_conf'} $user </dev/null 2>&1";
	}

local $out = &backquote_logged("$cmd 2>&1 </dev/null");
local $rv = $?;
if ($rv || $out =~ /chroot.*not available/i) {
	return &text('start_error', $out ? "<tt>$out</tt>" : "Unknown error");
	}
return undef;
}

# stop_bind()
# Kills the running DNS server, and returns undef on success or an error message
# upon failure
sub stop_bind
{
if ($config{'stop_cmd'}) {
	# Just use a command
	local $out = &backquote_logged("($config{'stop_cmd'}) 2>&1");
	if ($?) {
		return "<pre>$out</pre>";
		}
	}
else {
	# Kill the process
	local $pidfile = &get_pid_file();
	local $pid = &check_pid_file(&make_chroot($pidfile, 1));
	if (!$pid || !&kill_logged('TERM', $pid)) {
		return $text{'stop_epid'};
		}
	}
return undef;
}

# is_bind_running()
# Returns the PID if BIND is running
sub is_bind_running
{
local $pidfile = &get_pid_file();
local $rv = &check_pid_file(&make_chroot($pidfile, 1));
if (!$rv && $gconfig{'os_type'} eq 'windows') {
	# Fall back to checking for process
	$rv = &find_byname("named");
	}
return $rv;
}

# version_atleast(v1, v2, v3)
sub version_atleast
{
local @vsp = split(/\./, $bind_version);
local $i;
for($i=0; $i<@vsp || $i<@_; $i++) {
	return 0 if ($vsp[$i] < $_[$i]);
	return 1 if ($vsp[$i] > $_[$i]);
	}
return 1;	# same!
}

# get_zone_index(name, [view])
# Returns the index of some zone in the real on-disk configuration
sub get_zone_index
{
undef(@get_config_cache);
local $conf = &get_config();
local $vconf = $_[1] ne '' ? $conf->[$in{'view'}]->{'members'} : $conf;
local $c;
foreach $c (@$vconf) {
	if ($c->{'name'} eq 'zone' && $c->{'value'} eq $_[0]) {
		return $c->{'index'};
		}
	}
return undef;
}

# create_zone(&zone, &conf, [view-idx])
# Convenience function for adding a new zone
sub create_zone
{
local ($dir, $conf, $viewidx) = @_;
if ($viewidx ne "") {
	# Adding inside a view
	local $view = $conf->[$viewidx];
        &lock_file(&make_chroot($view->{'file'}));
        &save_directive($view, undef, [ $dir ], 1);
        &flush_file_lines();
        &unlock_file(&make_chroot($view->{'file'}));
	}
else {
	# Adding at top level
        $dir->{'file'} = &add_to_file();
        local $pconf = &get_config_parent($dir->{'file'});
        &lock_file(&make_chroot($dir->{'file'}));
        &save_directive($pconf, undef, [ $dir ], 0);
        &flush_file_lines();
        &unlock_file(&make_chroot($dir->{'file'}));
	}
&flush_zone_names();
}

$heiropen_file = "$module_config_directory/heiropen";

# get_heiropen()
# Returns an array of open categories
sub get_heiropen
{
open(HEIROPEN, $heiropen_file);
local @heiropen = <HEIROPEN>;
chop(@heiropen);
close(HEIROPEN);
return @heiropen;
}

# save_heiropen(&heir)
sub save_heiropen
{
&open_tempfile(HEIR, ">$heiropen_file");
foreach $h (@{$_[0]}) {
	&print_tempfile(HEIR, $h,"\n");
	}
&close_tempfile(HEIR);
}

# list_zone_names()
# Returns a list of zone names, types, files and views based on a cache
# built from the primary configuration.
sub list_zone_names
{
local @st = stat($zone_names_cache);
local %znc;
&read_file_cached($zone_names_cache, \%znc);

# Check if any files have changed, or if the master config has changed, or
# the PID file.
local @files;
local ($k, $changed, $filecount, %donefile);
foreach $k (keys %znc) {
	if ($k =~ /^file_(.*)$/) {
		$filecount++;
		$donefile{$1}++;
		local @fst = stat($1);
		if ($fst[9] > $st[9]) {
			$changed = 1;
			}
		}
	}
if ($changed || !$filecount || $znc{'version'} != $zone_names_version ||
    !$donefile{$config{'named_conf'}} ||
    $config{'pid_file'} ne $znc{'pidfile_config'}) {
	# Yes .. need to rebuild
	%znc = ( );
	local $conf = &get_config();
	local @views = &find("view", $conf);
	local ($v, $z);
	local $n = 0;
	foreach $v (@views) {
		local @vz = &find("zone", $v->{'members'});
		foreach $z (@vz) {
			local $type = &find_value("type", $z->{'members'});
			local $file = &find_value("file", $z->{'members'});
			$znc{"zone_".($n++)} = join("\t", $z->{'value'},
				$z->{'index'}, $type, $v->{'value'}, $file);
			$files{$z->{'file'}}++;
			}
		$znc{"view_".($n++)} = join("\t", $v->{'value'}, $v->{'index'});
		$files{$v->{'file'}}++;
		}
	foreach $z (&find("zone", $conf)) {
		local $type = &find_value("type", $z->{'members'});
		local $file = &find_value("file", $z->{'members'});
		$znc{"zone_".($n++)} = join("\t", $z->{'value'},
			$z->{'index'}, $type, "*", $file);
		$files{$z->{'file'}}++;
		}

	# Store the base directory and PID file
	$znc{'base'} = &base_directory($conf, 1);
	$znc{'pidfile'} = &get_pid_file(1);
	$znc{'pidfile_config'} = $config{'pid_file'};

	# Store source files
	foreach $f (keys %files) {
		local $realf = &make_chroot(&absolute_path($f));
		local @st = stat($realf);
		$znc{"file_".$realf} = $st[9];
		}

	$znc{'version'} = $zone_names_version;
	&write_file($zone_names_cache, \%znc);
	undef(@list_zone_names_cache);
	}

# Use in-memory cache
if (scalar(@list_zone_names_cache)) {
	return @list_zone_names_cache;
	}

# Construct the return value from the hash
local (@rv, %viewidx);
foreach $k (keys %znc) {
	if ($k =~ /^zone_(\d+)$/) {
		local ($name, $index, $type, $view, $file) =
			split(/\t+/, $znc{$k}, 5);
		push(@rv, { 'name' => $name,
			    'type' => $type,
			    'index' => $index,
			    'view' => $view eq '*' ? undef : $view,
			    'file' => $file });
		}
	elsif ($k =~ /^view_(\d+)$/) {
		local ($name, $index) = split(/\t+/, $znc{$k}, 2);
		push(@rv, { 'name' => $name,
			    'index' => $index,
			    'type' => 'view' });
		$viewidx{$name} = $index;
		}
	}
local $z;
foreach $z (@rv) {
	if ($z->{'type'} ne 'view' && $z->{'view'} ne '*') {
		$z->{'viewindex'} = $viewidx{$z->{'view'}};
		}
	}
@list_zone_names_cache = @rv;
return @rv;
}

# flush_zone_names()
# Clears the in-memory and on-disk zone name caches
sub flush_zone_names
{
undef(@list_zone_names_cache);
unlink($zone_names_cache);
}

# get_zone_name(index|name, [viewindex|"any"])
# Returns a zone cache object, looked up by name or index
sub get_zone_name
{
local @zones = &list_zone_names();
local $field = $_[0] =~ /^\d+$/ ? "index" : "name";
local $z;
foreach $z (@zones) {
	if ($z->{$field} eq $_[0] &&
	    ($_[1] eq 'any' ||
	     $_[1] eq '' && !defined($z->{'viewindex'}) ||
	     $_[1] ne '' && $z->{'viewindex'} == $_[1])) {
		return $z;
		}
	}
return undef;
}

# list_slave_servers()
# Returns a list of Webmin servers on which slave zones are created / deleted
sub list_slave_servers
{
&foreign_require("servers", "servers-lib.pl");
local %ids = map { $_, 1 } split(/\s+/, $config{'servers'});
local %secids = map { $_, 1 } split(/\s+/, $config{'secservers'});
local @servers = &servers::list_servers();
if (%ids) {
	local @rv = grep { $ids{$_->{'id'}} } @servers;
	foreach my $s (@rv) {
		$s->{'sec'} = $secids{$s->{'id'}};
		}
	return @rv;
	}
elsif ($config{'default_slave'} && !defined($config{'servers'})) {
	# Migrate old-style setting of single slave
	local ($serv) = grep { $_->{'host'} eq $config{'default_slave'} }
			     @servers;
	if ($serv) {
		&add_slave_server($serv);
		return ($serv);
		}
	}
return ( );
}

# add_slave_server(&server)
sub add_slave_server
{
&lock_file($module_config);
&foreign_require("servers", "servers-lib.pl");
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", @sids, $_[0]->{'id'});
if ($_[0]->{'sec'}) {
	local @secsids = split(/\s+/, $config{'secservers'});
	$config{'secservers'} = join(" ", @secsids, $_[0]->{'id'});
	}
&sync_default_slave();
&save_module_config();
&unlock_file($module_config);
&servers::save_server($_[0]);
}

# delete_slave_server(&server)
sub delete_slave_server
{
&lock_file($module_config);
local @sids = split(/\s+/, $config{'servers'});
$config{'servers'} = join(" ", grep { $_ != $_[0]->{'id'} } @sids);
local @secsids = split(/\s+/, $config{'secservers'});
$config{'secservers'} = join(" ", grep { $_ != $_[0]->{'id'} } @secsids);
&sync_default_slave();
&save_module_config();
&unlock_file($module_config);
}

sub sync_default_slave
{
local @servers = &list_slave_servers();
if (@servers) {
	$config{'default_slave'} = $servers[0]->{'host'};
	}
else {
	$config{'default_slave'} = '';
	}
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
}

# create_master_records(file, zone, master, email, refresh, retry, expiry, min,
#			add-master-ns, add-slaves-ns, add-template, tmpl-ip,
#			add-template-reverse)
# Creates the records file for a new master zone. Returns undef on success, or
# an error message on failure.
sub create_master_records
{
local ($file, $zone, $master, $email, $refresh, $retry, $expiry, $min,
       $add_master, $add_slaves, $add_tmpl, $ip, $addrev) = @_;

# Create the zone file
&lock_file(&make_chroot($file));
&open_tempfile(ZONE, ">".&make_chroot($file), 1) ||
	return &text('create_efile3', $file, $!);
&print_tempfile(ZONE, "\$ttl $min\n")
	if ($config{'master_ttl'});
&close_tempfile(ZONE);

# create the SOA and NS records
local $serial;
if ($config{'soa_style'} == 1) {
        $serial = &date_serial().sprintf("%2.2d", $config{'soa_start'});
        }
else {
	# Use Unix time for date and running number serials
        $serial = time();
        }
local $vals = "$master $email (\n".
        "\t\t\t$serial\n".
        "\t\t\t$refresh\n".
        "\t\t\t$retry\n".
        "\t\t\t$expiry\n".
        "\t\t\t$min )";
&create_record($file, "$zone.", undef, "IN", "SOA", $vals);
&create_record($file, "$zone.", undef, "IN", "NS", $master)
	if ($add_master);
if ($add_slaves) {
	local $slave;
	foreach $slave (&list_slave_servers()) {
		local @bn = $slave->{'nsname'} ||
				gethostbyname($slave->{'host'});
		local $full = "$bn[0].";
		&create_record($file, "$zone.", undef, "IN", "NS", $full);
		}
	}

if ($add_tmpl) {
	# Create template records
	local %bumped;
	for(my $i=0; $config{"tmpl_$i"}; $i++) {
		local @c = split(/\s+/, $config{"tmpl_$i"}, 3);
		local $name = $c[0] eq '.' ? "$zone." : $c[0];
		local $fullname = $name =~ /\.$/ ? $name : "$name.$zone.";
		local $recip = $c[2] || $ip;
		&create_record($file, $name, undef, "IN", $c[1], $recip);
		if ($addrev && ($c[1] eq "A" || $c[1] eq "AAAA")) {
			# Consider adding reverse record
			local ($revconf, $revfile, $revrec) = &find_reverse(
				$recip, $view);
			if ($revconf && &can_edit_reverse($revconf) &&
			    !$revrec) {
				# Yes, add one
				local $rname = $c[1] eq "A" ?
					&ip_to_arpa($recip) :
					&net_to_ip6int($recip);
				&lock_file(&make_chroot($revfile));
				&create_record($revfile, $rname,
					undef, "IN", "PTR", $fullname);
				if (!$bumped{$revfile}++) {
					local @rrecs = &read_zone_file(
						$revfile, $revconf->{'name'});
					&bump_soa_record($revfile, \@rrecs);
					&sign_dnssec_zone_if_key(
						$revconf, \@rrecs);
					}
				}
			}
		}
	if ($config{'tmpl_include'}) {
		# Add whatever is in the template file
		local $tmpl = &read_file_contents($config{'tmpl_include'});
		local %hash = ( 'ip' => $ip,
				'dom' => $zone );
		$tmpl = &substitute_template($tmpl, \%hash);
		&open_tempfile(FILE, ">>".&make_chroot($file));
		&print_tempfile(FILE, $tmpl);
		&close_tempfile(FILE);
		}
	}

# If DNSSEC for new zones was requested, sign now
local $secerr;
if ($config{'tmpl_dnssec'} && &supports_dnssec()) {
	# Compute the size
	($ok, $size) = &compute_dnssec_key_size($config{'tmpl_dnssecalg'},
						$config{'tmpl_dnssecsizedef'},
						$config{'tmpl_dnssecsize'});
	if (!$ok) {
		# Error computing size??
		$secerr = &text('mcreate_ednssecsize', $size);
		}
	else {
		# Create key and sign, saving any error
		local $fake = { 'file' => $file,
			        'name' => $zone };
		$secerr = &create_dnssec_key($fake, $config{'tmpl_dnssecalg'},
					     $size);
		if (!$secerr) {
			$secerr = &sign_dnssec_zone($fake);
			}
		}
	}

&unlock_file(&make_chroot($file));
&set_ownership(&make_chroot($file));

if ($secerr) {
	return &text('mcreate_ednssec', $secerr);
	}
return undef;
}

# automatic_filename(domain, is-reverse, base, [viewname])
# Returns a filename for a new zone
sub automatic_filename
{
local ($zone, $rev, $base, $viewname) = @_;
local ($subs, $format);
if ($rev) {
	# create filename for reverse zone
	$subs = &ip6int_to_net(&arpa_to_ip($zone));
	$subs =~ s/\//_/;
	$format = $config{'reversezonefilename_format'};
	}
else {
	# create filename for forward zone
	$format = $config{'forwardzonefilename_format'};
	$subs = $zone;
	}
if ($viewname) {
	$subs .= ".".$viewname;
	}
$format =~ s/ZONE/$subs/g;
return $file = $base."/".$format;
}

# create_on_slaves(zone, master-ip, file, [&hostnames], [local-view])
# Creates the given zone on all configured slave servers, and returns a list
# of errors
sub create_on_slaves
{
local ($zone, $master, $file, $hosts, $localview) = @_;
local %on = map { $_, 1 } @$hosts;
&remote_error_setup(\&slave_error_handler);
local $slave;
local @slaveerrs;
local @slaves = &list_slave_servers();
foreach $slave (@slaves) {
	# Skip if not on list to add to
	next if (%on && !$on{$slave->{'host'}} && !$on{$slave->{'nsname'}});

	# Connect to server
	$slave_error = undef;
	&remote_foreign_require($slave, "bind8", "bind8-lib.pl");
	if ($slave_error) {
		push(@slaveerrs, [ $slave, $slave_error ]);
		next;
		}

	# Work out other slave IPs
	local @otherslaves;
	if ($config{'other_slaves'}) {
		@otherslaves = grep { $_ ne '' }
				  map { &to_ipaddress($_->{'host'}) }
				      grep { $_ ne $slave } @slaves;
		}
	push(@otherslaves, split(/\s+/, $config{'extra_slaves'}));

	# Work out the view
	my $view;
	if ($slave->{'bind8_view'} eq '*') {
		# Same as this system
		$view = $localview;
		}
	elsif ($slave->{'bind8_view'}) {
		# Named view
		$view = $slave->{'bind8_view'};
		}

	# Create the zone
	local $err = &remote_foreign_call($slave, "bind8",
		"create_slave_zone", $zone, $master,
		$view, $file, \@otherslaves);
	if ($err == 1) {
		push(@slaveerrs, [ $slave, $text{'master_esetup'} ]);
		}
	elsif ($err == 2) {
		push(@slaveerrs, [ $slave, $text{'master_etaken'} ]);
		}
	elsif ($err == 3) {
		push(@slaveerrs, [ $slave, &text('master_eview',
					 $slave->{'bind8_view'}) ]);
		}
	}
&remote_error_setup();
return @slaveerrs;
}

# delete_on_slaves(domain, [&slave-hostnames], [local-view])
# Delete some domain or all or listed slave servers
sub delete_on_slaves
{
local ($dom, $slavehosts, $localview) = @_;
local %on = map { $_, 1 } @$slavehosts;
&remote_error_setup(\&slave_error_handler);
local $slave;
local @slaveerrs;
foreach $slave (&list_slave_servers()) {
	next if (%on && !$on{$slave->{'host'}} && !$on{$slave->{'nsname'}});

	# Connect to server
	$slave_error = undef;
	&remote_foreign_require($slave, "bind8", "bind8-lib.pl");
	if ($slave_error) {
		push(@slaveerrs, [ $slave, $slave_error ]);
		next;
		}

	# Work out the view
	my $view;
	if ($slave->{'bind8_view'} eq "*") {
		# Same as on master .. but for now, don't pass in any view
		# so that it will be found automatically
		$view = $localview;
		}
	elsif ($slave->{'bind8_view'}) {
		# Named view
		$view = $slave->{'bind8_view'};
		}

	# Delete the zone
	$err = &remote_foreign_call($slave, "bind8", "delete_zone",
			    $dom, $view, 1);
	if ($err == 1) {
		push(@slaveerrs, [ $slave, $text{'delete_ezone'} ]);
		}
	elsif ($err == 2) {
		push(@slaveerrs, [ $slave, &text('master_eview',
					 $slave->{'bind8_view'}) ]);
		}
	}
&remote_error_setup();
return @slaveerrs;
}

# rename_on_slaves(olddomain, newdomain, [&slave-hostnames])
# Changes the name of some domain on all or listed slave servers
sub rename_on_slaves
{
local ($olddom, $newdom, $on) = @_;
local %on = map { $_, 1 } @$on;
&remote_error_setup(\&slave_error_handler);
local $slave;
local @slaveerrs;
foreach $slave (&list_slave_servers()) {
	next if (%on && !$on{$slave->{'host'}} && !$on{$slave->{'nsname'}});

	# Connect to server
	$slave_error = undef;
	&remote_foreign_require($slave, "bind8", "bind8-lib.pl");
	if ($slave_error) {
		push(@slaveerrs, [ $slave, $slave_error ]);
		next;
		}

	# Delete the zone
	$err = &remote_foreign_call($slave, "bind8", "rename_zone",
			    $olddom, $newdom, $slave->{'bind8_view'});
	if ($err == 1) {
		push(@slaveerrs, [ $slave, $text{'delete_ezone'} ]);
		}
	elsif ($err == 2) {
		push(@slaveerrs, [ $slave, &text('master_eview',
					 $slave->{'bind8_view'}) ]);
		}
	}
&remote_error_setup();
return @slaveerrs;
}

# restart_on_slaves([&slave-hostnames])
# Re-starts BIND on all or listed slave servers, and returns a list of errors
sub restart_on_slaves
{
local %on = map { $_, 1 } @{$_[0]};
&remote_error_setup(\&slave_error_handler);
local $slave;
local @slaveerrs;
foreach $slave (&list_slave_servers()) {
	next if (%on && !$on{$slave->{'host'}});

	# Find the PID file
	$slave_error = undef;
	&remote_foreign_require($slave, "bind8", "bind8-lib.pl");
	if ($slave_error) {
		push(@slaveerrs, [ $slave, $slave_error ]);
		next;
		}
	local $sver = &remote_foreign_call($slave, "bind8",
				     "get_webmin_version");
	local $pidfile;
	if ($sver >= 1.140) {
		# Call new function to get PID file from slave
		$pidfile = &remote_foreign_call(
			$slave, "bind8", "get_pid_file");
		$pidfile = &remote_foreign_call(
			$slave, "bind8", "make_chroot", $pidfile, 1);
		}
	else {
		push(@slaveerrs, [ $slave, &text('restart_eversion',
						 $slave->{'host'}, 1.140) ]);
		next;
		}

	# Read the PID and restart
	local $pid = &remote_foreign_call($slave, "bind8",
				    "check_pid_file", $pidfile);
	if (!$pid) {
		push(@slaveerrs, [ $slave, &text('restart_erunning2',
						 $slave->{'host'}) ]);
		next;
		}
	$err = &remote_foreign_call($slave, "bind8", "restart_bind");
	if ($err) {
		push(@slaveerrs, [ $slave, &text('restart_esig2',
						 $slave->{'host'}, $err) ]);
		}
	}
&remote_error_setup();
return @slaveerrs;
}

sub slave_error_handler
{
$slave_error = $_[0];
}

sub get_forward_record_types
{
return ("A", "NS", "CNAME", "MX", "HINFO", "TXT", "SPF", "WKS", "RP", "PTR", "LOC", "SRV", "KEY", $config{'support_aaaa'} ? ( "AAAA" ) : ( ), @extra_forward);
}

sub get_reverse_record_types
{
return ("PTR", "NS", "CNAME", @extra_reverse);
}

# try_cmd(args, [rndc-args])
# Try calling rndc and ndc with the same args, to see which one works
sub try_cmd
{
local $args = $_[0];
local $rndc_args = $_[1] || $_[0];
local $out;
if (&has_ndc() == 2) {
	# Try with rndc
	$out = &backquote_logged("$config{'rndc_cmd'} $rndc_args 2>&1 </dev/null");
	}
if (&has_ndc() != 2 || $out =~ /connect\s+failed/i) {
	if (&has_ndc(2)) {
		# Try with rndc if rndc is not install or failed
		$out = &backquote_logged("$config{'ndc_cmd'} $args 2>&1 </dev/null");
		}
	}
return $out;
}

# supports_check_zone()
# Returns 1 if zone checking is supported, 0 if not
sub supports_check_zone
{
return $config{'checkzone'} && &has_command($config{'checkzone'});
}

# check_zone_records(&zone-name|&zone)
# Returns a list of errors from checking some zone file, if any
sub check_zone_records
{
local ($zone) = @_;
local ($zonename, $zonefile);
if ($zone->{'values'}) {
	# Zone object
	$zonename = $zone->{'values'}->[0];
	local $f = &find("file", $zone->{'members'});
	$zonefile = $f->{'values'}->[0];
	}
else {
	# Zone name object
	$zonename = $zone->{'name'};
	$zonefile = $zone->{'file'};
	}
local $out = &backquote_command(
	$config{'checkzone'}." ".quotemeta($zonename)." ".
	quotemeta(&make_chroot(&absolute_path($zonefile)))." 2>&1 </dev/null");
return $? ? split(/\r?\n/, $out) : ( );
}

# supports_check_conf()
# Returns 1 if BIND configuration checking is supported, 0 if not
sub supports_check_conf
{
return $config{'checkconf'} && &has_command($config{'checkconf'});
}

# check_bind_config([filename])
# Checks the BIND configuration and returns a list of errors
sub check_bind_config
{
local ($file) = @_;
$file ||= &make_chroot($config{'named_conf'});
local $chroot = &get_chroot();
local $out = &backquote_command("$config{'checkconf'} -h 2>&1 </dev/null");
local $zflag = $out =~ /\[-z\]/ ? "-z" : "";
local $out = &backquote_command(
        $config{'checkconf'}.
	($chroot && $chroot ne "/" ? " -t ".quotemeta($chroot) : "").
	" $zflag 2>&1 </dev/null");
return $? ? grep { !/loaded\s+serial/ } split(/\r?\n/, $out) : ( );
}

# delete_records_file(file)
# Given a file (chroot-relative), delete it with locking, and any associated
# journal or log files
sub delete_records_file
{
local ($file) = @_;
local $zonefile = &make_chroot(&absolute_path($file));
&lock_file($zonefile);
unlink($zonefile);
local $logfile = $zonefile.".log";
if (-r $logfile) {
	&lock_file($logfile);
	unlink($logfile);
	}
local $jnlfile = $zonefile.".jnl";
if (-r $jnlfile) {
	&lock_file($jnlfile);
	unlink($jnlfile);
	}
local $signfile = $zonefile.".signed";
if (-r $signfile) {
	&lock_file($signfile);
	unlink($signfile);
	}
}

# move_zone_button(&config, current-view, zone-index)
# If possible, returns a button row for moving this zone to another view
sub move_zone_button
{
local ($conf, $view, $index) = @_;
local @views = grep { &can_edit_view($_) } &find("view", $conf);
if ($view eq '' && @views || $view ne '' && @views > 1) {
	return &ui_buttons_row("move_zone.cgi",
                $text{'master_move'},
                $text{'master_movedesc'},
                &ui_hidden("index", $index).
                &ui_hidden("view", $view),
                &ui_select("newview", undef,
                        [ map { [ $_->{'index'}, $_->{'value'} ] }
                            grep { $_->{'index'} ne $view } @views ]));
	}
return undef;
}

# download_root_zone(file)
# Download the root zone data to a file (under the chroot), and returns undef
# on success or an error message on failure.
sub download_root_zone
{
my ($file) = @_;
my $rootfile = &make_chroot($file);
my $ftperr;
my $temp;
&ftp_download($internic_ftp_host, $internic_ftp_file, $rootfile, \$ftperr);
if ($ftperr) {
	# Try IP address directly
	$ftperr = undef;
	&ftp_download($internic_ftp_ip, $internic_ftp_file, $rootfile,\$ftperr);
	}
if ($ftperr) {
	# Try compressed version
	$ftperr = undef;
	$temp = &transname();
	&ftp_download($internic_ftp_host, $internic_ftp_gzip, $temp, \$ftperr);
	}
if ($ftperr) {
	# Try IP address directly for compressed version!
	$ftperr = undef;
	&ftp_download($internic_ftp_ip, $internic_ftp_gzip, $temp, \$ftperr);
	}
return $ftperr if ($ftperr);

# Got some file .. maybe need to un-compress
if ($temp) {
	&has_command("gzip") || return $text{'boot_egzip'};
	my $out = &backquote_command("gzip -d -c ".quotemeta($temp)." 2>&1 >".
				     quotemeta($rootfile)." </dev/null");
	return &text('boot_egzip2', "<tt>".&html_escape($out)."</tt>") if ($?);
	}
return undef;
}

# restart_links([&zone-name])
# Returns HTML for links to restart or start BIND, separated by <br> for use
# in ui_print_header
sub restart_links
{
local ($zone) = @_;
local @rv;
if (!$access{'ro'} && $access{'apply'}) {
	local $r = $ENV{'REQUEST_METHOD'} eq 'POST' ? 0 : 1;
	if (&is_bind_running()) {
		if ($zone && ($access{'apply'} == 1 || $access{'apply'} == 2)) {
			# Apply this zone
			push(@rv, "<a href='restart_zone.cgi?return=$r&".
				  "view=$zone->{'viewindex'}&".
				  "index=$zone->{'index'}'>".
				  "$text{'links_apply'}</a>");
			}
		# Apply whole config
		if ($access{'apply'} == 1 || $access{'apply'} == 3) {
			push(@rv, "<a href='restart.cgi?return=$r'>".
				  "$text{'links_restart'}</a>");
			}
		if ($access{'apply'} == 1) {
			# Stop BIND
			push(@rv, "<a href='stop.cgi?return=$r'>".
				  "$text{'links_stop'}</a>");
			}
		}
	elsif ($access{'apply'} == 1) {
		# Start BIND
		push(@rv, "<a href='start.cgi?return=$r'>".
			  "$text{'links_start'}</a>");
		}
	}
return join('<br>', @rv);
}

# supports_dnssec()
# Returns 1 if zone signing is supported
sub supports_dnssec
{
return &has_command($config{'signzone'}) &&
       &has_command($config{'keygen'});
}

# supports_dnssec_client()
# Returns 2 if this BIND can send and verify DNSSEC requests, 1 if the 
# dnssec-validation directive is not supported, 0 otherwise
sub supports_dnssec_client
{
return $bind_version >= 9.4 ? 2 :
       $bind_version >= 9 ? 1 : 0;
}

# dnssec_size_range(algorithm)
# Given an algorithm like DSA or DH, return the max and min allowed key sizes,
# and an optional forced divisor.
sub dnssec_size_range
{
local ($alg) = @_;
return $alg eq 'RSAMD5' || $alg eq 'RSASHA1' ? ( 512, 2048 ) :
       $alg eq 'DH' ? ( 128, 4096 ) :
       $alg eq 'DSA' ? ( 512, 1024, 64 ) :
       $alg eq 'HMAC-MD5' ? ( 1, 512 ) :
       $alg eq 'NSEC3RSASHA1' ? ( 512, 4096 ) :
       $alg eq 'NSEC3DSA' ? ( 512, 1024, 64 ) : ( );
}

sub list_dnssec_algorithms
{
return ("RSASHA1", "RSAMD5", "DSA", "DH", "HMAC-MD5",
	"NSEC3RSASHA1", "NSEC3DSA");
}

# get_keys_dir(&zone|&zone-name)
# Returns the directory in which to find DNSSEC keys for some zone
sub get_keys_dir
{
local ($z) = @_;
if ($config{'keys_dir'}) {
	return $config{'keys_dir'};
	}
else {
	local $fn = &get_zone_file($z, 2);
	$fn =~ s/\/[^\/]+$//;
	return $fn;
	}
}

# create_dnssec_key(&zone|&zone-name, algorithm, size, single-key)
# Creates a new DNSSEC key for some zone, and places it in the same directory
# as the zone file. Returns undef on success or an error message on failure.
sub create_dnssec_key
{
local ($z, $alg, $size, $single) = @_;
local $fn = &get_keys_dir($z);
$fn || return "Could not work keys directory!";

# Remove all keys for the same zone
opendir(ZONEDIR, $fn);
foreach my $f (readdir(ZONEDIR)) {
	if ($f =~ /^K\Q$dom\E\.\+(\d+)\+(\d+)\.(key|private)$/) {
		&unlink_file("$fn/$f");
		}
	}
closedir(ZONEDIR);

# Fork a background job to do lots of IO, to generate entropy
local $pid = fork();
if (!$pid) {
	exec("find / -type f >/dev/null 2>&1");
	exit(1);
	}

# Work out zone key size
local $zonesize;
if ($single) {
	(undef, $zonesize) = &compute_dnssec_key_size($alg, 1);
	}
else {
	$zonesize = $size;
	}

# Create the zone key
local $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};
local $out = &backquote_logged(
	"cd ".quotemeta($fn)." && ".
	"$config{'keygen'} -a ".quotemeta($alg)." -b ".quotemeta($zonesize).
	" -n ZONE $rand_flag $dom 2>&1");
if ($?) {
	kill('KILL', $pid);
	return $out;
	}

# Create the key signing key, if needed
if (!$single) {
	$out = &backquote_logged(
		"cd ".quotemeta($fn)." && ".
		"$config{'keygen'} -a ".quotemeta($alg)." -b ".quotemeta($size).
		" -n ZONE -f KSK $rand_flag $dom 2>&1");
	kill('KILL', $pid);
	if ($?) {
		return $out;
		}
	}
else {
	kill('KILL', $pid);
	}

# Get the new keys
local @keys = &get_dnssec_key($z);
@keys || return "No new keys found for zone : $out";
foreach my $key (@keys) {
	ref($key) || return "Failed to get new key for zone : $key";
	}
if (!$single) {
	@keys == 2 || return "Expected 2 keys for zone, but found ".
			     scalar(@keys);
	}

# Add the new DNSKEY record(s) to the zone
local $chrootfn = &get_zone_file($z);
local @recs = &read_zone_file($chrootfn, $dom);
for(my $i=$#recs; $i>=0; $i--) {
	if ($recs[$i]->{'type'} eq 'DNSKEY') {
		&delete_record($chrootfn, $recs[$i]);
		}
	}
foreach my $key (@keys) {
	&create_record($chrootfn, $dom.".", undef, "IN", "DNSKEY",
		       join(" ", @{$key->{'values'}}));
	}
&bump_soa_record($chrootfn, \@recs);

return undef;
}

# resign_dnssec_key(&zone|&zone-name)
# Re-generate the zone key, and re-sign everything. Returns undef on success or
# an error message on failure.
sub resign_dnssec_key
{
local ($z) = @_;
local $fn = &get_zone_file($z);
$fn || return "Could not work out records file!";
local $dir = &get_keys_dir($z);
$dir || return "Could not work out keys directory!";
local $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};

# Get the old zone key record
local @recs = &read_zone_file($fn, $dom);
local $zonerec;
foreach my $r (@recs) {
	if ($r->{'type'} eq 'DNSKEY' && $r->{'values'}->[0] % 2 == 0) {
		$zonerec = $r;
		}
	}
$zonerec || return "Could not find DNSSEC zone key record";
local @keys = &get_dnssec_key($z);
@keys == 2 || return "Expected to find 2 keys, but found ".scalar(@keys);
local ($zonekey) = grep { !$_->{'ksk'} } @keys;
$zonekey || return "Could not find DNSSEC zone key";

# Fork a background job to do lots of IO, to generate entropy
local $pid = fork();
if (!$pid) {
	exec("find / -type f >/dev/null 2>&1");
	exit(1);
	}

# Work out zone key size
local $zonesize;
local $alg = $zonekey->{'algorithm'};
(undef, $zonesize) = &compute_dnssec_key_size($alg, 1);

# Generate a new zone key
local $out = &backquote_logged(
	"cd ".quotemeta($dir)." && ".
	"$config{'keygen'} -a ".quotemeta($alg)." -b ".quotemeta($zonesize).
	" -n ZONE $rand_flag $dom 2>&1");
kill('KILL', $pid);
if ($?) {
	return "Failed to generate new zone key : $out";
	}

# Delete the old key file
&unlink_file($zonekey->{'privatefile'});
&unlink_file($zonekey->{'publicfile'});

# Update the zone file with the new key
@keys = &get_dnssec_key($z);
local ($newzonekey) = grep { !$_->{'ksk'} } @keys;
$newzonekey || return "Could not find new DNSSEC zone key";
&modify_record($fn, $zonerec, $dom.".", undef, "IN", "DNSKEY",
	       join(" ", @{$newzonekey->{'values'}}));
&bump_soa_record($fn, \@recs);

# Re-sign everything
local $err = &sign_dnssec_zone($z);
return "Re-signing failed : $err" if ($err);

return undef;
}

# delete_dnssec_key(&zone|&zone-name)
# Deletes the key for a zone, and all DNSSEC records
sub delete_dnssec_key
{
local ($z) = @_;
local $fn = &get_zone_file($z);
$fn || return "Could not work out records file!";
local $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};

# Remove the key
local @keys = &get_dnssec_key($z);
foreach my $key (@keys) {
	foreach my $f ('publicfile', 'privatefile') {
		&unlink_file($key->{$f}) if ($key->{$f});
		}
	}

# Remove records
local @recs = &read_zone_file($fn, $dom);
for(my $i=$#recs; $i>=0; $i--) {
	if ($recs[$i]->{'type'} eq 'NSEC' ||
	    $recs[$i]->{'type'} eq 'NSEC3' ||
	    $recs[$i]->{'type'} eq 'RRSIG' ||
		$recs[$i]->{'type'} eq 'NSEC3PARAM' ||
	    $recs[$i]->{'type'} eq 'DNSKEY') {
		&delete_record($fn, $recs[$i]);
		}
	}
&bump_soa_record($fn, \@recs);
}

# sign_dnssec_zone(&zone|&zone-name, [bump-soa])
# Replaces a zone's file with one containing signed records.
sub sign_dnssec_zone
{
local ($z, $bump) = @_;
local $chrootfn = &get_zone_file($z, 2);
$chrootfn || return "Could not work out records file!";
local $dir = &get_keys_dir($z);
local $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};
local $signed = $chrootfn.".webmin-signed";

# Up the serial number, if requested
local $fn = &get_zone_file($z, 1);
$fn =~ /^(.*)\/([^\/]+$)/;
local @recs = &read_zone_file($fn, $dom);
if ($bump) {
	&bump_soa_record($fn, \@recs);
	}

# Get the zone algorithm
local @keys = &get_dnssec_key($z);
local ($zonekey) = grep { !$_->{'ksk'} } @keys;
local $alg = $zonekey ? $zonekey->{'algorithm'} : "";

# Create the signed file. Sometimes this fails with an error like :
# task.c:310: REQUIRE(task->references > 0) failed
# But re-trying works!?!
local $out;
local $tries = 0;
while($tries++ < 10) {
	$out = &backquote_logged(
		"cd ".quotemeta($dir)." && ".
		"$config{'signzone'} -o ".quotemeta($dom).
		($alg =~ /^NSEC3/ ? " -3 -" : "").
		" -f ".quotemeta($signed)." ".
		quotemeta($chrootfn)." 2>&1");
	last if (!$?);
	}
return $out if ($tries >= 10);

# Merge records back into original file, by deleting all NSEC and RRSIG records
# and then copying over
for(my $i=$#recs; $i>=0; $i--) {
	if ($recs[$i]->{'type'} eq 'NSEC' ||
	    $recs[$i]->{'type'} eq 'NSEC3' ||
	    $recs[$i]->{'type'} eq 'RRSIG') {
		&delete_record($fn, $recs[$i]);
		}
	}
local @signedrecs = &read_zone_file($fn.".webmin-signed", $dom);
foreach my $r (@signedrecs) {
	if ($r->{'type'} eq 'NSEC' ||
	    $r->{'type'} eq 'NSEC3' ||
	    $r->{'type'} eq 'RRSIG') {
		&create_record($fn, $r->{'name'}, $r->{'ttl'}, $r->{'class'},
			       $r->{'type'}, join(" ", @{$r->{'values'}}),
			       $r->{'comment'});
		}
	}
&unlink_file($signed);
return undef;
}

# check_if_dnssec_tools_managed(&domain)
# Check if the given domain is managed by dnssec-tools
# Return 1 if yes, undef if not
sub check_if_dnssec_tools_managed
{
	local ($dom) = @_;
	my $dt_managed;

	if (&have_dnssec_tools_support()) {
		my $rrr;

		&lock_file($config{"dnssectools_rollrec"});
		rollrec_lock();
		rollrec_read($config{"dnssectools_rollrec"});
		$rrr = rollrec_fullrec($dom);
		if ($rrr) {
			$dt_managed = 1;
		}
		rollrec_close();
		rollrec_unlock();
		&unlock_file($config{"dnssectools_rollrec"});
	}

	return $dt_managed;
}

# sign_dnssec_zone_if_key(&zone|&zone-name, &recs, [bump-soa])
# If a zone has a DNSSEC key, sign it. Calls error if signing fails
sub sign_dnssec_zone_if_key
{
local ($z, $recs, $bump) = @_;

# Check if zones are managed by dnssec-tools
local $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};
 
# If zone is managed through dnssec-tools use zonesigner for resigning the zone 
if (&check_if_dnssec_tools_managed($dom)) {
	# Do the signing
	local $zonefile = &get_zone_file($z); 
	local $krfile = "$zonefile".".krf";
	local $err;

	&lock_file(&make_chroot($zonefile));
	$err = &dt_resign_zone($dom, $zonefile, $krfile, 0);
	&unlock_file(&make_chroot($zonefile));
	&error($err) if ($err);
	return undef;
}

local $keyrec = &get_dnskey_record($z, $recs);
if ($keyrec) {
	local $err = &sign_dnssec_zone($z, $bump);
	&error(&text('sign_emsg', $err)) if ($err);
	}
}

# get_dnssec_key(&zone|&zone-name)
# Returns a list of hash containing details of a zone's keys, or an error
# message. The KSK is always returned first.
sub get_dnssec_key
{
local ($z) = @_;
local $dir = &get_keys_dir($z);
local $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};
local %keymap;
opendir(ZONEDIR, $dir);
foreach my $f (readdir(ZONEDIR)) {
	if ($f =~ /^K\Q$dom\E\.\+(\d+)\+(\d+)\.key$/) {
		# Found the public key file .. read it
		$keymap{$2} ||= { };
		local $rv = $keymap{$2};
		$rv->{'publicfile'} = "$dir/$f";
		$rv->{'algorithmid'} = $1;
		$rv->{'keyid'} = $2;
		local $config{'short_names'} = 0;	# Force canonicalization
		local ($pub) = &read_zone_file("$dir/$f", $dom, undef, 0, 1);
		$pub || return "Public key file $dir/$f does not contain ".
			       "any records";
		$pub->{'name'} eq $dom."." ||
			return "Public key file $dir/$f is not for zone $dom";
		$pub->{'type'} eq "DNSKEY" ||
			return "Public key file $dir/$f does not contain ".
			       "a DNSKEY record";
		$rv->{'ksk'} = $pub->{'values'}->[0] % 2 ? 1 : 0;
		$rv->{'public'} = $pub->{'values'}->[3];
		$rv->{'values'} = $pub->{'values'};
		$rv->{'publictext'} = &read_file_contents("$dir/$f");
		}
	elsif ($f =~ /^K\Q$dom\E\.\+(\d+)\+(\d+)\.private$/) {
		# Found the private key file
		$keymap{$2} ||= { };
		local $rv = $keymap{$2};
		$rv->{'privatefile'} = "$dir/$f";
		local $lref = &read_file_lines("$dir/$f", 1);
		foreach my $l (@$lref) {
			if ($l =~ /^(\S+):\s*(.*)/) {
				local ($n, $v) = ($1, $2);
				$n =~ s/\(\S+\)$//;
				$n = lc($n);
				$rv->{$n} = $v;
				}
			}
		$rv->{'algorithm'} =~ s/^\d+\s+\((\S+)\)$/$1/;
		$rv->{'privatetext'} = join("\n", @$lref)."\n";
		}
	}
closedir(ZONEDIR);

# Sort to put KSK first
local @rv = values %keymap;
@rv = sort { $b->{'ksk'} <=> $a->{'ksk'} } @rv;
return wantarray ? @rv : $rv[0];
}

# compute_dnssec_key_size(algorithm, def-mode, size)
# Given an algorith and size mode (0=entered, 1=average, 2=big), returns either
# 0 and an error message or 1 and the corrected size
sub compute_dnssec_key_size
{
local ($alg, $def, $size) = @_;
local ($min, $max, $factor) = &dnssec_size_range($alg);
local $rv;
if ($def == 1) {
	# Average
	$rv = int(($max + $min) / 2);
	if ($factor) {
		$rv = int($rv / $factor) * $factor;
		}
	}
elsif ($def == 2) {
	# Max allowed
	$rv = $max;
	}
else {
	$size =~ /^\d+$/ && $size >= $min && $size <= $max ||
		return (0, &text('zonekey_esize', $min, $max));
	if ($factor && $size % $factor) {
		return (0, &text('zonekey_efactor', $factor));
		}
	$rv = $size;
	}
return (1, $rv);
}

# get_dnssec_cron_job()
# Returns the cron job object for re-signing DNSSEC domains
sub get_dnssec_cron_job
{
&foreign_require("cron", "cron-lib.pl");
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} =~ /^\Q$dnssec_cron_cmd\E/ }
		    &cron::list_cron_jobs();
return $job;
}

# refresh_nscd()
# Signal nscd to re-read cached DNS info
sub refresh_nscd
{
if (&find_byname("nscd")) {
	if (&has_command("nscd")) {
		# Use nscd -i to reload
		&system_logged("nscd -i hosts >/dev/null 2>&1 </dev/null");
		}
	else {
		# Send HUP signal
		&kill_byname_logged("nscd", "HUP");
		}
	}
}

# transfer_slave_records(zone, &masters, [file], [source-ip, [source-port]])
# Transfer DNS records from a master into some file. Returns a map from master
# IPs to errors.
sub transfer_slave_records
{
my ($dom, $masters, $file, $source, $sourceport) = @_;
my $sourcearg;
if ($source && $source ne "*") {
	$sourcearg = "-t ".$source;
	if ($sourceport) {
		$sourcearg .= "#".$sourceport;
		}
	}
my %rv;
my $dig = &has_command("dig");
foreach my $ip (@$masters) {
	if (!$dig) {
		$rv{$ip} = "Missing dig command";
		}
	else {
		my $out = &backquote_logged(
			"$dig IN $sourcearg AXFR ".quotemeta($dom).
			" \@".quotemeta($ip)." 2>&1");
		if ($? || $out =~ /Transfer\s+failed/) {
			$rv{$ip} = $out;
			}
		elsif (!$out) {
			$rv{$ip} = "No records transferred";
			}
		else {
			if ($file) {
				&open_tempfile(XFER, ">$file");
				&print_tempfile(XFER, $out);
				&close_tempfile(XFER);
				$file = undef;
				}
			}
		}
	}
return \%rv;
}

sub get_dnssectools_config
{ 
	&lock_file($config{'dnssectools_conf'});
	my $lref = &read_file_lines($config{'dnssectools_conf'}); 
	my @rv; 
	my $lnum = 0; 
	foreach my $line (@$lref) {
		my ($n, $v) = split(/\s+/, $line, 2); 
		# Do basic sanity checking
		$v =~ /(\S+)/;
		$v = $1;
		if ($n) {
			push(@rv, { 'name' => $n, 'value' => $v, 'line' => $lnum });
		} 
		$lnum++;
	} 
	&flush_file_lines();
	&unlock_file($config{'dnssectools_conf'});
	return \@rv;
}

# save_dnssectools_directive(&config, name, value)
# Save new dnssec-tools configuration values to the configuration file
sub save_dnssectools_directive
{
	local $conf = $_[0];
	local $nv = $_[1];

	&lock_file($config{'dnssectools_conf'});
	my $lref = &read_file_lines($config{'dnssectools_conf'});
	
	foreach my $n (keys %$nv) {
		my $old = &find($n, $conf);
		if ($old) {
			$lref->[$old->{'line'}] = "$n $$nv{$n}";
		}
		else {
		 	push(@$lref, "$n $$nv{$n}");
		}
	}

	&flush_file_lines();
	&unlock_file($config{'dnssectools_conf'});
}

# list_dnssec_dne()
# return a list containing the two DNSSEC mechanisms used for
# proving non-existance
sub list_dnssec_dne
{
	return ("NSEC", "NSEC3");
}

# list_dnssec_dshash()
# return a list containing the different DS record hash types 
sub list_dnssec_dshash
{
	return ("SHA1", "SHA256"); 
}

# schedule_dnssec_cronjob()
# schedule a cron job to handle periodic resign operations 
sub schedule_dnssec_cronjob
{
	my $job;
	my $period = $config{'dnssec_period'} || 21;

	# Create or delete the cron job
	$job = &get_dnssec_cron_job();
	if (!$job) {
		# Turn on cron job
		$job = {'user' => 'root',
			'active' => 1,
			'command' => $dnssec_cron_cmd,
			'mins' => int(rand()*60),
			'hours' => int(rand()*24),
			'days' => '*',
			'months' => '*',
			'weekdays' => '*' };

		&lock_file(&cron::cron_file($job));
		&cron::create_cron_job($job);
		&unlock_file(&cron::cron_file($job));
	}


	&cron::create_wrapper($dnssec_cron_cmd, $module_name, "resign.pl");

	&lock_file($module_config_file);
	$config{'dnssec_period'} = $in{'period'};
	&save_module_config();
	&unlock_file($module_config_file);
}

# dt_sign_zone(zone, nsec3) 
# Replaces a zone's file with one containing signed records.
sub dt_sign_zone
{
	local ($zone, $nsec3) = @_;
	local @recs;

	local $z = &get_zone_file($zone);
	local $d = $zone->{'name'};
	local $z_chroot = &make_chroot($z);
	local $k_chroot = $z_chroot.".krf";
	local $usz = $z_chroot.".webmin-unsigned";
	local $cmd;
	local $out;

	if ((($zonesigner=dt_cmdpath('zonesigner')) eq '')) {
		return $text{'dt_zone_enocmd'};
	}
	if ($nsec3 == 1) {
		$nsec3param = " -usensec3 -nsec3optout ";
	} else {
		$nsec3param = "";
	}

	&lock_file($z_chroot);

	rollrec_lock();

	# Remove DNSSEC records and save the unsigned zone file
	@recs = &read_zone_file($z, $dom);
	for(my $i=$#recs; $i>=0; $i--) {
		if ($recs[$i]->{'type'} eq 'NSEC' ||
			$recs[$i]->{'type'} eq 'NSEC3' ||
			$recs[$i]->{'type'} eq 'NSEC3PARAM' ||
			$recs[$i]->{'type'} eq 'RRSIG' ||
			$recs[$i]->{'type'} eq 'DNSKEY') {
				&delete_record($z, $recs[$i]);
		}   
	}
	&copy_source_dest($z_chroot, $usz); 

	$cmd = "$zonesigner $nsec3param".
				" -genkeys ".
				" -kskdirectory ".quotemeta($config{"dnssectools_keydir"}).
				" -zskdirectory ".quotemeta($config{"dnssectools_keydir"}).
				" -dsdir ".quotemeta($config{"dnssectools_keydir"}).
				" -zone ".quotemeta($d).
				" -krfile ".quotemeta($k_chroot).
				" ".quotemeta($usz)." ".quotemeta($z_chroot);

	$out = &backquote_logged("$cmd 2>&1");

	if ($?) {
		rollrec_unlock();
		&unlock_file($z_chroot);
		return $out;
	}

	# Create rollrec entry for zone
	$rrfile = $config{"dnssectools_rollrec"};
	&lock_file($rrfile);
	open(OUT,">> $rrfile") || &error($text{'dt_zone_errfopen'});
	print OUT "roll \"$d\"\n";
	print OUT " zonename    \"$d\"\n";
	print OUT " zonefile    \"$z_chroot\"\n";
	print OUT " keyrec      \"$k_chroot\"\n";
	print OUT " kskphase    \"0\"\n";
	print OUT " zskphase    \"0\"\n";
	print OUT " ksk_rolldate    \" \"\n";
	print OUT " ksk_rollsecs    \"0\"\n";
	print OUT " zsk_rolldate    \" \"\n";
	print OUT " zsk_rollsecs    \"0\"\n";
	print OUT " maxttl      \"0\"\n";
	print OUT " phasestart  \"new\"\n";
	&unlock_file($rrfile);

	# Setup zone to be auto-resigned every 30 days
	&schedule_dnssec_cronjob();

	rollrec_unlock();
	&unlock_file($z_chroot);
	
	&dt_rollerd_restart();
	&restart_bind();
	return undef;
}

# dt_resign_zone(zone-name, zonefile, krfile, threshold) 
# Replaces a zone's file with one containing signed records.
sub dt_resign_zone
{
	local ($d, $z, $k, $t) = @_;

	local $zonesigner;
	local @recs;
	local $cmd;
	local $out;
	local $threshold = "";
	local $z_chroot = &make_chroot($z);
	local $usz = $z_chroot.".webmin-unsigned";

	if ((($zonesigner=dt_cmdpath('zonesigner')) eq '')) {
		return $text{'dt_zone_enocmd'};
	}

	rollrec_lock();

	# Remove DNSSEC records and save the unsigned zone file
	@recs = &read_zone_file($z, $dom);
	for(my $i=$#recs; $i>=0; $i--) {
		if ($recs[$i]->{'type'} eq 'NSEC' ||
			$recs[$i]->{'type'} eq 'NSEC3' ||
			$recs[$i]->{'type'} eq 'NSEC3PARAM' ||
			$recs[$i]->{'type'} eq 'RRSIG' ||
			$recs[$i]->{'type'} eq 'DNSKEY') {
				&delete_record($z, $recs[$i]);
		}   
	}
	&copy_source_dest($z_chroot, $usz); 

	if ($t > 0) {
		$threshold = "-threshold ".quotemeta("-$t"."d"." "); 
	}

	$cmd = "$zonesigner -verbose -verbose".
		" -kskdirectory ".quotemeta($config{"dnssectools_keydir"}).
		" -zskdirectory ".quotemeta($config{"dnssectools_keydir"}).
		" -dsdir ".quotemeta($config{"dnssectools_keydir"}).
		" -zone ".quotemeta($d).
		" -krfile ".quotemeta(&make_chroot($k)).
		" ".$threshold.
		" ".quotemeta($usz)." ".quotemeta($z_chroot);
	$out = &backquote_logged("$cmd 2>&1");

	rollrec_unlock();

	return $out if ($?);

	&restart_zone($d);

	return undef;
}

# dt_zskroll_zone(zone-name)
# Initates a zsk rollover operation for the zone 
sub dt_zskroll_zone
{
	local ($d) = @_;
	if (!rollmgr_sendcmd(CHANNEL_WAIT,ROLLCMD_ROLLZSK,$d)) {
		return $text{'dt_zone_erollctl'};
	}
	
	return undef;
}

# dt_kskroll_zone(zone-name)
# Initates a ksk rollover operation for the zone 
sub dt_kskroll_zone
{
	local ($d) = @_;
	if (!rollmgr_sendcmd(CHANNEL_WAIT,ROLLCMD_ROLLKSK,$d)) {
		return $text{'dt_zone_erollctl'};
	}
	
	return undef;
}

# dt_notify_parentzone(zone-name)
# Notifies rollerd that the new DS record has been published in the parent zone 
sub dt_notify_parentzone
{
	local ($d) = @_;
	if (!rollmgr_sendcmd(CHANNEL_WAIT,ROLLCMD_DSPUB,$d)) {
		return $text{'dt_zone_erollctl'};
	}
	
	return undef;
}

# dt_rollerd_restart()
# Restart the rollerd daemon 
sub dt_rollerd_restart
{
	local $rollerd;
	local $r;
	local $cmd;
	local $out;

	if ((($rollerd=dt_cmdpath('rollerd')) eq '')) {
		return $text{'dt_zone_enocmd'};
	}
	rollmgr_halt();
	$r = $config{"dnssectools_rollrec"};   
	$cmd = "$rollerd -rrfile ".quotemeta($r);
	&execute_command($cmd);
	return undef;
}

# dt_genkrf()
# Generate a new krf file for the zone
sub dt_genkrf
{
	local ($zone, $z_chroot, $k_chroot) = @_;
	local $dom = $zone->{'name'};
	local @keys = &get_dnssec_key($zone);
	local $usz = $z_chroot.".webmin-unsigned";
	local $zskcur = "";
	local $kskcur = "";
	local $cmd;
	local $out;

	local $oldkeydir = &get_keys_dir($zone);
	local $keydir = $config{"dnssectools_keydir"};
	mkdir($keydir);

	foreach my $key (@keys) {
		foreach my $f ('publicfile', 'privatefile') {
			# Identify if this is a zsk or a ksk
			$key->{$f} =~ /(K\Q$dom\E\.\+\d+\+\d+)/;
			if ($key->{'ksk'}) {
				$kskcur = $1; 
			} else {
				$zskcur = $1; 
			}
			&copy_source_dest($key->{$f}, $keydir);
			&unlink_file($key->{$f});
		}
	}

	if (($zskcur eq "") || ($kskcur eq "")) {
		return &text('dt_zone_enokey', $dom);
	}

	# Remove the older dsset file 
	if ($oldkeydir) {
		&unlink_file($oldkeydir."/"."dsset-".$dom.".");
	}

	if ((($genkrf=dt_cmdpath('genkrf')) eq '')) {
		return $text{'dt_zone_enocmd'};
	}
	$cmd = "$genkrf".
				" -zone ".quotemeta($dom).
				" -krfile ".quotemeta($k_chroot).
				" -zskcur=".quotemeta($zskcur).
				" -kskcur=".quotemeta($kskcur).
				" -zskdir ".quotemeta($keydir).
				" -kskdir ".quotemeta($keydir).
				" ".quotemeta($usz)." ".quotemeta($z_chroot);

	$out = &backquote_logged("$cmd 2>&1");

	return $out if ($?);
	return undef;
}


# dt_delete_dnssec_state()
# Delete all DNSSEC-Tools meta-data for a given zone 
sub dt_delete_dnssec_state
{
	local ($zone) = @_;

	local $z = &get_zone_file($zone);
	local $dom = $zone->{'members'} ? $zone->{'values'}->[0] : $zone->{'name'};
	local $z_chroot = &make_chroot($z);
	local $k_chroot = $z_chroot.".krf";
	local $usz = $z_chroot.".webmin-unsigned";
	local @recs;

	if (&check_if_dnssec_tools_managed($dom)) {
		rollrec_lock();

		#remove entry from rollrec file
		&lock_file($config{"dnssectools_rollrec"});
		rollrec_read($config{"dnssectools_rollrec"});
		rollrec_del($dom);
		rollrec_close();
		&unlock_file($config{"dnssectools_rollrec"});

		&lock_file($z_chroot);

		# remove key and krf files
		keyrec_read($k_chroot);
		@kskpaths = keyrec_keypaths($dom, "all");
   	foreach (@kskpaths) {
			# remove any trailing ".key"
			s/(.*).key$/\1/;
			&unlink_file("$_.key");
			&unlink_file("$_.private");
		}
		keyrec_close();
		&unlink_file($k_chroot);
		&unlink_file($usz);

		# Delete dsset
		&unlink_file($config{"dnssectools_keydir"}."/"."dsset-".$dom.".");

		# remove DNSSEC records from zonefile
		@recs = &read_zone_file($z, $dom);
		for(my $i=$#recs; $i>=0; $i--) {
			if ($recs[$i]->{'type'} eq 'NSEC' ||
				$recs[$i]->{'type'} eq 'NSEC3' ||
				$recs[$i]->{'type'} eq 'NSEC3PARAM' ||
				$recs[$i]->{'type'} eq 'RRSIG' ||
				$recs[$i]->{'type'} eq 'DNSKEY') {
			   	    &delete_record($z, $recs[$i]);
			}   
		}
		&bump_soa_record($z, \@recs);
	
		&unlock_file($z_chroot);
		rollrec_unlock();

		&dt_rollerd_restart(); 
		&restart_bind();
	}

	return undef;
}

1;

