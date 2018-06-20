# Functions for managing BIND 4 and 8/9 records files
use strict;
use warnings;
no warnings 'redefine';

# Globals from Webmin or bind8-lib.pl
our (%config, %text, %in);
our $module_config_directory;
our $bind_version;
our $ipv6revzone = $config{'ipv6_mode'} ? "ip6.arpa" : "ip6.int";

# read_zone_file(file, origin, [previous], [only-soa], [no-chroot])
# Reads a DNS zone file and returns a data structure of records. The origin
# must be a domain without the trailing dot, or just .
sub read_zone_file
{
my ($file, $line, @tok, @lnum, @coms,
      @rv, $origin, @inc, @oset, $comment);
$origin = $_[1];
if (&has_ndc() == 2) {
	# Flush the zone file
	&backquote_command(
		$config{'rndc_cmd'}.
		($config{'rndc_conf'} ? " -c $config{'rndc_conf'}" : "").
		" sync ".quotemeta($origin)." 2>&1 </dev/null");
	}
if ($origin ne ".") {
	# Remove trailing dots in origin name, as they are added automatically
	# in the code below.
	$origin =~ s/\.*$//;
	}
$file = &absolute_path($_[0]);
my $rootfile = $_[4] ? $file : &make_chroot($file);
my $FILE;
if (&is_raw_format_records($rootfile)) {
	# Convert from raw format first
	&has_command("named-compilezone") ||
		&error("Zone file $rootfile is in raw format, but the ".
		       "named-compilezone command is not installed");
	open($FILE, "named-compilezone -f raw -F text -o - $origin $rootfile |");
	}
else {
	# Can read text format records directly
	open($FILE, "<", $rootfile);
	}
my $lnum = 0;
my ($gotsoa, $aftersoa) = (0, 0);
while($line = <$FILE>) {
	my ($glen, $merged_2, $merge);
	$glen = 0;
	# strip comments (# is not a valid comment separator here!)
	$line =~ s/\r|\n//g;
	# parsing splited into separate cases to fasten it
	if ($line =~ /;/ &&
	    ($line =~ /[^\\]/ &&
	     $line =~ /^((?:[^;\"]+|\"\"|(?:\"(?:[^\"]*)\"))*);(.*)/) ||
	    ($line =~ /[^\"]/ &&
	     $line =~ /^((?:[^;\\]|\\.)*);(.*)/) ||
	     # expresion below is the most general, but very slow 
	     # if ";" is quoted somewhere
	     $line =~ /^((?:(?:[^;\"\\]|\\.)+|(?:\"(?:[^\"\\]|\\.)*\"))*);(.*)/) {
		$comment = $2;
		$line = $1;
		if ($line =~ /^[^"]*"[^"]*$/) {
			# Line has only one ", meaning that a ; in the middle
			# of a quoted string broke it! Fix up
			$line .= ";".$comment;
			$comment = "";
			}
		}
	else { 
		$comment = "";
		}

	# split line into tokens
	my $oset = 0;
	while(1) {
		$merge = 1;
		my $base_oset = 0;
		if ($line =~ /^(\s*)\"((?:[^\"\\]|\\.)*)\"(.*)/ ||
		    $line =~ /^(\s*)((?:[^\s\(\)\"\\]|\\.)+)(.*)/ ||
		    ($merge = 0) || $line =~ /^(\s*)([\(\)])(.*)/) {
			if ($glen == 0) {
				$oset += length($1);
				}
			else {
				$glen += length($1);
				}
			$glen += length($2);
			$merged_2 .= $2;
			$line = $3;
			if (!$merge || $line =~ /^([\s\(\)]|$)/) {
				push(@tok, $merged_2); push(@lnum, $lnum);
				push(@oset, $oset);
				push(@coms, $comment); $comment = "";

				# Check if we have the SOA
				if (uc($merged_2) eq "SOA") {
					$gotsoa = 1;
					}
				elsif ($gotsoa) {
					$aftersoa++;
					}

				$merged_2 = "";
				$oset += $glen;
				$glen = 0;
				}
			}
		else { last; }
		}
	$lnum++;

	# Check if we have a complete SOA record
	if ($aftersoa > 10 && $_[3]) {
		last;
		}
	}
close($FILE);

# parse into data structures
my $i = 0; my $num = 0;
while($i < @tok) {
	if ($tok[$i] =~ /^\$origin$/i) {
		# $ORIGIN directive (may be relative or absolute)
		if ($tok[$i+1] =~ /^(\S*)\.$/) {
			$origin = $1 ? $1 : ".";
			}
		elsif ($origin eq ".") { $origin = $tok[$i+1]; }
		else { $origin = "$tok[$i+1].$origin"; }
		$i += 2;
		}
	elsif ($tok[$i] =~ /^\$include$/i) {
		# including another file
		if ($lnum[$i+1] == $lnum[$i+2]) {
			# $INCLUDE zonefile origin
			my $inc_origin;
			if ($tok[$i+2] =~ /^(\S+)\.$/) {
				$inc_origin = $1 ? $1 : ".";
				}
			elsif ($origin eq ".") { $inc_origin = $tok[$i+2]; }
			else { $inc_origin = "$tok[$i+2].$origin"; }
			@inc = &read_zone_file($tok[$i+1], $inc_origin,
					       @rv ? $rv[$#rv] : undef);
			$i += 3;
			}
		else {
			# $INCLUDE zonefile
			@inc = &read_zone_file($tok[$i+1], $origin,
					       @rv ? $rv[$#rv] : undef);
			$i += 2;
			}
		foreach my $j (@inc) { $j->{'num'} = $num++; }
		push(@rv, @inc);
		}
	elsif ($tok[$i] =~ /^\$generate$/i) {
		# a generate directive .. add it as a special record
		my $gen = { 'file' => $file,
			    'rootfile' => $rootfile,
			    'comment' => $coms[$i],
			    'line' => $lnum[$i],
			    'num' => $num++,
			    'type' => '' };
		my @gv;
		while($lnum[++$i] == $gen->{'line'}) {
			push(@gv, $tok[$i]);
			}
		$gen->{'generate'} = \@gv;
		push(@rv, $gen);
		}
	elsif ($tok[$i] =~ /^\$ttl$/i) {
		# a ttl directive
		$i++;
		my $defttl = { 'file' => $file,
			       'rootfile' => $rootfile,
		      	       'line' => $lnum[$i],
		               'num' => $num++,
		       	       'defttl' => $tok[$i++],
			       'type' => '' };
		push(@rv, $defttl);
		}
	elsif ($tok[$i] =~ /^\$(\S+)/i) {
		# some other special directive
		my $ln = $lnum[$i];
		while($lnum[$i] == $ln) {
			$i++;
			}
		}
	else {
		# A DNS record line
		my(%dir, @values, $l);
		$dir{'line'} = $lnum[$i];
		$dir{'file'} = $file;
		$dir{'rootfile'} = $rootfile;
		$dir{'comment'} = $coms[$i];
		if ($tok[$i] =~ /^(in|hs)$/i && $oset[$i] > 0) {
			# starting with a class
			$dir{'class'} = uc($tok[$i]);
			$i++;
			}
		elsif ($tok[$i] =~ /^\d/ && $tok[$i] !~ /in-addr/i &&
		       $oset[$i] > 0 && $tok[$i+1] =~ /^(in|hs)$/i) {
			# starting with a TTL and class
			$dir{'ttl'} = $tok[$i];
			$dir{'class'} = uc($tok[$i+1]);
			$i += 2;
			}
		elsif ($tok[$i+1] =~ /^(in|hs)$/i) {
			# starting with a name and class
			$dir{'name'} = $tok[$i];
			$dir{'class'} = uc($tok[$i+1]);
			$i += 2;
			}
		elsif ($oset[$i] > 0 && $tok[$i] =~ /^\d+/) {
			# starting with just a ttl
			$dir{'ttl'} = $tok[$i];
			$dir{'class'} = "IN";
			$i++;
			}
		elsif ($oset[$i] > 0) {
			# starting with nothing
			$dir{'class'} = "IN";
			}
		elsif ($tok[$i+1] =~ /^\d/ && $tok[$i+2] =~ /^(in|hs)$/i) {
			# starting with a name, ttl and class
			$dir{'name'} = $tok[$i];
			$dir{'ttl'} = $tok[$i+1];
			$dir{'class'} = uc($tok[$i+2]);
			$i += 3;
			}
                elsif ($tok[$i+1] =~ /^\d/) {
                        # starting with a name and ttl
                        $dir{'name'} = $tok[$i];
                        $dir{'ttl'} = $tok[$i+1];
                        $dir{'class'} = "IN";
                        $i += 2;
                        }
		else {
			# starting with a name
			$dir{'name'} = $tok[$i];
			$dir{'class'} = "IN";
			$i++;
			}
		if (!defined($dir{'name'}) || $dir{'name'} eq '') {
			my $prv;
			# Name comes from previous record
			for(my $p=$#rv; $p>=0; $p--) {
				$prv = $rv[$p];
				last if ($prv->{'name'});
				}
			$prv ||= $_[2];
			$prv || &error(&text('efirst', $lnum[$i]+1, $file));
			$dir{'name'} = $prv->{'name'};
			$dir{'realname'} = $prv->{'realname'};
			}
		else {
			$dir{'realname'} = $dir{'name'};
			}
		$dir{'type'} = uc($tok[$i++]);

		# read values until end of line, unless a ( is found, in which
		# case read till the )
		$l = $lnum[$i];
		while($i < @tok && $lnum[$i] == $l) {
			if ($tok[$i] eq "(") {
				my $olnum = $lnum[$i];
				while($tok[++$i] ne ")") {
					push(@values, $tok[$i]);
					if ($i >= @tok) {
						&error("No ending ) found for ".
						       "( starting at $olnum");
						}
					}
				$i++; # skip )
				last;
				}
			push(@values, $tok[$i++]);
			}
		$dir{'values'} = \@values;
		$dir{'eline'} = $lnum[$i-1];

		# Work out canonical form, and maybe use it
		my $canon = $dir{'name'};
		if ($canon eq "@") {
			$canon = $origin eq "." ? "." : "$origin.";
			}
		elsif ($canon !~ /\.$/) {
			$canon .= $origin eq "." ? "." : ".$origin.";
			}
		if (!$config{'short_names'}) {
			$dir{'name'} = $canon;
			}
		$dir{'canon'} = $canon;
		$dir{'num'} = $num++;

		# If this is an SPF record .. adjust the class
		my $spf;
		if ($dir{'type'} eq 'TXT' &&
		    !$config{'spf_record'} &&
		    ($spf=&parse_spf(@{$dir{'values'}}))) {
			if (!$spf->{'other'} || !@{$spf->{'other'}}) {
				$dir{'type'} = 'SPF';
				}
			}

		# If this is a DMARC record .. adjust the class
		my $dmarc;
		if ($dir{'type'} eq 'TXT' &&
                    ($dmarc=&parse_dmarc(@{$dir{'values'}}))) {
                        if (!$dmarc->{'other'} || !@{$dmarc->{'other'}}) {
                                $dir{'type'} = 'DMARC';
                                }
                        }

		push(@rv, \%dir);

		# Stop processing if this was an SOA record
		if ($dir{'type'} eq 'SOA' && $_[3]) {
			last;
			}
		}
	}
return @rv;
}

# create_record(file, name, ttl, class, type, values, comment)
# Add a new record of some type to some zone file
sub create_record
{
my $fn = &make_chroot(&absolute_path($_[0]));
&is_raw_format_records($fn) && &error("Raw format zone files cannot be edited");
my $lref = &read_file_lines($fn);
push(@$lref, &make_record(@_[1..$#_]));
&flush_file_lines($fn);
}

# modify_record(file, &old, name, ttl, class, type, values, comment)
# Updates an existing record in some zone file
sub modify_record
{
my $fn = &make_chroot(&absolute_path($_[0]));
&is_raw_format_records($fn) && &error("Raw format zone files cannot be edited");
my $lref = &read_file_lines($fn);
my $lines = $_[1]->{'eline'} - $_[1]->{'line'} + 1;
splice(@$lref, $_[1]->{'line'}, $lines, &make_record(@_[2..$#_]));
&flush_file_lines($fn);
}

# delete_record(file, &old)
# Deletes a record in some zone file
sub delete_record
{
my $fn = &make_chroot(&absolute_path($_[0]));
&is_raw_format_records($fn) && &error("Raw format zone files cannot be edited");
my $lref = &read_file_lines($fn);
my $lines = $_[1]->{'eline'} - $_[1]->{'line'} + 1;
splice(@$lref, $_[1]->{'line'}, $lines);
&flush_file_lines($fn);
}

# create_generator(file, range, lhs, type, rhs, [comment])
# Add a new $generate line to some zone file
sub create_generator
{
my $f = &make_chroot(&absolute_path($_[0]));
my $lref = &read_file_lines($f);
push(@$lref, join(" ", '$generate', @_[1..4]).
	     ($_[5] ? " ;$_[5]" : ""));
&flush_file_lines($f);
}

# modify_generator(file, &old, range, lhs, type, rhs, [comment])
# Updates an existing $generate line in some zone file
sub modify_generator
{
my $f = &make_chroot(&absolute_path($_[0]));
my $lref = &read_file_lines($f);
$lref->[$_[1]->{'line'}] = join(" ", '$generate', @_[2..5]).
			   ($_[6] ? " ;$_[6]" : "");
&flush_file_lines($f);
}

# delete_generator(file, &old)
# Deletes a $generate line in some zone file
sub delete_generator
{
my $f = &make_chroot(&absolute_path($_[0]));
my $lref = &read_file_lines($f);
splice(@$lref, $_[1]->{'line'}, 1);
&flush_file_lines($f);
}

# create_defttl(file, value)
# Adds a $ttl line to a records file
sub create_defttl
{
my $f = &make_chroot(&absolute_path($_[0]));
my $lref = &read_file_lines($f);
splice(@$lref, 0, 0, "\$ttl $_[1]");
&flush_file_lines($f);
}

# modify_defttl(file, &old, value)
# Updates the $ttl line with a new value
sub modify_defttl
{
my $f = &make_chroot(&absolute_path($_[0]));
my $lref = &read_file_lines($f);
$lref->[$_[1]->{'line'}] = "\$ttl $_[2]";
&flush_file_lines($f);
}

# delete_defttl(file, &old)
# Removes the $ttl line from a records file
sub delete_defttl
{
my $f = &make_chroot(&absolute_path($_[0]));
my $lref = &read_file_lines($f);
splice(@$lref, $_[1]->{'line'}, 1);
&flush_file_lines($f);
}

# make_record(name, ttl, class, type, values, comment)
# Returns a string for some zone record
sub make_record
{
my ($name, $ttl, $cls, $type, $values, $cmt) = @_;
$type = $type eq "SPF" && !$config{'spf_record'} ? "TXT" :
        $type eq "DMARC" ? "TXT" : $type;
return $name . ($ttl ? "\t".$ttl : "") . "\t" . $cls . "\t" . $type ."\t" .
       $values . ($cmt ? "\t;$cmt" : "");
}

# bump_soa_record(file, &records)
# Increase the serial number in some SOA record by 1
sub bump_soa_record
{
my($r, $v, $vals);
for(my $i=0; $i<@{$_[1]}; $i++) {
	$r = $_[1]->[$i];
	if ($r->{'type'} eq "SOA") {
		$v = $r->{'values'};
		# already set serial if no acl allow it to update or update
		# is disabled
		my $serial = $v->[2];
		if ($config{'updserial_on'}) {
			# automatically handle serial numbers ?
			$serial = &compute_serial($v->[2]);
			}
		$vals = "$v->[0] $v->[1] (\n\t\t\t$serial\n\t\t\t$v->[3]\n".
			"\t\t\t$v->[4]\n\t\t\t$v->[5]\n\t\t\t$v->[6] )";
		&modify_record($r->{'file'}, $r, $r->{'realname'}, $r->{'ttl'},
				$r->{'class'}, $r->{'type'}, $vals);
		}
	}
}

# date_serial()
# Returns a string like YYYYMMDD
sub date_serial
{
my $now = time();
my @tm = localtime($now);
return sprintf "%4.4d%2.2d%2.2d", $tm[5]+1900, $tm[4]+1, $tm[3];
}

# get_zone_defaults(&hash)
sub get_zone_defaults
{
if (!&read_file("$module_config_directory/zonedef", $_[0])) {
	$_[0]->{'refresh'} = 10800; $_[0]->{'retry'} = 3600;
	$_[0]->{'expiry'} = 604800; $_[0]->{'minimum'} = 38400;
	$_[0]->{'refunit'} = ""; $_[0]->{'retunit'} = "";
	$_[0]->{'expunit'} = ""; $_[0]->{'minunit'} = "";
	}
else {
	$_[0]->{'refunit'} = $1 if ($_[0]->{'refresh'} =~ s/([^0-9])$//);
	$_[0]->{'retunit'} = $1 if ($_[0]->{'retry'} =~ s/([^0-9])$//);
	$_[0]->{'expunit'} = $1 if ($_[0]->{'expiry'} =~ s/([^0-9])$//);
	$_[0]->{'minunit'} = $1 if ($_[0]->{'minimum'} =~ s/([^0-9])$//);
	}
}

# save_zone_defaults(&array)
sub save_zone_defaults
{
&write_file("$module_config_directory/zonedef", $_[0]);
}

# allowed_zone_file(&access, file)
sub allowed_zone_file
{
return 0 if ($_[1] =~ /\.\./);
return 0 if (-l $_[1] && !&allowed_zone_file($_[0], readlink($_[1])));
my $l = length($_[0]->{'dir'});
return length($_[1]) > $l && substr($_[1], 0, $l) eq $_[0]->{'dir'};
}

# sort_records(list)
sub sort_records
{
return @_ if (!@_);
my $s = $in{'sort'} ? $in{'sort'} : $config{'records_order'};
if ($s == 1) {
	# Sort by name
	if ($_[0]->{'type'} eq "PTR") {
		my @rv = sort ptr_sort_func @_; 
		return @rv;
		}
	else {
		my @rv = sort { $a->{'name'} cmp $b->{'name'} } @_;
		return @rv;
		}
	}
elsif ($s == 2) {
	# Sort by value
	if ($_[0]->{'type'} eq "A") {
		my @rv = sort ip_sort_func @_;
		return @rv;
		}
	elsif ($_[0]->{'type'} eq "MX") {
		my @rv = sort { $a->{'values'}->[1] cmp $b->{'values'}->[1] } @_;
		return @rv;
		}
	else {
		my @rv = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @_;
		return @rv;
		}
	}
elsif ($s == 3) {
	# Sort by IP address or by value if there is no IP
	if ($_[0]->{'type'} eq "A") {
		my @rv = sort ip_sort_func @_;
		return @rv;
		}
	elsif ($_[0]->{'type'} eq "PTR") {
		my @rv = sort ptr_sort_func @_;
		return @rv;
		}
	elsif ($_[0]->{'type'} eq "MX") {
		my @rv = sort { $a->{'values'}->[1] cmp $b->{'values'}->[1] } @_;
		return @rv;
		}
	else {
		my @rv = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @_;
		return @rv;
		}
	}
elsif ($s == 4) {
	# Sort by comment
	my @rv = sort { $b->{'comment'} cmp $a->{'comment'} } @_;
	return @rv;
	}
elsif ($s == 5) {
	# Sort by type
	my @rv = sort { $a->{'type'} cmp $b->{'type'} } @_;
	return @rv;
	}
else {
	return @_;
	}
}

sub ptr_sort_func
{
$a->{'name'} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
my ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
$b->{'name'} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
return	$a4 < $4 ? -1 :
	$a4 > $4 ? 1 :
	$a3 < $3 ? -1 :
	$a3 > $3 ? 1 :
	$a2 < $2 ? -1 :
	$a2 > $2 ? 1 :
	$a1 < $1 ? -1 :
	$a1 > $1 ? 1 : 0;
}

sub ip_sort_func
{
$a->{'values'}->[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
my ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
$b->{'values'}->[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
return	$a1 < $1 ? -1 :
	$a1 > $1 ? 1 :
	$a2 < $2 ? -1 :
	$a2 > $2 ? 1 :
	$a3 < $3 ? -1 :
	$a3 > $3 ? 1 :
	$a4 < $4 ? -1 :
	$a4 > $4 ? 1 : 0;
}

# arpa_to_ip(name)
# Converts an address like 4.3.2.1.in-addr.arpa. to 1.2.3.4
sub arpa_to_ip
{
if ($_[0] =~ /^([\d\-\.\/]+)\.in-addr\.arpa/i) {
	return join('.',reverse(split(/\./, $1)));
	}
return $_[0];
}

# ip_to_arpa(address)
# Converts an IP address like 1.2.3.4 to 4.3.2.1.in-addr.arpa.
sub ip_to_arpa
{
if ($_[0] =~ /^([\d\-\.\/]+)$/) {
	return join('.',reverse(split(/\./,$1))).".in-addr.arpa.";
	}
return $_[0];
}

# ip6int_to_net(name)
# Converts an address like a.b.c.d.4.3.2.1.ip6.int. to 1234:dcba::
sub ip6int_to_net
{
my $n;
my $addr = $_[0];
if ($addr =~ /^([\da-f]\.)+$ipv6revzone/i) {
	$addr =~ s/\.$ipv6revzone/\./i;
	$addr = reverse(split(/\./, $addr));
	$addr =~ s/([\w]{4})/$1:/g;
	$n = ($addr =~ s/([\w])/$1/g) * 4;
	$addr =~ s/(\w+)$/$+0000/;
	$addr =~ s/([\w]{4})0+$/$1:/;
	$addr =~ s/$/:/;
	$addr =~ s/:0{1,3}/:/g;
	if ($n > 112) {
		$addr =~ s/::$//;
		$addr =~ s/(:0)+:/::/;
		}
	if ($n < 128) {
		return $addr."/$n";
		}
	return $addr
	}
return $_[0];
}

# net_to_ip6int(address, [bits])
# Converts an IPv6 address like 1234:dcba:: to a.b.c.d.4.3.2.1.ip6.int.
sub net_to_ip6int
{
my $addr = lc($_[0]);
my $n = $_[1] ? $_[1] >> 2 : 0;
if (&check_ip6address($addr)) {
	$addr = reverse(split(/\:/, &expandall_ip6($addr)));
	$addr =~ s/(\w)/$1\./g;
	if ($n > 0) {
		$addr = substr($addr, -2 * $n, 2 * $n);
	}
	$addr = $addr.$ipv6revzone.".";
	}
return $addr;
}

our $uscore = $config{'allow_underscore'} ? "_" : "";
our $star = $config{'allow_wild'} ? "\\*" : "";

# valdnsname(name, wild, origin)
sub valdnsname
{
my($fqdn);
$fqdn = $_[0] !~ /\.$/ ? "$_[0].$_[2]." : $_[0];
if (length($fqdn) > 255) {
	&error(&text('edit_efqdn', $fqdn));
	}
if ($_[0] =~ /[^\.]{64}/) {
	# no label longer than 63 chars
	&error(&text('edit_elabel', $_[0]));
	}
return ((($_[1] && $config{'allow_wild'})
	 ? (($_[0] =~ /^[\*A-Za-z0-9\-\.$uscore]+$/)
	   && ($_[0] !~ /.\*/ || $bind_version >= 9) # "*" can be only the first
						    # char, for bind 8
	   && ($_[0] !~ /\*[^\.]/))	# a "." must always follow "*"
	 : ($_[0] =~ /^[\A-Za-z0-9\-\.$uscore]+$/))
	&& ($_[0] !~ /\.\./)		# no ".." inside
	&& ($_[0] !~ /^\../)		# no "." at the beginning
	&& ($_[0] !~ /^\-/)		# no "-" at the beginning
	&& ($_[0] !~ /\-$/)		# no "-" at the end
	&& ($_[0] !~ /\.\-/)		# no ".-" inside
	&& ($_[0] !~ /\-\./)		# no "-." inside
	&& ($_[0] !~ /\.[0-9]+\.$/));	# last label in FQDN may not be
					# purely numeric
}

# valemail(email)
sub valemail
{
return $_[0] eq "." ||
       $_[0] =~ /^[A-Za-z0-9\.\-]+$/ ||
       $_[0] =~ /(\S*)\@(\S*)/ && 
       &valdnsname($2, 0, ".") && 
       $1 =~ /[a-z][\w\-\.$uscore]+/i;
}

# absolute_path(path)
# If a path does not start with a /, prepend the base directory
sub absolute_path
{
if ($_[0] =~ /^([a-zA-Z]:)?\//) { return $_[0]; }
return &base_directory()."/".$_[0];
}

# parse_spf(text, ...)
# If some text looks like an SPF TXT record, return a parsed hash ref
sub parse_spf
{
my $txt = join(" ", @_);
if ($txt =~ /^v=spf1/) {
	my @w = split(/\s+/, $txt);
	my $spf = { };
	foreach my $w (@w) {
		$w = lc($w);
		if ($w eq "a" || $w eq "mx" || $w eq "ptr") {
			$spf->{$w} = 1;
			}
		elsif ($w =~ /^(a|mx|ip4|ip6|ptr|include|exists):(\S+)$/) {
			push(@{$spf->{"$1:"}}, $2);
			}
		elsif ($w eq "-all") {
			$spf->{'all'} = 3;
			}
		elsif ($w eq "~all") {
			$spf->{'all'} = 2;
			}
		elsif ($w eq "?all") {
			$spf->{'all'} = 1;
			}
		elsif ($w eq "+all" || $w eq "all") {
			$spf->{'all'} = 0;
			}
		elsif ($w eq "v=spf1") {
			# Ignore this
			}
		elsif ($w =~ /^(redirect|exp)=(\S+)$/) {
			# Modifier for domain redirect or expansion
			$spf->{$1} = $2;
			}
		else {
			push(@{$spf->{'other'}}, $w);
			}
		}
	return $spf;
	}
return undef;
}

# join_spf(&spf)
# Converts an SPF record structure to a string, designed to be inserted into
# quotes in a TXT record. If it is longer than 255 bytes, it will be split
# into multiple quoted strings.
sub join_spf
{
my ($spf) = @_;
my @rv = ( "v=spf1" );
foreach my $s ("a", "mx", "ptr") {
	push(@rv, $s) if ($spf->{$s});
	}
foreach my $s ("a", "mx", "ip4", "ip6", "ptr", "include", "exists") {
	if ($spf->{"$s:"}) {
		foreach my $v (@{$spf->{"$s:"}}) {
			push(@rv, "$s:$v");
			}
		}
	}
if ($spf->{'other'}) {
	push(@rv, @{$spf->{'other'}});
	}
foreach my $m ("redirect", "exp") {
	if ($spf->{$m}) {
		push(@rv, $m."=".$spf->{$m});
		}
	}
if ($spf->{'all'} == 3) { push(@rv, "-all"); }
elsif ($spf->{'all'} == 2) { push(@rv, "~all"); }
elsif ($spf->{'all'} == 1) { push(@rv, "?all"); }
elsif ($spf->{'all'} eq '0') { push(@rv, "all"); }
my @rvwords;
my $rvword = "";
while(@rv) {
	my $w = shift(@rv);
	if (length($rvword)+length($w)+1 >= 255) {
		$rvword .= " ";
		push(@rvwords, $rvword);
		$rvword = "";
		}
	$rvword .= " " if ($rvword);
	$rvword .= $w;
	}
push(@rvwords, $rvword);
return join("\" \"", @rvwords);
}

# parse_dmarc(text, ...)
# If some text looks like an DMARC TXT record, return a parsed hash ref
sub parse_dmarc
{
my $txt = join(" ", @_);
if ($txt =~ /^v=dmarc1/i) {
	my @w = split(/;\s*/, $txt);
	my $dmarc = { };
	foreach my $w (@w) {
		$w = lc($w);
		if ($w =~ /^(v|pct|ruf|rua|p|sp|adkim|aspf)=(\S+)$/i) {
			$dmarc->{$1} = $2;
			}
		else {
			push(@{$dmarc->{'other'}}, $w);
			}
		}
	return $dmarc;
	}
return undef;
}

# join_dmarc(&dmarc)
# Converts a DMARC record structure to a string, designed to be inserted into
# quotes in a TXT record. If it is longer than 255 bytes, it will be split
# into multiple quoted strings.
sub join_dmarc
{
my ($dmarc) = @_;
my @rv = ( "v=DMARC1" );
foreach my $s ("pct", "ruf", "rua", "p", "sp", "adkim", "aspf") {
	if ($dmarc->{$s} && $dmarc->{$s} ne '') {
		push(@rv, $s."=".$dmarc->{$s});
		}
	}
if ($dmarc->{'other'}) {
	push(@rv, @{$dmarc->{'other'}});
	}
my @rvwords;
my $rvword = "";
while(@rv) {
	my $w = shift(@rv);
	if (length($rvword)+length($w)+1 >= 255) {
		push(@rvwords, $rvword);
		$rvword = "";
		}
	$rvword .= "; " if ($rvword);
	$rvword .= $w;
	}
push(@rvwords, $rvword);
return join("\" \"", @rvwords);
}

# join_record_values(&record)
# Given the values for a record, joins them into a space-separated string
# with quoting if needed
sub join_record_values
{
my ($r) = @_;
if ($r->{'type'} eq 'SOA') {
	# Multiliple lines, with brackets
	my $v = $r->{'values'};
	return "$v->[0] $v->[1] (\n\t\t\t$v->[2]\n\t\t\t$v->[3]\n".
	       "\t\t\t$v->[4]\n\t\t\t$v->[5]\n\t\t\t$v->[6] )";
	}
else {
	# All one one line
	my @rv;
	foreach my $v (@{$r->{'values'}}) {
		push(@rv, $v =~ /\s/ ? "\"$v\"" : $v);
		}
	return join(" ", @rv);
	}
}

# compute_serial(old)
# Given an old serial number, returns a new one using the configured method
sub compute_serial
{
my ($old) = @_;
if ($config{'soa_style'} == 1 && $old =~ /^(\d{8})(\d\d)$/) {
	if ($1 >= &date_serial()) {
		if ($2 >= 99) {
			# Have to roll over to next day
			return sprintf "%d%2.2d", $1+1, $config{'soa_start'};
			}
		else {
			# Just increment within this day
			return sprintf "%d%2.2d", $1, $2+1;
			}
		}
	else {
		# A new day has come
		return &date_serial().sprintf("%2.2d", $config{'soa_start'});
		}
	}
elsif ($config{'soa_style'} == 2) {
	# Unix time
	my $rv = time();
	while($rv <= $old) {
		$rv = $old + 1;
		}
	return $rv;
	}
else {
	# Incrementing number
	return $old+1;
	}
}

# convert_to_absolute(short, origin)
# Make a short name like foo a fully qualified name like foo.domain.com.
sub convert_to_absolute
{
my ($name, $origin) = @_;
if ($name eq $origin ||
    $name =~ /\.\Q$origin\E$/) {
	# Name already ends in domain name - add . automatically, so we don't
	# re-append the domain name.
	$name .= ".";
	}
my $rv = $name eq "" ? "$origin." :
	    $name eq "@" ? "$origin." :
	    $name !~ /\.$/ ? "$name.$origin." : $name;
$rv =~ s/\.+$/\./;
return $rv;
}

# get_zone_file(&zone|&zonename, [absolute])
# Returns the relative-to-chroot path to a domain's zone file.
# If absolute is 1, the path is made absolute. If 2, it is also un-chrooted
sub get_zone_file
{
my ($z, $abs) = @_;
$abs ||= 0;
my $fn;
if ($z->{'members'}) {
	my $file = &find("file", $z->{'members'});
	return undef if (!$file);
	$fn = $file->{'values'}->[0];
	}
else {
	$fn = $z->{'file'};
	}
if ($abs) {
	$fn = &absolute_path($fn);
	}
if ($abs == 2) {
	$fn = &make_chroot($fn);
	}
return $fn;
}

# get_dnskey_record(&zone|&zonename, [&records])
# Returns the DNSKEY record(s) for some domain, or undef if none
sub get_dnskey_record
{
my ($z, $recs) = @_;
my @rv;
my $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};
if (!$recs) {
	# Need to get zone file and thus records
	my $fn = &get_zone_file($z);
	$recs = [ &read_zone_file($fn, $dom) ];
	}
# Find the record
foreach my $r (@$recs) {
	if ($r->{'type'} eq 'DNSKEY' &&
	    $r->{'name'} eq $dom.'.') {
		push(@rv, $r);
		}
	}
return wantarray ? @rv : $rv[0];
}

# record_id(&r)
# Returns a unique ID string for a record, based on the name and value
sub record_id
{
my ($r) = @_;
return $r->{'name'}."/".$r->{'type'}.
       (uc($r->{'type'}) eq 'SOA' || !$r->{'values'} ? '' :
		'/'.join('/', @{$r->{'values'}}));
}

# find_record_by_id(&recs, id, index)
# Find a record by ID and possibly index
sub find_record_by_id
{
my ($recs, $id, $num) = @_;
my @rv = grep { &record_id($_) eq $id } @$recs;
if (!@rv) {
	return undef;
	}
elsif (@rv == 1) {
	return $rv[0];
	}
else {
	# Multiple matches .. find the one with the right index
	@rv = grep { $_->{'num'} == $num } @rv;
	return @rv ? $rv[0] : undef;
	}
}

# get_dnskey_rrset(&zone, [&records])
# Returns the DNSKEY recordset for some domain, or an empty array if none 
sub get_dnskey_rrset
{
	my ($z, $recs) = @_;
	my @rv = ();
	my $dom = $z->{'members'} ? $z->{'values'}->[0] : $z->{'name'};
	if (!$recs) {
		# Need to get zone file and thus records
		my $fn = &get_zone_file($z);
		$recs = [ &read_zone_file($fn, $dom) ];
	}
	# Find the record
	foreach my $r (@$recs) {
		if ($r->{'type'} eq 'DNSKEY' &&
			$r->{'name'} eq $dom.'.') {
				push(@rv, $r);
		}
	}
	return @rv;
}

# is_raw_format_records(file)
# Checks if a zone file is in BIND's new raw or text format
sub is_raw_format_records
{
my ($file) = @_;
open(my $RAW, "<", $file) || return 0;
my $buf;
read($RAW, $buf, 3);
close($RAW);
return $buf eq "\0\0\0";
}

1;

