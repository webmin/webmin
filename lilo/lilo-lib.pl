# lilo-lib.pl
# Common functions for lilo.conf

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

map { $member{$_}++ } ('range', 'loader', 'table', 'unsafe', 'label',
		       'alias', 'lock', 'optional', 'password', 'restricted',
		       'append', 'literal', 'ramdisk', 'read-only',
		       'read-write', 'root', 'vga', 'initrd');

# read the lilo version
if (open(VERSION, "$module_config_directory/version")) {
	chop($lilo_version = <VERSION>);
	close(VERSION);
	}

# get_lilo_conf()
# Parses lilo.conf and returns a list of directives
sub get_lilo_conf
{
return @lilo_conf_cache if (scalar(@lilo_conf_cache));
open(CONF, $config{'lilo_conf'});
local $lnum = -1;
local ($image, $line);
while($line = <CONF>) {
	$lnum++;
	$line =~ s/\r|\n//g;
	$line =~ s/#.*$//g;
	local %dir;
	if ($line =~ /^\s*([^=\s]+)\s*=\s*"(.*)"$/ ||
	    $line =~ /^\s*([^=\s]+)\s*=\s*(.*)$/) {
		$dir{'name'} = $1;
		$dir{'value'} = $2;
		$dir{'line'} = $lnum;
		if ($dir{'value'} =~ s/\\$//) {
			# multi-line directive!
			while($line = <CONF>) {
				$line =~ s/\r|\n//g;
				$line =~ s/^\s+//;
				local $cont = ($line =~ s/\\$//g);
				$dir{'value'} .= ' '.$line;
				$lnum++;
				last if (!$cont);
				}
			}
		$dir{'eline'} = $lnum;
		}
	elsif ($line =~ /^\s*(\S+)/) {
		$dir{'name'} = $1;
		$dir{'eline'} = $dir{'line'} = $lnum;
		}
	else { next; }
	if ($dir{'name'} eq 'image' || $dir{'name'} eq 'other') {
		$dir{'index'} = scalar(@rv);
		$image = \%dir;
		push(@rv, \%dir);
		}
	elsif ($member{$dir{'name'}} && $image) {
		$dir{'index'} = scalar(@{$image->{'members'}});
		push(@{$image->{'members'}}, \%dir);
		$image->{'eline'} = $lnum;
		}
	else {
		$dir{'index'} = scalar(@rv);
		push(@rv, \%dir);
		$image = undef;
		}
	}
close(CONF);
@lilo_conf_cache = @rv;
return \@rv;
}

# save_directive(&config, &old|name, &new)
# Given a directive, either update it in the config file or add it at the
# correct position.
sub save_directive
{
local $lref = &read_file_lines($config{'lilo_conf'});
local $old = ref($_[1]) ? $_[1] : &find($_[1], $_[0]);
local @lines = $_[2] ? &directive_lines($_[2]) : undef;
if ($_[2] && $old) {
	# updating some directive, possibly multi-line
	local $len = $old->{'eline'} - $old->{'line'} + 1;
	splice(@$lref, $old->{'line'}, $len, @lines);
	&renumber($_[0], $old->{'eline'}+1, @lines - $len);
	$_[2]->{'eline'} = $_[2]->{'line'} + @lines - 1;
	$_[0]->[$old->{'index'}] = $_[2];
	}
elsif ($old) {
	# deleting an existing directive
	local $len = $old->{'eline'} - $old->{'line'} + 1;
	splice(@$lref, $old->{'line'}, $len);
	&renumber($_[0], $old->{'line'}, -1);
	splice(@{$_[0]}, $old->{'index'}, 1);
	&renumber_index($_[0], $old->{'index'}, -1);
	}
elsif ($_[2] && $_[2]->{'members'}) {
	# adding a multi-line directive at the end
	local $last = $_[0]->[@{$_[0]} - 1];
	$_[2]->{'line'} = $last->{'eline'} + 1;
	$_[2]->{'eline'} = $last->{'eline'} + @lines;
	push(@$lref, @lines);
	$_[2]->{'index'} = scalar(@{$_[0]});
	push(@{$_[0]}, $_[2]);
	}
elsif ($_[2]) {
	# adding a single-line directive at the top
	$_[2]->{'line'} = $_[2]->{'eline'} = 0;
	$_[2]->{'index'} = 0;
	splice(@$lref, 0, 0, @lines);
	&renumber($_[0], $_[2]->{'line'}, 1);
	&renumber_index($_[0], 0, 1);
	splice(@{$_[0]}, 0, 0, $_[2]);
	}
}

# directive_lines(&directive, indent)
sub directive_lines
{
local $v = $_[0]->{'value'} =~ /\s/ ? '"'.$_[0]->{'value'}.'"'
				    : $_[0]->{'value'};
if ($_[0]->{'members'}) {
	local @rv = ( $_[1].$_[0]->{'name'}."=".$v );
	local $m;
	foreach $m (@{$_[0]->{'members'}}) {
		push(@rv, &directive_lines($m, $_[1]."\t"));
		}
	return @rv;
	}
elsif ($_[0]->{'value'} ne "") {
	return ( $_[1].$_[0]->{'name'}."=".$v );
	}
else {
	return ( $_[1].$_[0]->{'name'} );
	}
}

# renumber(&config, line, offset)
# Add offset to the start and end of any directive after the line
sub renumber
{
return if (!$_[2]);
local $c;
foreach $c (@{$_[0]}) {
	$c->{'line'} += $_[2] if ($c->{'line'} >= $_[1]);
	$c->{'eline'} += $_[2] if ($c->{'eline'} >= $_[1]);
	if ($c->{'members'}) {
		&renumber($c->{'members'}, $_[1], $_[2]);
		}
	}
}

# renumber_index(&config, pos, offset)
sub renumber_index
{
return if (!$_[2]);
local $c;
foreach $c (@{$_[0]}) {
	$c->{'index'} += $_[2] if ($c->{'index'} >= $_[1]);
	}
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

# save_subdirective(&image, name, value)
sub save_subdirective
{
local $mems = $_[0]->{'members'};
local $old = &find($_[1], $mems);
if ($old && defined($_[2])) {
	$old->{'value'} = $_[2];
	}
elsif (defined($_[2])) {
	push(@$mems, { 'name' => $_[1], 'value' => $_[2] });
	}
elsif ($old) {
	local $idx = &indexof($old, @$mems);
	splice(@$mems, $idx, 1);
	}
}

sub is_x86
{
return `uname -m 2>&1` =~ /i.86/i;
}


1;
