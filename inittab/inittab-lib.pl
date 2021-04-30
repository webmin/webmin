#!/usr/local/bin/perl

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# parse_inittab()
# Returns a list of entries from the /etc/inittab file
sub parse_inittab
{
local @rv;
local $lnum = 0;
open(INITTAB, "<".$config{'inittab_file'});
while(<INITTAB>) {
	s/\r|\n//g;
	#s/#.*$//g;
	s/\/\/.*$//g;
	if ($gconfig{'os_type'} eq 'aix') {
		# A leading : indicates a comment on AIX
		s/^:.*$//g;
		}
	next if (/^\s*#\s*\$Header/i);	# CVS header
	local $sline = $lnum;
	# Join \ lines
	while(/\\$/) {
		local $nl = <INITTAB>;
		s/\\$//;
		$nl =~ s/^\s+//;
		$_ .= $nl;
		$lnum++;
		}
	if (/^(#*)\s*\$Id/ || /^(#*)\s*\/etc/ || /^(#*)\s*<id>/) {
		# Skip this line
		}
	elsif (/^(#*)\s*([^:]+):([^:]*):([^:]+):([^:]*)/) {
		push(@rv, { 'id' => $2,
			    'action' => $4,
			    'process' => $5,
			    'comment' => $1 ne '',
			    'levels' => [ split(//, $3) ],
			    'line' => $sline,
			    'eline' => $lnum,
			    'index' => scalar(@rv) });
		}
	$lnum++;
	}
close(INITTAB);
return @rv;
} 

# create_inittab(&inittab)
# Adds an entry to /etc/inittab
sub create_inittab
{
&open_tempfile(INITTAB, ">>$config{'inittab_file'}");
&print_tempfile(INITTAB, $_[0]->{'comment'} ? "# " : "",
	      join(":", $_[0]->{'id'}, join("", @{$_[0]->{'levels'}}),
			$_[0]->{'action'}, $_[0]->{'process'}),"\n");
&close_tempfile(INITTAB);
}

# modify_inittab(&inittab)
# Replaces an /etc/inittab entry
sub modify_inittab
{
local $lref = &read_file_lines($config{'inittab_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       ($_[0]->{'comment'} ? "# " : "").
       join(":", $_[0]->{'id'}, join("", @{$_[0]->{'levels'}}),
		 $_[0]->{'action'}, $_[0]->{'process'}));
&flush_file_lines();
}

# delete_inittab(&inittab)
# Delete a single /etc/inittab entry
sub delete_inittab
{
local $lref = &read_file_lines($config{'inittab_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

sub list_runlevels
{
return ( 0..6, "a", "b", "c" );
}

sub list_actions
{
return ( [ "respawn", $text{ 'inittab_respawn' } ],
	 [ "wait", $text{ 'inittab_wait' } ],
	 [ "once", $text{ 'inittab_once' } ],
	 [ "ondemand", $text{ 'inittab_ondemand' } ],
         [ "initdefault", $text{ 'inittab_initdefault' } ],
	 [ "sysinit", $text{ 'inittab_sysinit' } ],
	 [ "powerwait", $text{ 'inittab_powerwait' } ],
	 [ "powerfail", $text{ 'inittab_powerfail' } ],
	 [ "powerokwait", $text{ 'inittab_powerokwait' } ],
	 [ "powerfailnow", $text{ 'inittab_powerfailnow' } ],
	 [ "ctrlaltdel", $text{ 'inittab_ctrlaltdel' } ],
	 [ "kbdrequest", $text{ 'inittab_kbdrequest' } ],
	 [ "bootwait", $text{'inittab_bootwait'} ],
	 [ "boot", $text{'inittab_boot'} ],
	 [ "off", $text{'inittab_off'} ],
	);
}

