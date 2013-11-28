# nis-lib.pl
# Common functions for NIS client and server management

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
if (-r "$module_root_directory/$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl") {
	do "$gconfig{'os_type'}-$gconfig{'os_version'}-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
if ($gconfig{'os_type'} =~ /-linux$/) {
	do "linux-lib.pl";
	}
&foreign_require("init", "init-lib.pl");

# init_script(action)
# Returns the full path to some init script
sub init_script
{
local %iconfig = &foreign_config("init");
return "$iconfig{'init_dir'}/$_[0]";
}

# get_nsswitch_conf()
# Parses lines of nsswitch.conf into an array
sub get_nsswitch_conf
{
local @rv;
open(SWITCH, $config{'nsswitch_conf'});
while(<SWITCH>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/^\s*(\S+):\s*(.*)/) {
		local $sw = { 'service' => $1,
			      'order' => $2 };
		push(@rv, $sw);
		}
	}
close(SWITCH);
return @rv;
}

# save_nsswitch(service, order)
# Updates the line for some service in nsswitch.conf
sub save_nsswitch
{
local $lref = &read_file_lines($config{'nsswitch_conf'});
foreach $l (@$lref) {
	if ($l =~ /^\s*(\S+):/ && $1 eq $_[0]) {
		$l = "$_[0]:\t$_[1]";
		last;
		}
	}
}

# table_edit_setup(table, line, splitter)
# Returns &table, &lnums, line1, line2, ...
sub table_edit_setup
{
local @tables = &list_nis_tables();
local $t = $tables[$_[0]];
return ( $t ) if (!defined($_[1]));
local @lnums = ( $_[1] );
local $lref = &read_file_lines($t->{'files'}->[0]);
local @lines = ( [ split($_[2], $lref->[$_[1]]) ] );
local $i;
for($i=1; $t->{'files'}->[$i]; $i++) {
	local $lref2 = &read_file_lines($t->{'files'}->[$i]);
	local $lnum = 0;
	foreach $l (@$lref2) {
		local @line2 = split($_[2], $l);
		if ($line2[0] eq $lines[0]->[0]) {
			push(@lnums, $lnum);
			push(@lines, \@line2);
			last;
			}
		$lnum++;
		}
	}
return ($t, \@lnums, @lines);
}

# table_add(&table, separator, &record, ...)
# Adds a record to an NIS table
sub table_add
{
local $i = 2;
foreach $f (@{$_[0]->{'files'}}) {
	local $lref = &read_file_lines($f);
	push(@$lref, join($_[1], @{$_[$i++]}));
	}
&flush_file_lines();
}

# table_delete(&table, &lnums)
# Delete a record from an NIS table
sub table_delete
{
local $i = 0;
foreach $f (@{$_[0]->{'files'}}) {
	local $lref = &read_file_lines($f);
	splice(@$lref, $_[1]->[$i], 1);
	$i++;
	}
&flush_file_lines();
}

# table_update(&table, &lnums, separator, &record, ...)
# Modify a record in an NIS table
sub table_update
{
local $i = 0;
foreach $f (@{$_[0]->{'files'}}) {
	local $lref = &read_file_lines($f);
	splice(@$lref, $_[1]->[$i], 1, join($_[2], @{$_[$i+3]}));
	$i++;
	}
&flush_file_lines();
}

# date_input(day, month, year, prefix)
sub date_input
{
print "<input name=$_[3]d size=3 value='$_[0]'>";
print "/<select name=$_[3]m>\n";
local $m;
foreach $m (1..12) {
	printf "<option value=%d %s>%s</option>\n",
		$m, $_[1] eq $m ? 'selected' : '', $text{"smonth_$m"};
	}
print "</select>";
print "/<input name=$_[3]y size=5 value='$_[2]'>";
print &date_chooser_button("$_[3]d", "$_[3]m", "$_[3]y");
}

