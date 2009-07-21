# dnsadmin common functions

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("bind8", "bind8-lib.pl");
do "$bind8::module_root_directory/records-lib.pl";

# mapping between record types and names
%code_map = ("A", "Address", "NS", "Name Server", "CNAME", "Name Alias",
	     "MX", "Mail Server", "HINFO", "Host Information", "TXT", "Text",
	     "WKS", "Well Known Service", "RP", "Responsible Person",
	     "PTR", "Reverse Address");

# get_config()
# Returns the current bind4 configuration
sub get_config
{
if (!@get_config_cache) {
        @get_config_cache = &read_config_file($config{'named_boot_file'});
        }
return \@get_config_cache;
}

# read_config_file(filename, [dont expand includes])
# Read and parse a BIND4 format config file
sub read_config_file
{
# read primary config file
local $lnum = 0;
local $n = 0;
local($i, $j, @rv);
open(CONF, $_[0]);
while(<CONF>) {
	s/\r|\n//g;	# strip newline
	s/;.*$//g;	# strip comments
	s/\s+$//g;	# strip trailing spaces
	if (/^(\S+)\s*(.*)$/) {
		local(%dir);
		$dir{'name'} = $1;
		$dir{'value'} = $2;
		$dir{'values'} = [ split(/\s+/, $2) ];
		$dir{'line'} = $lnum;
		$dir{'file'} = $_[0];
		$dir{'index'} = $n++;
		push(@rv, \%dir);
		}
	$lnum++;
	}
close(CONF);

# expand include directives
for($i=0; $i<@rv; $i++) {
	if ($rv[$i]->{'name'} eq "include" && !$_[1]) {
		# replace this include directive
		$inc = $rv[$i]->{'value'};
		if ($inc !~ /^\//) {
			$inc = &base_directory(\@rv)."/".$inc;
			}
		@inc = &read_config_file($inc, 1);

		# update index of included structures
		for($j=0; $j<@inc; $j++) {
			$inc[$j]->{'index'} += $rv[$i]->{'index'};
			}

		# update index of directives after include
		for($j=$i+1; $j<@rv; $j++) {
			$rv[$j]->{'index'} += scalar(@inc) - 1;
			}

		splice(@rv, $i--, 1, @inc);
		}
	}
return @rv;
}

# find_config(name, &array)
sub find_config
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

# base_directory([&config])
# Returns the base directory for include and domain files
sub base_directory
{
$conf = @_ ? $_[0] : &get_config();
$dir = &find_config("directory", $conf);
if ($dir) { return $dir->{'values'}->[0]; }
$config{'named_boot_file'} =~ /^(.*)\/[^\/]+$/;
return $1;
}

# create_zone(&details)
sub create_zone
{
local(@v) = @{$_[0]->{'values'}};
open(ZONE, ">> $config{'named_boot_file'}");
print ZONE $_[0]->{'name'}.(@v ? " ".join(" ", @v) : "")."\n";
close(ZONE);
}

# modify_zone(&old, &details)
sub modify_zone
{
local(@v) = @{$_[1]->{'values'}};
&replace_file_line($_[0]->{'file'}, $_[0]->{'line'},
		   $_[1]->{'name'}.(@v ? " ".join(" ", @v) : "")."\n");
}

# delete_zone(&old)
sub delete_zone
{
&replace_file_line($_[0]->{'file'}, $_[0]->{'line'});
}

# find_reverse(address)
# Returns the zone and record structures for the PTR record for some address
sub find_reverse
{
local($conf, @zl, $rev, $z, $revconf, $revfile, $revrec, @revrecs, @octs, $rr);

# find reverse domain
$conf = &get_config();
@zl = &find_config("primary", $conf);
@octs = split(/\./, $_[0]);
for($i=2; $i>=0; $i--) {
	$rev = &ip_to_arpa(join('.', @octs[0..$i]));
	$rev =~ s/\.$//g;
	foreach $z (@zl) {
		if (lc($z->{'values'}->[0]) eq $rev) {
			# found the reverse master domain
			$revconf = $z;
			last;
			}
		}
	}

# find reverse record
if ($revconf) {
        $revfile = $revconf->{'values'}->[1];
        @revrecs = &read_zone_file($revfile, $revconf->{'values'}->[0]);
        local $addr = &ip_to_arpa($_[0]);
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

# find_forward(address)
# Returns the zone and record structures for the A record for some address
sub find_forward
{
local($conf, @zl, $fwd, $z, $fwdconf, $fwdfile, $fwdrec, @fwdrecs, @octs, $rr);

# find reverse domain
local $host = $_[0]; $host =~ s/\.$//;
$conf = &get_config();
@zl = &find_config("primary", $conf);
local @parts = split(/\./, $host);
DOMAIN: for($i=1; $i<@parts; $i++) {
	local $fwd = join(".", @parts[$i .. @parts-1]);
	foreach $z (@zl) {
		local $typed;
		if (lc($z->{'values'}->[0]) eq $fwd) {
			# Found the forward master!
			$fwdconf = $z;
			last DOMAIN;
			}
		}
	}

# find forward record
if ($fwdconf) {
        $fwdfile = $fwdconf->{'values'}->[1];
        local @fwdrecs = &read_zone_file($fwdfile, $fwdconf->{'values'}->[0]);
        foreach $fr (@fwdrecs) {
                if ($fr->{'type'} eq 'A' &&
                    $fr->{'name'} eq $_[0]) {
                        # found the forward record
                        $fwdrec = $fr;
                        last;
                        }
                }
        }
return ($fwdconf, $fwdfile, $fwdrec);
}

# can_edit_zone(&access, zone)
sub can_edit_zone
{
local %zcan;
return 1 if ($access{'zones'} eq '*');
foreach (split(/\s+/, $access{'zones'})) {
        return 1 if ($_ eq $_[1]);
        }
return 0;
}

sub make_chroot
{
return $_[0];
}

1;

