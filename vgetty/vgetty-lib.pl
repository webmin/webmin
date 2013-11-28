# vgetty-lib.pl
# Common functions for editing the vgetty config files
# XXX options under ring_type 
# XXX DTMF command shells http://vocp.sourceforge.net/
# XXX DTMF terminals http://telephonectld.sourceforge.net/

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# vgetty_inittabs()
# Returns a list of inittab entries for mgetty, with options parsed
sub vgetty_inittabs
{
local @rv;
foreach $i (&inittab::parse_inittab()) {
	if ($i->{'process'} =~ /^(\S*vgetty)\s*(.*)\s+((\/.*)?tty\S+)(\s+(\S+))?$/) {
		$i->{'vgetty'} = $1;
		$i->{'args'} = $2;
		$i->{'tty'} = $3;
		$i->{'ttydefs'} = $6;
		push(@rv, $i);
		}
	elsif ($i->{'process'} =~ /^(\S*mgetty)\s*(.*)\s+((\/.*)?tty\S+)/) {
		$i->{'mgetty'} = $1;
		$i->{'tty'} = $3;
		push(@rv, $i);
		}
	}
return @rv;
}

# get_config()
# Parse the vgetty config file into a series of directives
sub get_config
{
local @rv;
local $lnum = 0;
open(CONFIG, $config{'vgetty_config'});
while(<CONFIG>) {
	s/\r|\n//g;
	s/#.*$//;
	local @v;
	while(/^\s*"([^"]*)"(.*)/ ||
	      /^\s*'([^']*)'(.*)/ ||
	      /^\s*(\S+)(.*)/) {
		push(@v, $1);
		$_ = $2;
		}
	if (@v) {
		push(@rv, { 'line' => $lnum,
			    'index' => scalar(@rv),
			    'name' => shift(@v),
			    'values' => \@v });
		}
	$lnum++;
	}
close(CONFIG);
return @rv;
}

# find(name, &config)
# Finds one more more config entries with the given name
sub find
{
local ($c, @rv);
foreach $c (@{$_[1]}) {
	push(@rv, $c) if (lc($c->{'name'}) eq lc($_[0]));
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @v = &find($_[0], $_[1]);
return undef if (!@v);
return wantarray ? @{$v[0]->{'values'}} : $v[0]->{'values'}->[0];
}

# tty_opt_file(base, tty)
sub tty_opt_file
{
local $tf = $_[1];
$tf =~ s/^\/dev\///;
$tf =~ s/\//\./g;
$tf = "$_[0].$tf";
return $tf;
}

# answer_mode_input(value, name)
sub answer_mode_input
{
local @modes = ( '', 'voice', 'fax', 'data' );
local @am = split(/:/, $_[0]);
local ($i, $rv);
for($i=0; $i<3; $i++) {
	$rv .= "<select name=$_[1]_$i>\n";
	foreach $m (@modes) {
		$rv .= sprintf "<option value='%s' %s>%s</option>\n",
		    $m, $am[$i] eq $m ? "selected" : "", $text{"vgetty_ans_$m"};
		}
	$rv .= "</select>&nbsp;";
	}
return $rv;
}

# parse_answer_mode(name)
sub parse_answer_mode
{
local (@rv, $i, $m);
for($i=0; defined($m = $in{"$_[0]_$i"}); $i++) {
	push(@rv, $m) if ($m);
	}
return join(":", @rv);
}

# receive_dir(&config)
sub receive_dir
{
local $vdir = &find_value("voice_dir", \@conf);
local $rdir = &find_value("receive_dir", \@conf);
return $rdir =~ /^\// ? $rdir : "$vdir/$rdir";
}

# messages_dir(&config)
sub messages_dir
{
local $vdir = &find_value("voice_dir", \@conf);
local $rdir = &find_value("message_dir", \@conf);
return $rdir =~ /^\// ? $rdir : "$vdir/$rdir";
}

# messages_index(&config)
sub messages_index
{
local $dir = &messages_dir($_[0]);
local $ifile = &find_value("message_list", \@conf);
return "$dir/$ifile";
}

# rmd_file_info(file)
sub rmd_file_info
{
local $out = `rmdfile '$_[0]' 2>&1`;
return undef if ($?);
local @st = stat($_[0]);
$_[0] =~ /\/([^\/]+)$/;
local $rv = { 'file' => "$1",
	      'path' => $_[0],
	      'size' => $st[7],
	      'date' => $st[9],
	      'speed' => $out =~ /speed:\s+(\d+)/i ? "$1" : undef,
	      'type' => $out =~ /type\s+is:\s+"([^"]+)"/i ? "$1" : undef,
	      'bits' => $out =~ /sample:\s+(\d+)/i ? "$1" : undef
	    };
return $rv;
}

# list_rmd_formats()
sub list_rmd_formats
{
local @rv;
open(RMD, "pvftormd -L 2>&1 |");
while(<RMD>) {
	if (/^\s+\-\s+(\S+)\s+([0-9, ]+)\s+(.*)/) {
		local $code = $1;
		local $bits = $2;
		local $desc = $3;
		$bits =~ s/\s//g;
		foreach $b (split(/,/, $bits)) {
			push(@rv, { 'code' => $code,
				    'bits' => $b,
				    'desc' => &text('pvfdesc',
						    "$code ($desc)", $b),
				    'index' => scalar(@rv) });
			}
		}
	}
close(RMD);
return @rv;
}

# save_directive(&config, name, value)
sub save_directive
{
local $lref = &read_file_lines($config{'vgetty_config'});
local $old = &find($_[1], $_[0]);
if ($old) {
	$lref->[$old->{'line'}] = "$_[1] $_[2]";
	}
else {
	push(@$lref, "$_[1] $_[2]");
	}
}

# apply_configuration()
# Apply the vgetty serial port configuration. Returns undef on success, or an
# error message on failure
sub apply_configuration
{
local $out = &backquote_logged("telinit q 2>&1 </dev/null");
return "<tt>$out</tt>" if ($?);
&system_logged("killall vgetty");
return undef;
}

1;

