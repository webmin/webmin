# pap-lib.pl
# Functions for managing the mgetty configuration files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

do 'secrets-lib.pl';

# mgetty_inittabs()
# Returns a list of inittab entries for mgetty, with options parsed
sub mgetty_inittabs
{
local @rv;
foreach $i (&inittab::parse_inittab()) {
	if ($i->{'process'} =~ /^(\S*mgetty)\s*(.*)\s+((\/.*)?(tty|term|cua)\S+)(\s+(\S+))?$/) {
		$i->{'mgetty'} = $1;
		$i->{'args'} = $2;
		$i->{'tty'} = $3;
		$i->{'ttydefs'} = $7;
		if ($i->{'args'} =~ s/\s*-s\s+(\d+)//) {
			$i->{'speed'} = $1;
			}
		if ($i->{'args'} =~ s/\s*-r//) {
			$i->{'direct'} = 1;
			}
		if ($i->{'args'} =~ s/\s*-n\s+(\d+)//) {
			$i->{'rings'} = $1;
			}
		if ($i->{'args'} =~ s/\s*-D//) {
			$i->{'data'} = 1;
			}
		if ($i->{'args'} =~ s/\s*-F//) {
			$i->{'fax'} = 1;
			}
		if ($i->{'args'} =~ s/\s*-R\s+(\d+)//) {
			$i->{'back'} = $1;
			}
		if ($i->{'args'} =~ s/\s*-p\s+'([^']+)'// ||
		    $i->{'args'} =~ s/\s*-p\s+"([^"]+)"// ||
		    $i->{'args'} =~ s/\s*-p\s+(\S+)//) {
			$i->{'prompt'} = $1;
			}
		push(@rv, $i);
		}
	elsif ($i->{'process'} =~ /^(\S*vgetty)\s*(.*)\s+((\/.*)?tty\S+)/) {
		$i->{'vgetty'} = $1;
		$i->{'args'} = $2;
		$i->{'tty'} = $3;
		push(@rv, $i);
		}
	}
return @rv;
}

