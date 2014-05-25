# parser-lib.pl
# Functions for reading and writing the squid config file

use strict;
use warnings;
our (@get_config_cache, %config);

# get_config()
# Parses squid.conf into an array of data structures
sub get_config
{
if (!@get_config_cache) {
	my $fh = "CONF";
	&open_readfile($fh, $config{'squid_conf'}) || return [];
	my $lnum = 0;
	while(my $line = <$fh>) {
		$line =~ s/\r|\n//g;	# strip newlines and comments
		if ($line =~ /^\s*(\#?\s*|\#\s+TAG:\s+)(\S+)\s*(.*)$/) {
			my %dir;
			$dir{'name'} = $2;
			$dir{'value'} = $3;
			$dir{'enabled'} = !$1;
			$dir{'comment'} = $1;
			my $str = $3;
			while($str =~ /^\s*("[^"]*")(.*)$/ ||
			      $str =~ /^\s*(\S+)(.*)$/) {
				my $v = $1;
				$str = $2;
				if ($v !~ /^"/ && $v =~ /^(.*)#/ &&
				    !$dir{'comment'}) {
					# A comment .. end of values
					$v = $1;
					$dir{'postcomment'} = $str;
					$str = undef;
					last if ($v eq '');
					}
				$dir{'values'} ||= [ ];
				push(@{$dir{'values'}}, $v);
				}
			$dir{'line'} = $lnum;
			$dir{'index'} = scalar(@get_config_cache);
			if ($dir{'comment'} =~ /TAG/) {
				$dir{'tag'} = 1;
				}
			push(@get_config_cache, \%dir);
			}
		$lnum++;
		}
	close($fh);
	}
return \@get_config_cache;
}

# find_config(name, &config, [disabled-mode])
# Returns the structure(s) with some name
# disabled mode 0 = only enabled, 1 = both, 2 = only disabled,
# 3 = disabled and tags
sub find_config
{
my ($name, $conf, $mode) = @_;
$mode ||= 0;
my @rv;
foreach my $c (@$conf) {
	if ($c->{'name'} eq $name) {
		push(@rv, $c);
		}
	}
if ($mode == 0) {
	@rv = grep { $_->{'enabled'} && !$_->{'tag'} } @rv;
	}
elsif ($mode == 1) {
	@rv = grep { !$_->{'tag'} } @rv;
	}
elsif ($mode == 2) {
	@rv = grep { !$_->{'enabled'} && !$_->{'tag'} } @rv;
	}
elsif ($mode == 3) {
	@rv = grep { !$_->{'enabled'} } @rv;
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &config, [disabled-mode])
# Returns the value of some directive
sub find_value
{
my ($name, $conf, $mode) = @_;
my $rv = &find_config($name, $conf, $mode);
return $rv ? $rv->{'value'} : undef;
}

# find_values(name, &config, [disabled-mode])
# Returns the value of some directive
sub find_values
{
my ($name, $conf, $mode) = @_;
my $rv = &find_config($name, $conf, $mode);
return $rv ? $rv->{'values'} : undef;
}

# save_value(&config, name, value*)
sub save_value
{
my ($conf, $name, @values) = @_;
my @v = map { { 'name' => $name,
		'values' => [ $_ ] } } @values;
&save_directive($conf, $name, \@v);
}

# save_directive(&config, name, &values, [after])
# Given a structure containing a directive name, type, values and members
# add, update or remove that directive in config structure and data files.
sub save_directive
{
my ($conf, $name, $values, $after) = @_;
my @oldv = &find_config($name, $conf);
my @newv = map { my %n = %$_; \%n } @$values;
my $lref = &read_file_lines($config{'squid_conf'});
my $change = undef;
for(my $i=0; $i<@oldv || $i<@newv; $i++) {
	if ($i >= @oldv) {
		# a new directive is being added.. 
		my $nl = &directive_line($newv[$i]);
		my @after = ref($after) ? ( $after ) :
			    $after ? &find_config($after, $conf) : ( );
		my $after = @after ? $after[$#after] : undef;
		my @comment = &find_config($_[1], $_[0], 3);
		my $comment = @comment ? $comment[$#comment] : undef;
		if ($change &&
		    (!$after || $after->{'line'} < $change->{'line'})) {
			# put it after any directives of the same type
			$newv[$i]->{'line'} = $change->{'line'}+1;
			splice(@$lref, $newv[$i]->{'line'}, 0, $nl);
			&renumber($conf, $change->{'line'}, 1);
			splice(@$conf, &indexof($change, @$conf),
			       0, $newv[$i]);
			$change = $newv[$i];
			}
		elsif ($comment) {
			# put it after commented line
			$newv[$i]->{'line'} = $comment->{'line'}+1;
			splice(@$lref, $newv[$i]->{'line'}, 0, $nl);
			&renumber($conf, $comment->{'line'}, 1);
			splice(@$conf, &indexof($comment, @$conf),
			       0, $newv[$i]);
			}
		else {
			# put it at the end of the file
			$newv[$i]->{'line'} = scalar(@$lref);
			push(@$lref, $nl);
			push(@$conf, $newv[$i]);
			}
		}
	elsif ($i >= @newv) {
		# a directive was deleted
		splice(@$lref, $oldv[$i]->{'line'}, 1);
		&renumber($conf, $oldv[$i]->{'line'}, -1);
		splice(@$conf, &indexof($oldv[$i], @$conf), 1);
		}
	else {
		# updating some directive
		$newv[$i]->{'postcomment'} = $oldv[$i]->{'postcomment'};
		my $nl = &directive_line($newv[$i]);
		my @after = $change && $after ? ( $change ) :
							# After last one updated
			    ref($after) ? ( $after ) :	# After specific
			    $after ? &find_config($after, $conf) : ( );
		my $after = @after ? $after[$#after] : undef;
		if ($after && $oldv[$i]->{'line'} < $after->{'line'}) {
			# Need to move it after some directive
			splice(@$lref, $oldv[$i]->{'line'}, 1);
			splice(@$conf, &indexof($oldv[$i], @$conf), 1);
			&renumber($conf, $oldv[$i]->{'line'}, -1);

			splice(@$lref, $after->{'line'}+1, 0, $nl);
			$newv[$i]->{'line'} = $after->{'line'}+1;
			splice(@$conf, &indexof($after, @$conf)+1, 0,
			       $newv[$i]);
			&renumber($conf, $newv[$i]->{'line'}, 1);
			$change = $newv[$i];
			}
		else {
			# Can just update at the same line
			splice(@$lref, $oldv[$i]->{'line'}, 1, $nl);
			$newv[$i]->{'line'} = $oldv[$i]->{'line'};
			$conf->[&indexof($oldv[$i], @$conf)] = $newv[$i];
			$change = $newv[$i];
			}
		}
	}
}

# directive_line(&details)
# Returns the line of text for some directive
sub directive_line
{
my ($d) = @_;
my @v = @{$d->{'values'}};
return $d->{'name'}.(@v ? " ".join(' ',@v) : "").
       ($d->{'postcomment'} ? " #".$d->{'postcomment'} : "");
}

# renumber(&directives, line, count, [end])
# Runs through the given array of directives and increases the line numbers
# of all those greater than some line by the given count
sub renumber
{
my ($conf, $line, $count, $end) = @_;
foreach my $d (@$conf) {
	if ($d->{'line'} > $line && (!$end || $d->{'line'} < $end)) {
		$d->{'line'} += $count;
		}
	}
}

1;

