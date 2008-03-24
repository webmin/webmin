# parser-lib.pl
# Functions for reading and writing the squid config file

# get_config()
# Parses squid.conf into an array of data structures
sub get_config
{
local($lnum, $_);
if (!@get_config_cache) {
	open(CONF, $config{'squid_conf'});
	$lnum = 0;
	while(<CONF>) {
		s/\r|\n//g;	# strip newlines and comments
		if (/^\s*(\#?\s*|\#\s+TAG:\s+)(\S+)\s*(.*)$/) {
			local(%dir);
			$dir{'name'} = $2;
			$dir{'value'} = $3;
			$dir{'enabled'} = !$1;
			$dir{'comment'} = $1;
			local $str = $3;
			while($str =~ /^\s*("[^"]*")(.*)$/ ||
			      $str =~ /^\s*(\S+)(.*)$/) {
				local $v = $1;
				$str = $2;
				if ($v !~ /^"/ && $v =~ /^(.*)#/ &&
				    !$dir{'comment'}) {
					# A comment .. end of values
					$v = $1;
					$dir{'postcomment'} = $str;
					$str = undef;
					last if ($v eq '');
					}
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
	close(CONF);
	}
return \@get_config_cache;
}

# find_config(name, &config, [disabled-mode])
# Returns the structure(s) with some name
# disabled mode 0 = only enabled, 1 = both, 2 = only disabled,
# 3 = disabled and tags
sub find_config
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
if ($_[2] == 0) {
	@rv = grep { $_->{'enabled'} && !$_->{'tag'} } @rv;
	}
elsif ($_[2] == 1) {
	@rv = grep { !$_->{'tag'} } @rv;
	}
elsif ($_[2] == 2) {
	@rv = grep { !$_->{'enabled'} && !$_->{'tag'} } @rv;
	}
elsif ($_[2] == 3) {
	@rv = grep { !$_->{'enabled'} } @rv;
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &config, [disabled-mode])
# Returns the value of some directive
sub find_value
{
local $rv = &find_config(@_);
return $rv ? $rv->{'value'} : undef;
}

# find_values(name, &config, [disabled-mode])
# Returns the value of some directive
sub find_values
{
local $rv = &find_config(@_);
return $rv ? $rv->{'values'} : undef;
}

# save_value(&config, name, value*)
sub save_value
{
local @v = map { { 'name' => $_[1],
		   'values' => [ $_ ] } } @_[2..@_-1];
&save_directive($_[0], $_[1], \@v);
}

# save_directive(&config, name, &values, [after])
# Given a structure containing a directive name, type, values and members
# add, update or remove that directive in config structure and data files.
sub save_directive
{
local(@oldv, @newv, $i, $o, $n, $lref, $nl, $change);
@oldv = &find_config($_[1], $_[0]);
@newv = map { local %n = %$_; \%n } @{$_[2]};
$lref = &read_file_lines($config{'squid_conf'});
for($i=0; $i<@oldv || $i<@newv; $i++) {
	if ($i >= @oldv) {
		# a new directive is being added.. 
		$nl = &directive_line($newv[$i]);
		local @after = ref($_[3]) ? ( $_[3] ) :
			       $_[3] ? &find_config($_[3], $_[0]) : ( );
		local $after = @after ? @after[$#after] : undef;
		local @comment = &find_config($_[1], $_[0], 3);
		local $comment = @comment ? $comment[$#comment] : undef;
		if ($change &&
		    (!$after || $after->{'line'} < $change->{'line'})) {
			# put it after any directives of the same type
			$newv[$i]->{'line'} = $change->{'line'}+1;
			splice(@$lref, $newv[$i]->{'line'}, 0, $nl);
			&renumber($_[0], $change->{'line'}, 1);
			splice(@{$_[0]}, &indexof($change, @{$_[0]}),
			       0, $newv[$i]);
			$change = $newv[$i];
			}
		elsif ($comment) {
			# put it after commented line
			$newv[$i]->{'line'} = $comment->{'line'}+1;
			splice(@$lref, $newv[$i]->{'line'}, 0, $nl);
			&renumber($_[0], $comment->{'line'}, 1);
			splice(@{$_[0]}, &indexof($comment, @{$_[0]}),
			       0, $newv[$i]);
			}
		else {
			# put it at the end of the file
			$newv[$i]->{'line'} = scalar(@$lref);
			push(@$lref, $nl);
			push(@{$_[0]}, $newv[$i]);
			}
		}
	elsif ($i >= @newv) {
		# a directive was deleted
		splice(@$lref, $oldv[$i]->{'line'}, 1);
		&renumber($_[0], $oldv[$i]->{'line'}, -1);
		splice(@{$_[0]}, &indexof($oldv[$i], @{$_[0]}), 1);
		}
	else {
		# updating some directive
		$newv[$i]->{'postcomment'} = $oldv[$i]->{'postcomment'};
		$nl = &directive_line($newv[$i]);
		local @after = $change && $_[3] ? ( $change ) :
							# After last one updated
			       ref($_[3]) ? ( $_[3] ) :	# After specific
			       $_[3] ? &find_config($_[3], $_[0]) : ( );
		local $after = @after ? @after[$#after] : undef;
		if ($after && $oldv[$i]->{'line'} < $after->{'line'}) {
			# Need to move it after some directive
			splice(@$lref, $oldv[$i]->{'line'}, 1);
			splice(@{$_[0]}, &indexof($oldv[$i], @{$_[0]}), 1);
			&renumber($_[0], $oldv[$i]->{'line'}, -1);

			splice(@$lref, $after->{'line'}+1, 0, $nl);
			$newv[$i]->{'line'} = $after->{'line'}+1;
			splice(@{$_[0]}, &indexof($after, @{$_[0]})+1, 0,
			       $newv[$i]);
			&renumber($_[0], $newv[$i]->{'line'}, 1);
			$change = $newv[$i];
			}
		else {
			# Can just update at the same line
			splice(@$lref, $oldv[$i]->{'line'}, 1, $nl);
			$newv[$i]->{'line'} = $oldv[$i]->{'line'};
			$_[0]->[&indexof($oldv[$i], @{$_[0]})] = $newv[$i];
			$change = $newv[$i];
			}
		}
	}
}

# directive_line(&details)
sub directive_line
{
local @v = @{$_[0]->{'values'}};
return $_[0]->{'name'}.(@v ? " ".join(' ',@v) : "").
       ($_[0]->{'postcomment'} ? " #".$_[0]->{'postcomment'} : "");
}

# renumber(&directives, line, count, [end])
# Runs through the given array of directives and increases the line numbers
# of all those greater than some line by the given count
sub renumber
{
local($d);
foreach $d (@{$_[0]}) {
	if ($d->{'line'} > $_[1] && (!$_[3] || $d->{'line'} < $_[3])) {
		$d->{'line'} += $_[2];
		}
	}
}

1;