# parse_ppp_options(file)
sub parse_ppp_options
{
local @rv;
local $lnum = 0;
open(OPTS, $_[0]);
while(<OPTS>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/^([0-9\.]+):([0-9\.]+)/) {
		push(@rv, { 'local' => $1,
			    'remote' => $2,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	elsif (/^(\S+)\s*(.*)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'file' => $_[0],
			    'line' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(OPTS);
return @rv;
}

# find(name, &config)
sub find
{
local @rv = grep { lc($_->{'name'}) eq lc($_[0]) } @{$_[1]};
return wantarray ? @rv : $rv[0];
}

# save_ppp_option(&config, file, &old|name, &new)
sub save_ppp_option
{
local $ol = ref($_[2]) || !defined($_[2]) ? $_[2] : &find($_[2], $_[0]);
local $nw = $_[3];
local $lref = &read_file_lines($_[1]);
local $line;
if ($nw) {
	if ($nw->{'local'}) {
		$line = $nw->{'local'}.":".$nw->{'remote'};
		}
	else {
		$line = $nw->{'name'};
		$line .= " $nw->{'value'}" if ($nw->{'value'} ne "");
		}
	}
if ($ol && $nw) {
	$lref->[$ol->{'line'}] = $line;
	}
elsif ($ol) {
	splice(@$lref, $ol->{'line'}, 1);
	local $c;
	foreach $c (@{$_[0]}) {
		$c->{'line'}-- if ($c->{'line'} > $ol->{'line'});
		}
	}
elsif ($nw) {
	push(@$lref, $line);
	}
}

# parse_login_config()
# Parses the mgetty login options file into a list of users
sub parse_login_config
{
local @rv;
local $lnum = 0;
open(LOGIN, $config{'login_config'});
while(<LOGIN>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/^(\S+)\s+(\S+)\s+(\S+)\s+(.*)/) {
		push(@rv, { 'user' => $1,
			    'userid' => $2,
			    'utmp' => $3,
			    'program' => $4,
			    'line' => $lnum });
		}
	$lnum++;
	}
close(LOGIN);
return @rv;
}

# delete_login_config(&config, &login)
sub delete_login_config
{
local $lref = &read_file_lines($config{'login_config'});
splice(@$lref, $_[1]->{'line'}, 1);
}

# create_login_config(&config, &login)
sub create_login_config
{
local ($star) = grep { $_->{'user'} eq '*' } @{$_[0]};
local $line = join("\t", $_[1]->{'user'}, $_[1]->{'userid'},
			 $_[1]->{'utmp'}, $_[1]->{'program'});
local $lref = &read_file_lines($config{'login_config'});
if ($star) {
	splice(@$lref, $star->{'line'}, 0, $line);
	}
else {
	push(@$lref, $line);
	}
}

# parse_dialin_config()
# Parses the mgetty dialin file
sub parse_dialin_config
{
local @rv;
local $lnum = 0;
open(DIALIN, $config{'dialin_config'});
while(<DIALIN>) {
	s/\r|\n//g;
	s/#.*$//g;
	s/^\s+//;
	local $t;
	foreach $t (split(/[ \t,]+/, $_)) {
		local ($not) = ($t =~ s/^\!//);
		push(@rv, { 'number' => $t,
			    'not' => $not,
			    'index' => scalar(@rv),
			    'line' => $lnum });
		}
	$lnum++;
	}
close(DIALIN);
return @rv;
}

# create_dialin(&dialin)
sub create_dialin
{
&open_tempfile(DIALIN, ">>$config{'dialin_config'}");
&print_tempfile(DIALIN, &dialin_line($_[0])."\n");
&close_tempfile(DIALIN);
}

# delete_dialin(&dialin, &config)
sub delete_dialin
{
local @same = grep { $_->{'line'} == $_[0]->{'line'} && $_ ne $_[0] }
		   @{$_[1]};
if (@same) {
	&replace_file_line($config{'dialin_config'}, $_[0]->{'line'},
			   join(" ", map { &dialin_line($_) } @same)."\n");
	}
else {
	&replace_file_line($config{'dialin_config'}, $_[0]->{'line'});
	}
}

# modify_dialin(&dialin, &config)
sub modify_dialin
{
local @same = grep { $_->{'line'} == $_[0]->{'line'} } @{$_[1]};
&replace_file_line($config{'dialin_config'}, $_[0]->{'line'},
		   join(" ", map { &dialin_line($_) } @same)."\n");
}

# swap_dialins(&dialin1, &dialin2, &config)
sub swap_dialins
{
local $lref = &read_file_lines($config{'dialin_config'});
local @same1 = grep { $_->{'line'} == $_[0]->{'line'} } @{$_[2]};
local @same2 = grep { $_->{'line'} == $_[1]->{'line'} } @{$_[2]};
local $idx1 = &indexof($_[0], @same1);
local $idx2 = &indexof($_[1], @same2);
if ($_[0]->{'line'} == $_[1]->{'line'}) {
	($same1[$idx1], $same1[$idx2]) = ($same1[$idx2], $same1[$idx1]);
	&replace_file_line($config{'dialin_config'}, $_[0]->{'line'},
			   join(" ", map { &dialin_line($_) } @same1)."\n");
	}
else {
	($same1[$idx1], $same2[$idx2]) = ($same2[$idx2], $same1[$idx1]);
	&replace_file_line($config{'dialin_config'}, $_[0]->{'line'},
			   join(" ", map { &dialin_line($_) } @same1)."\n");
	&replace_file_line($config{'dialin_config'}, $_[1]->{'line'},
			   join(" ", map { &dialin_line($_) } @same2)."\n");
	}
}

# dialin_line(&dialin)
sub dialin_line
{
return ($_[0]->{'not'} ? "!" : "").$_[0]->{'number'};
}

# apply_mgetty()
# Apply the current serial port and mgetty configuration, or return an
# error message
sub apply_mgetty
{
local %iconfig = &foreign_config("inittab");
local $out = &backquote_logged("$iconfig{'telinit'} q 2>&1 </dev/null");
if ($?) {
	return "<tt>$out</tt>";
	}
&kill_byname_logged("mgetty", 'TERM');
return undef;
}

1;

