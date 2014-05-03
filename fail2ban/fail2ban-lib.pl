# Functions for configuring the fail2ban log analyser
#
# XXX locking and logging
# XXX include in makedist.pl
# XXX help page
# XXX multi-line directives

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
our ($module_root_directory, %text, %config, %gconfig, $base_remote_user);
our %access = &get_module_acl();

# check_fail2ban()
# Returns undef if installed, or an appropriate error message if missing
sub check_fail2ban
{
-d $config{'config_dir'} || return &text('check_edir',
					 "<tt>$config{'config_dir'}</tt>");
-r "$config{'config_dir'}/fail2ban.conf" ||
	return &text('check_econf', "<tt>$config{'config_dir'}</tt>",
		     "<tt>fail2ban.conf</tt>");
&has_command($config{'client_cmd'}) ||
	return &text('check_eclient', "<tt>$config{'client_cmd'}</tt>");
&has_command($config{'server_cmd'}) ||
	return &text('check_eserver', "<tt>$config{'server_cmd'}</tt>");
return undef;
}

sub is_fail2ban_running
{
my ($pid) = &find_byname($config{'server_cmd'});
if (!$pid) {
	($pid) = &find_byname("fail2ban-server");
	}
return $pid;
}

# list_filters()
# Returns a list of all defined filter files, each of which contains multiple
# sections like [Definition]
sub list_filters
{
my $dir = "$config{'config_dir'}/filter.d";
my @rv;
foreach my $f (glob("$dir/*.conf")) {
	my @conf = &parse_config_file($f);
	if (@conf) {
		push(@rv, \@conf);
		}
	}
return @rv;
}

# list_actions()
# Returns a list of all defined action files, each of which contains multiple
# sections like [Definition] and [Init]
sub list_actions
{
my $dir = "$config{'config_dir'}/action.d";
my @rv;
foreach my $f (glob("$dir/*.conf")) {
	my $conf = &parse_config_file($f);
	if (@$conf) {
		push(@rv, $conf);
		}
	}
return @rv;
}

# list_jails()
# Returns a list of all sections from the jails file
sub list_jails
{
return &parse_config_file("$config{'config_dir'}/jail.conf");
}

# parse_config_file(file)
# Parses one file into a list of [] sections, each with multiple directives
sub parse_config_file
{
my ($file) = @_;
my $lref = &read_file_lines($file, 1);
my $lnum = 0;
my $fh = "CONF";
my $sect;
my @rv;
&open_readfile($fh, $file) || return ( );
while(<$fh>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^\s*\[([^\]]+)\]/) {
		# Start of a section
		$sect = { 'name' => $1,
			  'line' => $lnum,
		 	  'eline' => $lnum,
			  'file' => $file,
			  'members' => [] };
		push(@rv, $sect);
		}
	elsif (/^\s*(\S+)\s*=\s*(.*)/ && $sect) {
		# A directive in a section
		my $dir = { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum,
                            'eline' => $lnum,
                            'file' => $file,
			  };
		push(@{$sect->{'members'}}, $dir);
		$sect->{'eline'} = $lnum;
		&split_directive_values($dir);
		}
	elsif (/^\s+(\S.*)/ && $sect && @{$sect->{'members'}}) {
		# Continuation of a directive
		my $dir = $sect->{'members'}->[@{$sect->{'members'}} - 1];
		$dir->{'value'} .= ' '.$1;
		$dir->{'eline'} = $lnum;
		$sect->{'eline'} = $lnum;
		&split_directive_values($dir);
		}
	$lnum++;
	}
close($fh);
return @rv;
}

# split_directive_values(&dir)
# Populate the 'values' field by splitting up the 'value' field
sub split_directive_values
{
my ($dir) = @_;
my @w;
my $v = $dir->{'value'};
while($v =~ /\S/) {
	if ($v =~ /^(\S+\[[^\]]+\])\s*(.*)/) {
		push(@w, $1);
		$v = $2;
		}
	elsif ($v =~ /^(\S+)\s*(.*)/) {
		push(@w, $1);
		$v = $2;
		}
	}
$dir->{'values'} = \@w;
}

# create_section(file, &section)
# Add a new section to a file
sub create_section
{
my ($file, $sect) = @_;
my $lref = &read_file_lines($file);
$sect->{'file'} = $file;
$sect->{'line'} = scalar(@$lref);
push(@$lref, &section_lines($sect));
$sect->{'eline'} = scalar(@$lref) - $sect->{'line'};
&flush_file_lines($file);
}

# delete_section(file, &section)
# Remove a section and all directives from a file
sub delete_section
{
my ($file, $sect) = @_;
my $lref = &read_file_lines($file);
splice(@$lref, $sect->{'line'}, $sect->{'eline'} - $sect->{'line'} + 1);
my $empty = 1;
foreasch my $l (@$lref) {
	my $ll = $l;
	$ll =~ s/^\s*#.*//;
	$empty = 0 if ($ll =~ /\S/);
	}
if ($empty) {
	# File is now empty, so delete it
	&unflush_file_lines($file);
	&unlink_file($file);
	}
else {
	# Save the file
	&flush_file_lines($file);
	}
}

# section_lines(&section)
# Returns all the lines of text for some section plus directives
sub section_lines
{
my ($sect) = @_;
my @rv;
push(@rv, "[".$sect->{'name'}."]");
foreach my $m (@{$sect->{'members'}}) {
	push(@rv, &directive_lines($m));
	}
return @rv;
}

# directive_lines(&directive)
# Returns all lines of text for some directive
sub directive_lines
{
my ($dir) = @_;
my @rv;
push(@rv, $dir->{'name'}." = ".$dir->{'value'});
return @rv;
}

# save_directive(...)
sub save_directive
{
}

sub find_value
{
my ($name, $object) = @_;
my @rv = map { $_->{'value'} } &find($name, $object);
return wantarray ? @rv : $rv[0];
}

sub find
{
my ($name, $object) = @_;
my $members = ref($object) eq 'HASH' ? $object->{'members'} : $object;
my @rv = grep { lc($_->{'name'}) eq $name } @$members;
return wantarray ? @rv : $rv[0];
}

1;
