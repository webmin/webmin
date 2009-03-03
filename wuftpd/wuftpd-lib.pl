# wuftpd-lib.pl
# Functions for configuring wuftpd

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_ftpaccess()
# Returns a list of wuftpd config options
sub get_ftpaccess
{
local @rv;
local $lnum = 0;
open(FTP, $config{'ftpaccess'});
while(<FTP>) {
	s/\r|\n//g;
	s/#.*$//;
	local @v = split(/\s+/, $_);
	if (@v) {
		push(@rv, { 'name' => shift(@v),
			    'values' => \@v,
			    'index' => scalar(@rv),
			    'line' => $lnum });
		}
	$lnum++;
	}
close(FTP);
return \@rv;
}

# find(name, &config)
sub find
{
local (@rv, $c);
foreach $c (@{$_[1]}) {
	push(@rv, $c) if ($c->{'name'} eq $_[0]);
	}
return wantarray ? @rv :
       @rv ? $rv[0] : undef;
}

# find_value(name, &config)
sub find_value
{
local (@rv, $c);
foreach $c (@{$_[1]}) {
	push(@rv, $c->{'values'}) if ($c->{'name'} eq $_[0]);
	}
return wantarray ? @rv :
       @rv ? $rv[0] : undef;
}

# save_directive(&config, name, &new)
sub save_directive
{
local @old = &find($_[1], $_[0]);
local @new = @{$_[2]};
local $lref = &read_file_lines($config{'ftpaccess'});
local ($i, $change);
for($i=0; $i<@old || $i<@new; $i++) {
	if ($i >= @old) {
		if ($change) {
			# Adding a new directive after one of the same
			splice(@$lref, $change->{'line'}+1, 0,
			       &directive_line($new[$i]));
			$new[$i]->{'line'} = $change->{'line'}+1;
			&renumber($_[0], $change->{'line'}, 1);
			push(@{$_[0]}, $new[$i]);
			}
		else {
			# Adding a new directive at the end
			push(@$lref, &directive_line($new[$i]));
			$new[$i]->{'line'} = scalar(@$lref);
			push(@{$_[0]}, $new[$i]);
			}
		$change = $new[$i];
		}
	elsif ($i >= @new) {
		# Removing a directive
		splice(@$lref, $old[$i]->{'line'}, 1);
		splice(@{$_[0]}, &indexof($old[$i], @{$_[0]}), 1);
		&renumber($_[0], $old[$i]->{'line'}, -1);
		}
	else {
		# Changing a directive
		$lref->[$old[$i]->{'line'}] = &directive_line($new[$i]);
		$new[$i]->{'line'} = $old[$i]->{'line'};
		$_[0]->[&indexof($old[$i], @{$_[0]})] = $new[$i];
		$change = $new[$i];
		}
	}
}

# renumber(&config, line, offset)
sub renumber
{
foreach $d (@{$_[0]}) {
	if ($d->{'line'} > $_[1]) { $d->{'line'} += $_[2]; }
	}
}

sub directive_line
{
return join("\t", $_[0]->{'name'}, @{$_[0]->{'values'}});
}

# running_under_inetd()
# Returns the inetd/xinetd object and program if WUFTP is running under one
sub running_under_inetd
{
local ($inet, $inet_mod);
if (&foreign_check('inetd')) {
	# Check if ftpd is in inetd
	&foreign_require('inetd', 'inetd-lib.pl');
	foreach $i (&foreign_call('inetd', 'list_inets')) {
		if ($i->[1] && $i->[3] eq 'ftp') {
			$inet = $i;
			last;
			}
		}
	$inet_mod = 'inetd';
	}
elsif (&foreign_check('xinetd')) {
	# Check if ftpd is in xinetd
	&foreign_require('xinetd', 'xinetd-lib.pl');
	foreach $xi (&foreign_call("xinetd", "get_xinetd_config")) {
		if ($xi->{'quick'}->{'disable'}->[0] ne 'yes' &&
		    $xi->{'value'} eq 'ftp') {
			$inet = $xi;
			last;
			}
		}
	$inet_mod = 'xinetd';
	}
else {
	# Not supported on this OS .. assume so
	$inet = 1;
	}
return ($inet, $inet_mod);
}

1;

