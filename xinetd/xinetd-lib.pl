# xinetd-lib.pl
# Functions for parsing xinetd config files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_xinetd_config()
sub get_xinetd_config
{
return &parse_xinetd($config{'xinetd_conf'});
}

# parse_xinetd(file, [offset])
# Parses the xinetd config file into directives
sub parse_xinetd
{
local @rv;
open(INET, $_[0]);
local @lines = <INET>;
close(INET);
local $lnum = 0;
local $section;
foreach (@lines) {
	s/\r|\n//g; s/#.*$//g; s/\s+$//;  # remove newlines, comments and spaces
	if (/^\s*\{/) {
		# put subsequent directives into a section
		$section = $rv[$#rv];
		$section->{'members'} = [ ];
		}
	elsif (/^\s*\}/) {
		# finished the section
		$section->{'eline'} = $lnum;
		$section = undef;
		}
	elsif (/^\s*include\s+(\S+)/) {
		# include directives from a file
		push(@rv, &parse_xinetd($1, scalar(@rv)));
		}
	elsif (/^\s*includedir\s+(\S+)/) {
		# include directives from every file in a directory
		local $d = $1;
		opendir(DIR, $d);
		foreach $f (readdir(DIR)) {
			next if ($f =~ /^\./);
			push(@rv, &parse_xinetd("$d/$f", scalar(@rv)));
			}
		closedir(DIR);
		}
	elsif (/^\s*(\S+)\s*(.*)/) {
		# a directive or start of a section
		local $dir = { 'name' => $1, 'file' => $_[0],
			       'index' => scalar(@rv) + $_[1],
			       'line' => $lnum, 'eline' => $lnum };
		local $v = $2;
		if ($v =~ /^(=|\+=|-=)\s+(.*)/) {
			$dir->{'op'} = $1;
			$dir->{'value'} = $2;
			}
		else {
			$dir->{'op'} = '=' if ($service);
			$dir->{'value'} = $v;
			}
		local @v = split(/\s+/, $dir->{'value'});
		$dir->{'values'} = \@v;
		if ($section) {
			push(@{$section->{'members'}}, $dir);
			local @q = @{$section->{'quick'}->{$dir->{'name'}}};
			if ($dir->{'op'} eq '=') {
				@q = @v;
				}
			elsif ($dir->{'op'} eq '+=') {
				@q = ( @q, @v );
				}
			elsif ($dir->{'op'} eq '-=') {
				@q = grep { &indexof($_, @v) < 0 } @q;
				}
			$section->{'quick'}->{$dir->{'name'}} = \@q;
			}
		else { push(@rv, $dir); }
		}
	$lnum++;
	}
return @rv;
}

# set_member_value(&xinet, name, [value]*)
# Removes all members with the given name and replaces them with one
# like  name = value
sub set_member_value
{
local @m = @{$_[0]->{'members'}};
@m = grep { $_->{'name'} ne $_[1] } @m;
if (defined($_[2])) {
	push(@m, { 'name' => $_[1],
		   'op' => '=',
		   'values' => [ @_[2..@_-1] ] } );
	$_[0]->{'quick'}->{$_[1]} = [ @_[2..@_-1] ];
	}
else {
	delete($_[0]->{'quick'}->{$_[1]});
	}
$_[0]->{'members'} = \@m;
}

# create_xinet(&xinet, [file])
# Add a new xinet record to the end of the config file
sub create_xinet
{
local $lref = &read_file_lines($_[1] || $config{'xinetd_conf'});
push(@$lref, &xinet_lines($_[0]));
&flush_file_lines();
}

# modify_xinet(&xinet)
# Update an existing xinet record
sub modify_xinet
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &xinet_lines($_[0]));
&flush_file_lines();
}

# delete_xinet(&xinet)
# Delete an existing xinet record
sub delete_xinet
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

# xinet_lines(&xinet, tabs)
sub xinet_lines
{
local @rv;
$rv[0] = "$_[1]$_[0]->{'name'}";
$rv[0] .= " $_[0]->{'op'}" if ($_[0]->{'op'});
foreach $v (@{$_[0]->{'values'}}) {
	$rv[0] .= " $v";
	}
if ($_[0]->{'members'}) {
	push(@rv, $_[1].'{');
	foreach $m (@{$_[0]->{'members'}}) {
		push(@rv, &xinet_lines($m, "$_[1]\t"));
		}
	push(@rv, $_[1].'}');
	}
return @rv;
}

# list_protocols()
# Returns a list of supported protocols on this system
sub list_protocols
{
local(@rv);
open(PROT, $config{'protocols_file'});
while(<PROT>) {
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	/^(\S+)\s+/;
	push(@rv, $1);
	}
close(PROT);
return &unique(@rv);
}

sub is_xinetd_running
{
if ($config{'pid_file'}) {
	return &check_pid_file($config{'pid_file'});
	}
else {
	local ($pid) = &find_byname("xinetd");
	return $pid;
	}
}

sub get_start_binary
{
my ($cmd) = split(/\s+/, $config{'start_cmd'});
return &has_command($cmd);
}

1;