# parse_ypserv_conf()
# Returns &opts, &maps
sub parse_ypserv_conf
{
local (%opts, @hosts);
local $lnum = 0;
open(CONF, $ypserv_conf);
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*([^:\s]+):\s*(yes|no)/) {
		# Found an option
		$opts{$1} = { 'name' => $1,
			      'value' => $2 eq 'yes' ? 1 : 0,
			      'line' => $lnum };
		}
	elsif (/^\s*([^:\s]+)\s*:\s*([^:\s]+)\s*:\s*([^:\s]+)\s*:\s*(none|port|mangle|deny)(\/mangle(:(\d+))?)?/) {
		# Found a host and domain line (new format)
		push(@hosts, { 'host' => $1,
			       'domain' => $2,
			       'map' => $3,
			       'sec' => $4,
			       'mangle' => $5 ? 1 : 0,
			       'field' => $7,
			       'line' => $lnum } );
		}
	elsif (/^\s*([^:\s]+)\s*:\s*([^:\s]+)\s*:\s*([^:\s]+)(\s*:\s*([^:\s]+))?(\s*:\s*([^:\s]+))?/) {
		# Found a host line (old format)
		push(@hosts, { 'host' => $1,
			       'map' => $2,
			       'sec' => $3,
			       'mangle' => $5 eq 'yes' ? 1 : 0,
			       'field' => $7 eq '' ? 2 : $7,
			       'line' => $lnum } );
		}
	$lnum++;
	}
close(CONF);
return (\%opts, \@hosts);
}

# parse_yp_makefile()
# Returns hashes of makefile variables and rules
sub parse_yp_makefile
{
# First parse joined lines
local $lnum = 0;
local (@lines, $llast);
open(MAKE, $yp_makefile);
while(<MAKE>) {
	s/\r|\n//g;
	local $slash = (s/\\$//);
	s/#.*$//;
	if ($llast) {
		$llast->{'value'} .= " $_";
		$llast->{'eline'} = $lnum;
		}
	else {
		push(@lines, { 'value' => $_,
			       'line' => $lnum,
			       'eline' => $lnum });
		}
	$llast = $slash ? $lines[$#lines] : undef;
	$lnum++;
	}
close(MAKE);

# Then look for variables and rules
local ($i, %var, %rule);
for($i=0; $i<@lines; $i++) {
	if ($lines[$i]->{'value'} =~ /^\s*(\S+)\s*=\s*(.*)/) {
		# Found a variable
		$var{$1} = { 'name' => $1,
			     'value' => $2,
			     'type' => 0,
			     'line' => $lines[$i]->{'line'},
			     'eline' => $lines[$i]->{'eline'} };
		}
	elsif ($lines[$i]->{'value'} =~ /^\s*(\S+)\s*\+=\s*(.*)/) {
		# Adding to a variable
		if ($var{$1}) {
			$var{$1}->{'value'} .= ' '.$2;
			}
		}
	elsif ($lines[$i]->{'value'} =~ /^\s*(\S+):\s*(.*)/) {
		# Found a makefile rule
		$rule{$1} = { 'name' => $1,
			      'value' => $2,
			      'type' => 1,
			      'line' => $lines[$i]->{'line'},
			      'eline' => $lines[$i]->{'eline'} };
		if ($lines[$i+1]->{'value'} =~ /^\s+/) {
			$rule{$1}->{'code'} = $lines[$i+1]->{'value'};
			$rule{$1}->{'eline'} = $lines[$i+1]->{'eline'};
			$i++;
			}
		}
	}
return ( \%var, \%rule );
}

# expand_vars(string, &vars)
sub expand_vars
{
local $rv = $_[0];
while($rv =~ /^(.*)\$\(([A-Za-z0-9_]+)\)(.*)$/) {
#	if (substr($_[1]->{$2}->{'value'}, 0, 7) eq '$(shell') {
#		$rv = $1."\0(".$2.")".$3;
#		}
#	else {
		$rv = $1.$_[1]->{$2}->{'value'}.$3;
#		}
	}
#$rv =~ s/\0/\$/g;
return $rv;
}

# update_makefile(&old, value, [value]);
sub update_makefile
{
local $lref = &read_file_lines($yp_makefile);
local @n;
if ($_[0]->{'type'} == 0) {
	@n = ( "$_[0]->{'name'} = $_[1]" );
	}
else {
	@n = ( "$_[0]->{'name'}: $_[1]", $_[2] );
	}
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1, @n);
}

1;

