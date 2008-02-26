# procmail-lib.pl
# Functions for parsing the .procmailrc file

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%minfo = &get_module_info($module_name);
if ($minfo{'usermin'}) {
	&switch_to_remote_user();
	&create_user_config_dirs();
	$procmailrc = "$remote_user_info[7]/.procmailrc";
	$includes = $userconfig{'includes'};
	}
else {
	$procmailrc = $config{'procmailrc'};
	$includes = $config{'includes'};
	}

# get_procmailrc()
# Parses the .procmailrc file into recipes
sub get_procmailrc
{
return &parse_procmail_file($procmailrc);
}

# parse_procmail_file(file)
sub parse_procmail_file
{
local (@rv, $rec, $_);
local $lnum = 0;
local $fh = $_[0];
open($fh, $_[0]);
while(<$fh>) {
	local $slnum = $lnum;
	s/\s+$//;
	while(s/\\$//) {
		local $cont = <$fh>;
		$cont =~ s/\s+$//;
		$cont =~ s/^\s+//;
		$_ .= $cont;
		$lnum++;
		}
	while(/^\s*([^\s=]+)\s*=([^"]*)"([^"]*)$/) {
		# Quote in environment variable that is not ended!
		local $cont = <$fh>;
		$cont =~ s/\r|\n//g;
		$_ .= "\n".$cont;
		$lnum++;
		}
	if (!/^\*/) {
		s/#.*$//;
		s/\s+$//;
		}
	if (/^\s*([^\s=]+)\s*=\s*"((.|\n)*)"$/ ||
	    /^\s*([^\s=]+)\s*=\s*'((.|\n)*)'$/ ||
	    /^\s*([^\s=]+)\s*=\s*((.|\n)*)$/) {
		if ($1 eq "INCLUDERC") {
			local $ifile = $2;
			if ($includes && $ifile !~ /\$/) {
				# Including another file
				local @inc = &parse_procmail_file(
					&make_absolute($ifile, $procmailrc));
				map { $_->{'index'} += scalar(@rv) } @inc;
				push(@rv, @inc);
				}
			else {
				# Just indicate the include
				local $inc = { 'index' => scalar(@rv),
					       'file' => $_[0],
					       'line' => $slnum,
					       'eline' => $lnum,
					       'include' => $ifile };
				push(@rv, $inc);
				}
			}
		elsif ($1 eq "SWITCHRC") {
			# Change to another file
			local @inc = &parse_procmail_file(
					&make_absolute("$2", $procmailrc));
			map { $_->{'index'} += scalar(@rv) } @inc;
			push(@rv, @inc);
			last;
			}
		elsif ($rec) {
			# Environment variable as action for recipe
			$rec->{'type'} = "=";
			$rec->{'action'} = "$1=$2";
			$rec->{'eline'} = $lnum;
			$rec = undef;
			}
		else {
			# Environment variable assignment
			local $env = { 'index' => scalar(@rv),
				       'file' => $_[0],
				       'line' => $slnum,
				       'eline' => $lnum,
				       'name' => $1,
				       'value' => $2 };
			push(@rv, $env);
			}
		}
	elsif (/^\s*:0\s*(\S*)\s*:\s*(.*)$/ || /^:0\s*(\S*)/) {
		# Start of a new recipe
		$rec = { 'index' => scalar(@rv),
			 'file' => $_[0],
			 'line' => $slnum,
			 'eline' => $lnum,
			 'lockfile' => $2,
			 'flags' => [ split(//, $1) ] };
		push(@rv, $rec);
		}
	elsif (/^\s*\*\s*(\!|\$|\?|<|>|)(.*)$/) {
		# A condition for a recipe
		push(@{$rec->{'conds'}}, [ $1, $2 ]);
		$rec->{'eline'} = $lnum;
		}
	elsif (/^\s*\{\s*$/) {
		# A conditional action .. read till the end
		local $nest = 1;
		$rec->{'block'} = "";
		while(<$fh>) {
			$lnum++;
			if (/^\{\s*$/) {
				$nest++;
				}
			elsif (/^\}\s*$/) {
				last if (!--$nest);
				}
			$rec->{'block'} .= $_;
			}
		$rec->{'eline'} = $lnum;
		$rec = undef;
		}
	elsif (/^\s*\{(.*)\}\s*$/) {
		# A single-line conditional action .. 
		$rec->{'block'} = $1;
		$rec->{'eline'} = $lnum;
		$rec = undef;
		}
	elsif (/^\s*(\!|\|)\s*(.*)$/) {
		# The action for a recipe
		$rec->{'type'} = $1;
		$rec->{'action'} = $2;
		$rec->{'eline'} = $lnum;
		$rec = undef;
		}
	elsif (/\S/) {
		if ($rec->{'action'}) {
			# Unknown line
			&error(&text('config_eline', $slnum+1,
				     $_[0], "<tt>$_</tt>"));
			}
		else {
			# File delivery action
			$rec->{'type'} = undef;
			$rec->{'action'} = $_;
			$rec->{'eline'} = $lnum;
			if ($rec->{'action'} =~ /^\"(.*)\"$/) {
				# Quoted path .. un-quote
				$rec->{'action'} = $1;
				}
			$rec = undef;
			}
		}
	$lnum++;
	}
close($fh);
return @rv;
}

# create_recipe(&recipe, [file])
sub create_recipe
{
local $lref = &read_file_lines($_[1] || $procmailrc);
push(@$lref, &recipe_lines($_[0]));
&flush_file_lines();
}

# create_recipe_before(&recipe, &before, [file])
sub create_recipe_before
{
local $lref = &read_file_lines($_[2] || $procmailrc);
local @lines = &recipe_lines($_[0]);
splice(@$lref, $_[1]->{'line'}, 0, @lines);
$_[1]->{'line'} += @lines;
$_[1]->{'eline'} += @lines;
&flush_file_lines();
}

# delete_recipe(&recipe)
sub delete_recipe
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

# modify_recipe(&recipe)
sub modify_recipe
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &recipe_lines($_[0]));
&flush_file_lines();
}

# swap_recipes(&recipe1, &recipe2)
sub swap_recipes
{
local $lref0 = &read_file_lines($_[0]->{'file'});
local $lref1 = &read_file_lines($_[1]->{'file'});
local @lines0 = @$lref0[$_[0]->{'line'} .. $_[0]->{'eline'}];
local @lines1 = @$lref1[$_[1]->{'line'} .. $_[1]->{'eline'}];
if ($_[0]->{'line'} < $_[1]->{'line'}) {
	splice(@$lref1, $_[1]->{'line'}, $_[1]->{'eline'} - $_[1]->{'line'} + 1,
	       @lines0);
	splice(@$lref0, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
	       @lines1);
	}
else {
	splice(@$lref0, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
	       @lines1);
	splice(@$lref1, $_[1]->{'line'}, $_[1]->{'eline'} - $_[1]->{'line'} + 1,
	       @lines0);
	}
&flush_file_lines();
}

sub recipe_lines
{
if ($_[0]->{'name'}) {
	# Environment variable
	local $v = $_[0]->{'value'} =~ /\n/ ? $_[0]->{'value'} :
		   $_[0]->{'value'} =~ /^\`/ ? $_[0]->{'value'} :
		   $_[0]->{'value'} =~ /^\S+$/ ? $_[0]->{'value'} :
		   $_[0]->{'value'} =~ /"/ ? "'$_[0]->{'value'}'" :
					    "\"$_[0]->{'value'}\"";
	return ( $_[0]->{'name'}."=".$v );
	}
elsif ($_[0]->{'include'}) {
	# Included file
	local $v = $_[0]->{'include'} =~ /^\`/ ? $_[0]->{'include'} :
		   $_[0]->{'include'} =~ /^\S+$/ ? $_[0]->{'include'} :
		   $_[0]->{'include'} =~ /"/ ? "'$_[0]->{'include'}'" :
					    "\"$_[0]->{'include'}\"";
	return ( "INCLUDERC=".$v );
	}
else {
	# Recipe with conditions and action
	local (@rv, $c);
	push(@rv, ":0".join("", @{$_[0]->{'flags'}}));
	if (defined($_[0]->{'lockfile'})) {
		$rv[0] .= ":".$_[0]->{'lockfile'};
		}
	foreach $c (@{$_[0]->{'conds'}}) {
		push(@rv, "* ".$c->[0].$c->[1]);
		}
	if (defined($_[0]->{'block'})) {
		push(@rv, "{", split(/\n/, $_[0]->{'block'}), "}");
		}
	elsif ($_[0]->{'type'} && $_[0]->{'type'} ne '=') {
		push(@rv, $_[0]->{'type'}." ".$_[0]->{'action'});
		}
	elsif ($_[0]->{'action'} !~ /^\S+$/) {
		# File with a space .. need to quote
		push(@rv, "\"$_[0]->{'action'}\"");
		}
	else {
		# File delivery
		push(@rv, $_[0]->{'action'});
		}
	return @rv;
	}
}

# parse_action(&recipe)
sub parse_action
{
if ($_[0]->{'type'} eq '|') {
	return (4, $_[0]->{'action'});
	}
elsif ($_[0]->{'type'} eq '!') {
	return (3, $_[0]->{'action'});
	}
elsif ($_[0]->{'type'} eq '=') {
	local ($n, $v) = split(/=/, $_[0]->{'action'}, 2);
	return (6, $n);
	}
elsif (defined($_[0]->{'block'})) {
	return (5);
	}
elsif ($_[0]->{'action'} =~ /^(.*)\/$/) {
	return (2, $1);
	}
elsif ($_[0]->{'action'} =~ /^(.*)\/\.$/) {
	return (1, $1);
	}
else {
	return (0, $_[0]->{'action'});
	}
}

# make_absolute(file, basefile)
sub make_absolute
{
return $_[0] if ($_[0] =~ /^\//);
$_[1] =~ /^(.*)\/[^\/]+$/;
return "$1/$_[0]";
}

@known_flags = ('H', 'B', 'D', 'h', 'b', 'c', 'w', 'W', 'i', 'r', 'f');

1;

