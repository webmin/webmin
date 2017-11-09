# dhcpd-lib.pl
# Functions for parsing the DHCPD config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# get_parent_config([file])
# Returns a dummy parent structure for the DHCP config
sub get_parent_config
{ 
local ($file) = @_;
$file ||= $config{'dhcpd_conf'};
return $get_parent_config_cache{$file} if ($get_parent_config_cache{$file});
return $get_parent_config_cache{$file} = {
	 'file' => $file,
	 'members' => &get_config($file),
	 'line' => -1,
	 'fline' => -1,
	 'eline' => $get_config_lines };
}

# get_config([file])
# Parses the DHCPD config file into a data structure
sub get_config
{
local ($file) = @_;
$file ||= $config{'dhcpd_conf'};
return $get_config_cache{$file} if ($get_config_cache{$file});
local @rv = &get_config_file($file, \$get_config_lines);
$get_config_cache{$file} = \@rv;
return $get_config_cache{$file};
}

# get_config_file(file, [&lines])
sub get_config_file
{
local (@tok, $i, $j, @rv, $c);
$i = 0; $j = 0;
local $lines = &tokenize_file($_[0], \@tok);
${$_[1]} = $lines if ($_[1]);
while($i < @tok) {
	local $str = &parse_struct(\@tok, \$i, $j++, $_[0]);
	if ($str) {
		if ($str->{'name'} eq 'include') {
			# Expand the include directive
			local $p = $str->{'values'}->[0];
			if ($p !~ /^\//) {
				$config{'dhcpd_conf'} =~ /^(\S+)\//;
				$p = "$1/$p";
				}
			local @inc = &get_config_file($p);
			$j--;
			foreach $c (@inc) {
				$c->{'index'} += $j;
				}
			push(@rv, @inc);
			$j += scalar(@inc);
			}
		else {
			push(@rv, $str);
			}
		}
	}
return @rv;
}

# tokenize_file(file, &tokens)
sub tokenize_file
{
local $lines = 0;
local ($line, $cmode);
open(FILE, $_[0]);
while($line = <FILE>) {
	# strip comments
	$line =~ s/\r|\n//g;
	$line =~ s/^([^"#]*)#.*$/$1/g;
	$line =~ s/^([^"]*)\/\/.*$/$1/g;
	$line =~ s/^([^"]*)\s+#.*$/$1/g;	# remove stuff after #, unless
	$line =~ s/^(.*".*".*)\s+#.*$/$1/g;	#  it is inside quotes
	$line =~ s/\\\\/\\134/g;		# convert \\ into \134
	$line =~ s/([^\\])\\"/$1\\042/g;	# convert escaped quotes to \042
	while(1) {
		if (!$cmode && $line =~ /\/\*/ && $line !~ /\".*\/\*.*\"/) {
			# start of a C-style comment
			$cmode = 1;
			$line =~ s/\/\*.*$//g;
			}
		elsif ($cmode) {
			if ($line =~ /\*\//) {
				# end of comment
				$cmode = 0;
				$line =~ s/^.*\*\///g;
				}
			else { $line = ""; last; }
			}
		else { last; }
		}

	# split line into tokens
	while(1) {
		if ($line =~ /^\s*"([^"]*)"(.*)$/) {
			push(@{$_[1]}, [ $1, 1, $lines ]); $line = $2;
			}
		elsif ($line =~ /^\s*([{};,])(.*)$/) {
			push(@{$_[1]}, [ $1, 0, $lines ]); $line = $2;
			}
		elsif ($line =~ /^\s*([^{}; \t,]+)(.*)$/) {
			push(@{$_[1]}, [ $1, 0, $lines ]); $line = $2;
			}
		else { last; }
		}
	$lines++;
	}
close(FILE);
#print STDERR "tokenized $_[0] into $lines\n";
return $lines;
}

# parse_struct(&tokens, &token_num, index, file)
# A structure can either have one value, or a list of values.
# Pos will end up at the start of the next structure
sub parse_struct
{
local(%str, $i, $t, @vals, @quotes, $str, @text);
local $lref = &read_file_lines($_[3]);
$i = ${$_[1]};
$str{'name'} = $_[0]->[$i]->[0];
$str{'line'} = $_[0]->[$i]->[2];
if ($str{'line'} && $lref->[$str{'line'}-1] =~ /^\s*(#|\/\/)\s*(.*)/) {
	# Previous line is a comment, so include it in the directive
	$str{'line'}--;
	$str{'comment'} = $2;
	}
#print STDERR "parsing at line $str{'line'} = $str{'name'}\n";
while(1) {
	# Add values between directive name and { or ;
	$t = $_[0]->[++$i];
	if (($t->[0] eq "{" && $str{'name'} ne 'option') ||
	    $t->[0] eq ";") { last; }
	elsif (!defined($t->[0])) { ${$_[1]} = $i; return undef; }
	else { push(@vals, $t->[0]); push(@quotes, $t->[1]); }
	push(@text, $t->[1] ? "\"$t->[0]\"" : $t->[0]);
	}
$str{'values'} = \@vals;
$str{'quotes'} = \@quotes;
$str{'value'} = $vals[0];
$str{'text'} = join(" ", @text);
$str{'index'} = $_[2];
$str{'file'} = $_[3];
$str{'fline'} = $_[0]->[$i]->[2];
if ($t->[0] eq "{") {
	# contains sub-structures.. parse them
	local(@mems, $j);
	$i++;		# skip {
	$str{'type'} = 1;
	$j = 0;
	while($_[0]->[$i]->[0] ne "}") {
		if (!defined($_[0]->[$i]->[0]))
			{ ${$_[1]} = $i; return undef; }
		$str = &parse_struct($_[0], \$i, $j++, $_[3]);
		if ($str) {
			$str->{'parent'} = \%str;
			push(@mems, $str);
			}
		}
	$str{'members'} = \@mems;
	$i++;		# skip trailing }
	}
else {
	# only a single value..
	$str{'type'} = 0;
	$i++;	# skip trailing ;
	}
$str{'eline'} = $_[0]->[$i-1]->[2];	# ending line is the line number the
					# trailing ; is on
${$_[1]} = $i;
return \%str;
}

# find(name, &array)
sub find
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_value(name, &array)
sub find_value
{
local(@v);
@v = &find($_[0], $_[1]);
if (!@v) { return undef; }
elsif (wantarray) { return map { $_->{'value'} } @v; }
else { return $v[0]->{'value'}; }
}

# choice_input(text, name, &config, [display, option]+)
sub choice_input
{
local($rv, $v, $i, @ops);
$rv = "<td><b>$_[0]</b></td> <td>";
$v = &find_value($_[1], $_[2]);
for($i=3; $i<@_; $i+=2) {
	@ops = split(/,/, $_[$i+1]);
	$rv .= "<input type=radio name=$_[1] value=\"$ops[0]\" ".
		($v eq $ops[0] ? "checked" : "").">$_[$i]\n";
	}
return $rv."</td>\n";
}

# wide_choice_input(text, name, &config, [display, option]+)
sub wide_choice_input
{
local($rv, $v, $i, @ops);
$rv = "<td><b>$_[0]</b></td> <td colspan=3>";
$v = &find_value($_[1], $_[2]);
for($i=3; $i<@_; $i+=2) {
	@ops = split(/,/, $_[$i+1]);
	$rv .= "<input type=radio name=$_[1] value=\"$ops[0]\" ".
		($v eq $ops[0] ? "checked" : "").">$_[$i]\n";
	}
return $rv."</td>\n";
}

# save_choice(name, &parent, indent)
sub save_choice
{
local($nd);
if ($in{$_[0]}) { $nd = { 'name' => $_[0], 'values' => [ $in{$_[0]} ] }; }
&save_directive($_[1], $_[0], $nd ? [ $nd ] : [ ], $_[2], 1);
}

# addr_match_input(text, name, &config)
# A field for editing a list of addresses, ACLs and partial IP addresses
sub addr_match_input
{
local($v, $rv, $av, @av);
$v = &find($_[1], $_[2]);
$rv = "<td><b>$_[0]</b></td> <td>";
$rv .= "<input type=radio name=$_[1]_def value=1 ".
       ($v ? "" : "checked").">Default ";
$rv .= "<input type=radio name=$_[1]_def value=0 ".
       ($v ? "checked" : "").">Listed..<br>";
foreach $av (@{$v->{'members'}}) { push(@av, $av->{'name'}); }
$rv .= "<textarea name=$_[1] rows=3 cols=15>".
	join("\n", @av)."</textarea></td>\n";
}

sub save_addr_match
{
local($addr, @vals, $dir);
if ($in{"$_[0]_def"}) { &save_directive($_[1], $_[0], [ ], $_[2], 1); }
else {
	foreach $addr (split(/\s+/, $in{$_[0]})) {
		push(@vals, { 'name' => $addr });
		}
	$dir = { 'name' => $_[0], 'type' => 1, 'members' => \@vals };
	&save_directive($_[1], $_[0], [ $dir ], $_[2], 1);
	}
}

# address_input(text, name, &config, type)
sub address_input
{
local($v, $rv, $av, @av);
$v = &find($_[1], $_[2]);
foreach $av (@{$v->{'members'}}) { push(@av, $av->{'name'}); }
if ($_[3] == 0) {
	# text area
	$rv = "<td><b>$_[0]</b></td> <td>";
	$rv .= "<textarea name=$_[1] rows=3 cols=15>".
		join("\n", @av)."</textarea></td>\n";
	}
else {
	$rv = "<td><b>$_[0]</b></td> <td colspan=3>";
	$rv .= "<input name=$_[1] size=50 value=\"".join(' ',@av)."\"></td>\n";
	}
return $rv;
}

sub save_address
{
local($addr, @vals, $dir);
foreach $addr (split(/\s+/, $in{$_[0]})) {
	&check_ipaddress($addr) || &error("'$addr' is not a valid IP address");
	push(@vals, { 'name' => $addr });
	}
$dir = { 'name' => $_[0], 'type' => 1, 'members' => \@vals };
&save_directive($_[1], $_[0], @vals ? [ $dir ] : [ ], $_[2], 1);
}

# opt_input(text, name, &config, default, size, units)
# Returns HTML for an optional text field
sub opt_input
{
local($v, $rv);
$v = &find($_[1], $_[2]);
$rv = "<td valign=middle><b>$_[0]</b></td><td valign=middle nowrap";
$rv .= $_[4] > 30 ? " colspan=3>\n" : ">\n";
$rv .= &ui_radio($_[1]."_def", ( $v ? 0 : 1 ), [ [ 1, $_[3] ], [ 0, "&nbsp;" ] ]);
$rv .= &ui_textbox($_[1], ( $v ? $v->{'value'} : "" ), $_[4])."&nbsp;".$_[5];
$rv .= "</td>";
#$rv .= sprintf "<input type=radio name=$_[1]_def value=1 %s> $_[3]\n",
#	$v ? "" : "checked";
#$rv .= sprintf "<input type=radio name=$_[1]_def value=0 %s> ",
#	$v ? "checked" : "";
#$rv .= sprintf "<input name=$_[1] size=$_[4] value=\"%s\"> $_[5]</td>\n",
#	$v ? $v->{'value'} : "";
return $rv;
}

# save_opt(name, &func, &parent, [indent], [quote])
# Saves an optional text field
sub save_opt
{
local($dir);
if ($in{"$_[0]_def"}) { &save_directive($_[2], $_[0], [ ], $_[3], 1); }
elsif ($_[1] && ($err = &{$_[1]}($in{$_[0]}))) {
	&error($err);
	}
else {
	$dir = { 'name' => $_[0],
		 'values' => [ $in{$_[0]} ],
		 'quotes' => [ $_[4] ] };
	&save_directive($_[2], $_[0], [ $dir ], $_[3], 1);
	}
}

# save_directive(&parent, [name|&oldvalues], &values, indent, start, [after])
# Given a structure containing a directive name, type, values and members
# add, update or remove that directive in config structure and data files.
# Updating of files assumes that there is no overlap between directives -
# each line in the config file must contain part or all of only one directive.
sub save_directive
{
local(@oldv, @newv, $pm, $i, $o, $n, $lref, @nl);
$pm = $_[0]->{'members'};
@oldv = ref($_[1]) ? @{$_[1]} : &find($_[1], $pm);
@newv = @{$_[2]};
for($i=0; $i<@oldv || $i<@newv; $i++) {
	if ($i >= @oldv && $_[5]) {
		# a new directive is being added.. put it after some other
		$lref = $_[0]->{'file'} ? &read_file_lines($_[0]->{'file'})
					: [ ];
		@nl = &directive_lines($newv[$i], $_[3]);
		$nline = $_[5]->{'line'}+1;
		$nidx = &indexof($_[5], @$pm) + 1;
		splice(@$lref, $nline, 0, @nl);
		&renumber(&get_config(), $nline,
			  $_[0]->{'file'}, scalar(@nl));
		&renumber_index($_[0]->{'members'}, $nidx, 1);
		$newv[$i]->{'index'} = $nidx;
		$newv[$i]->{'file'} = $_[0]->{'file'};
		$newv[$i]->{'line'} = $nline;
		$newv[$i]->{'eline'} = $nline + scalar(@nl);
		splice(@$pm, $nidx, 0, $newv[$i]);
		}
	elsif ($i >= @oldv && $_[4]) {
		# a new directive is being added.. put it at the start of
		# the parent
		$lref = $_[0]->{'file'} ? &read_file_lines($_[0]->{'file'})
					: [ ];
		@nl = &directive_lines($newv[$i], $_[3]);
		$nline = $_[0]->{'fline'}+1;
		splice(@$lref, $nline, 0, @nl);
		&renumber(&get_config(), $nline,
			  $_[0]->{'file'}, scalar(@nl));
		&renumber_index($_[0]->{'members'}, 0, 1);
		$newv[$i]->{'file'} = $_[0]->{'file'};
		$newv[$i]->{'line'} = $nline;
		$newv[$i]->{'eline'} = $nline + scalar(@nl);
		unshift(@$pm, $newv[$i]);
		}
	elsif ($i >= @oldv) {
		# a new directive is being added.. put it at the end of
		# the parent
		$lref = $_[0]->{'file'} ? &read_file_lines($_[0]->{'file'}) : [ ];
		@nl = &directive_lines($newv[$i], $_[3]);
		splice(@$lref, $_[0]->{'eline'}, 0, @nl);
		&renumber(&get_config(), $_[0]->{'eline'},
			  $_[0]->{'file'}, scalar(@nl));
		$newv[$i]->{'file'} = $_[0]->{'file'};
		$newv[$i]->{'line'} = $_[0]->{'eline'};
		$newv[$i]->{'eline'} = $_[0]->{'eline'} + scalar(@nl) - 1;
		push(@$pm, $newv[$i]);
		}
	elsif ($i >= @newv) {
		# a directive was deleted
		$lref = $oldv[$i]->{'file'} ? &read_file_lines($oldv[$i]->{'file'}) : [ ];
		$ol = $oldv[$i]->{'eline'} - $oldv[$i]->{'line'} + 1;
		splice(@$lref, $oldv[$i]->{'line'}, $ol);
		&renumber(&get_config(), $oldv[$i]->{'eline'},
			  $oldv[$i]->{'file'}, -$ol);
		&renumber_index($_[0]->{'members'}, $oldv[$i]->{'index'}, -1);
		splice(@$pm, &indexof($oldv[$i], @$pm), 1);
		}
	else {
		# updating some directive
		if (!defined($newv[$i]->{'comment'})) {
			$newv[$i]->{'comment'} = $oldv[$i]->{'comment'};
			}
		$lref = $oldv[$i]->{'file'} ? &read_file_lines($oldv[$i]->{'file'}) : [ ];
		@nl = &directive_lines($newv[$i], $_[3]);
		$ol = $oldv[$i]->{'eline'} - $oldv[$i]->{'line'} + 1;
		splice(@$lref, $oldv[$i]->{'line'}, $ol, @nl);
		&renumber(&get_config(), $oldv[$i]->{'eline'},
			  $oldv[$i]->{'file'}, scalar(@nl) - $ol);
		$newv[$i]->{'file'} = $_[0]->{'file'};
		$newv[$i]->{'line'} = $oldv[$i]->{'line'};
		$newv[$i]->{'eline'} = $oldv[$i]->{'line'} + scalar(@nl) - 1;
		$pm->[&indexof($oldv[$i], @$pm)] = $newv[$i];
		}
	}
}

# directive_lines(&directive, tabs)
# Renders some directive into a number of lines of text
sub directive_lines
{
local(@rv, $v, $m, $i);
if ($_[0]->{'comment'}) {
	push(@rv, ("\t" x $_[1])."# ".$_[0]->{'comment'});
	}
local $first = "\t" x $_[1];
$first .= "$_[0]->{'name'}";
for($i=0; $i<@{$_[0]->{'values'}}; $i++) {
	$v = $_[0]->{'values'}->[$i];
	if ($_[0]->{'quotes'}->[$i]) { $first .= " \"$v\""; }
	else { $first .= " $v"; }
	}
push(@rv, $first);
if ($_[0]->{'type'}) {
	# multiple values.. include them as well
	$rv[$#rv] .= " {";
	foreach $m (@{$_[0]->{'members'}}) {
		push(@rv, &directive_lines($m, $_[1]+1));
		}
	push(@rv, ("\t" x ($_[1]+1))."}");
	}
else { $rv[$#rv] .= ";"; }
return @rv;
}

# renumber(&directives, line, file, count)
# Runs through the given array of directives and increases the line numbers
# of all those greater than some line by the given count
sub renumber
{
local($d);
local ($list, $line, $file, $count) = @_;
return if (!$count);
foreach $d (@$list) {
	if ($d->{'file'} eq $file) {
		if ($d->{'line'} >= $line) { $d->{'line'} += $count; }
		if ($d->{'eline'} >= $line) { $d->{'eline'} += $count; }
		}
	if ($d->{'type'}) {
		&renumber($d->{'members'}, $line, $file, $count);
		}
	}
}

# renumber_index(&directives, index, count)
sub renumber_index
{
local($d);
foreach $d (@{$_[0]}) {
	if ($d->{'index'} >= $_[1]) {
		$d->{'index'} += $_[2];
		}
	}
}

# directive_diff(&d1, &d2)
# Do two directives differ?
sub directive_diff
{
local $i;
local ($d1, $d2) = @_;
return 1 if ($d1->{'name'} ne $d2->{'name'});
local $l1 = @{$d1->{'values'}};
local $l2 = @{$d2->{'values'}};
return 1 if ($l1 != $l2);
for($i=0; $i<$l1; $i++) {
	return 1 if ($d1->{'values'}->[$i] ne $d2->{'values'}->[$i]);
	}
return 1 if ($d1->{'type'} != $d2->{'type'});
if ($d1->{'type'}) {
	$l1 = @{$d1->{'members'}};
	$l2 = @{$d2->{'members'}};
	return 1 if ($l1 != $l2);
	for($i=0; $i<$l1; $i++) {
		return 1 if (&directive_diff($d1->{'members'}->[$i],
					     $d2->{'members'}->[$i]));
		}
	}
return 0;
}

# group_name(&members, &group)
sub group_name
{
local @opts = &find("option", $_[1]->{'members'});
local ($dn) = grep { $_->{'values'}->[0] eq 'domain-name' } @opts;
return  $config{'group_name'} == 1 && $dn ?
		&text('index_gdom',$dn->{'values'}->[1]) :
	$config{'group_name'} == 2 && $_[1]->{'comment'} ?
		$_[1]->{'comment'} :
	$_[1]->{'values'}->[0] ? $_[1]->{'values'}->[0] :
        $_[0] == 0 ? $text{'index_nomemb'} :
	$_[0] == 1 ? $text{'index_1memb'} :
	$_[0] >= 2 && $_[0] <= 4 ? &text('index_234memb', $_[0]) :
	&text('index_memb', $_[0]);

}

# get_subnets_and_hosts() 
# returns the references to sorted lists of hosts and subnets
sub get_subnets_and_hosts
{
return (\@get_subnets_cache, \@get_hosts_cache) 
	if (@get_subnets_cache && @get_hosts_cache);

local(@subn,@host,@group,@shan, $s,$h,$g,$sn, $conf);
$conf = &get_config();

# get top level hosts and groups
@host = &find("host", $conf);
foreach $h (&find("host", $conf)) {
	$h->{'order'} = $h->{'index'};
	}
@group = &find("group", $conf);
foreach $g (@group) {
	foreach $h (&find("host", $g->{'members'})) {
		push(@host, $h);
		}
	}
@subn = &find("subnet", $conf);
foreach $u (@subn) {
	foreach $h (&find("host", $u->{'members'})) {
		push(@host, $h);
		}
	foreach $g (&find("group", $u->{'members'})) {
		push(@group, $g);
		foreach $h (&find("host", $g->{'members'})) {
			push(@host, $h);
			}
		}
	}
@shan = &find("shared-network", $conf);
foreach $s (@shan) {
	foreach $h (&find("host", $s->{'members'})) {
		push(@host, $h);
		}
	foreach $g (&find("group", $s->{'members'})) {
		push(@group, $g);
		foreach $h (&find("host", $g->{'members'})) {
			push(@host, $h);
			}
		}
	foreach $u (&find("subnet", $s->{'members'})) {
		push(@subn, $u);
		foreach $h (&find("host", $u->{'members'})) {
			push(@host, $h);
			}
		foreach $g (&find("group", $sn->{'members'})) {
			push(@group, $g);
			foreach $h (&find("host", $g->{'members'})) {
				push(@host, $h);
				}
			}
		}
	}
@get_subnets_cache = sort { $a->{'order'} <=> $b->{'order'} } @subn;
@get_hosts_cache = sort { $a->{'order'} <=> $b->{'order'} } @host;

return (\@get_subnets_cache, \@get_hosts_cache);
}

sub get_subnets
{
local ($sr, $hr) = &get_subnets_and_hosts();
return @{$sr};
}

sub get_hosts
{
local ($sr, $hr) = &get_subnets_and_hosts();
return @{$hr};
}

sub get_host_shared_network
{
local ($h) = @_;
local $shar;
while($h) {
	if ($h->{'name'} eq 'shared-network') {
		return $h;
		}
	$h = $h->{'parent'};
	}
return undef;
}

sub get_my_shared_network_hosts
{
local ($h) = @_;
local $shar = &get_host_shared_network($h);
local @rv;
foreach my $oh (&get_hosts()) {
	if (&get_host_shared_network($oh) eq $shar) {
		push(@rv, $oh);
		}
	}
return @rv;
}

# hash that links objtypes shortcuts with object names
%obj_names2types = qw(host hst group grp subnet sub shared-network sha);

# get_branch(objtype, [addmode]) 
# useful for edit_*.cgi and save_*.cgi scripts
# $objtype = one of 'hst' 'grp' 'sub' 'sha'
sub get_branch
{
local %obj_types2names = reverse %obj_names2types;
local $name = $obj_types2names{$_[0]};
local ($parnode, $nparnode, $node, $indent, $nindent);
$parnode = $nparnode = &get_parent_config(
	$_[1] && $in{'sidx'} eq '' && $in{'uidx'} eq '' && $in{'gidx'} eq '' &&
	$in{'parent'} eq '' ? $config{'add_file'} : undef);
$indent = $nindent = 0;
foreach ($in{'sidx'}, $in{'uidx'}, $in{'gidx'}) {
    if ($_ ne '') {
		$parnode = $parnode->{'members'}->[$_];
		$indent++;
		}
    }

if (!($in{'delete'} && $in{'options'})) {
	if ($in{'assign'} > 0 && !defined($in{'parent'})) {
		# A quirk for not javascript-capable browser
		# New parent is undefined yet; we need 2nd step
		undef $nparnode;
		}
	else {
		foreach (split(/\,/, $in{'parent'})) {
			$nindent++;
			if ($_ < @{$nparnode->{'members'}}) {
				$nparnode = $nparnode->{'members'}->[$_];
				}
			}
		}
	}

if (!$in{'new'}) {
	$node = $parnode->{'members'}->[$in{'idx'}];
	}
else {
	die "Wrong call to get_nodes: pass objtype for new object" unless $name;
	# Construct new node structure
	$node->{'name'} = $name;
	$node->{'type'} = 1;
	$node->{'members'} = [ ];
	}
return ($parnode, $node, $indent, $nparnode, $nindent);
}

# can(permissions_string, \%access, \%config_node, smode)
# this is a cached wrapper of can_noncached(...)
sub can
{
local ($perm, $acc, $node, $smode) = @_;
if (defined($can_cache) &&
	($can_perm_cache eq $perm) &&
	($can_node_cache eq $node) &&
	($can_smode_cache eq $smode)) {
	return $can_cache;
	}
else {
	$can_perm_cache = $perm;
	$can_node_cache = $node;
	$can_smode_cache = $smode;
	return ($can_cache = &can_noncached(@_));
	}
}

# can_noncached(permissions_string, \%access, \%config_node, smode)
# check global and per-object permissions:
#
# permissions_string= 'c' 'r' 'w' or any combination.
# smode= 0 or undef - check only current, 1 - recursive childs check, 
#	2 - check parents, 3 - check parents and all childs
#	note: while deleting an object you must allways enforce smode=1 or 3
#		because all child objects are deletes recursevly. 
#	this maybe an optional parameter 
sub can_noncached
{
local $acl;
local ($perm, $acc, $node, $smode) = @_;
local @perm = split(//, $perm);

if ($node ne get_parent_config() &&
    $node ne get_parent_config($config{'add_file'})) {
	foreach (@perm) { 
		next if ($_ ne 'c') &&  ($_ ne 'r') && ($_ ne 'w');
		return 0 unless $acc->{$_ . '_' . $obj_names2types{$node->{'name'}} };
		}

	# per-object permissions
	return 0 unless &can_node(\@perm, $acc, $node);

	if (($acc->{'smode'} == 2) || ($smode == 2) ||
	    ($acc->{'smode'} == 3) || ($smode == 3)) {
		# check parents
		#$parnode=&get_parent_config();
		#foreach ($in{'sidx'}, $in{'uidx'}, $in{'gidx'}) {
		#	if ($_ ne '') {
		#		$parnode = $parnode->{'members'}->[$_];
		#		return 0 unless &can_node(\@perm, $acc, $parnode);
		#		}
		#	}
		$parnode = $node->{'parent'};
		while($parnode) {
			return 0 unless &can_node(\@perm, $acc, $parnode);
			$parnode = $parnode->{'parent'};
			}
		}
		
	if (($acc->{'smode'} == 1) || ($smode == 1) ||
		($acc->{'smode'} == 3) || ($smode == 3)) {
		# check childs
		return 0 unless &can_subtree(\@perm, $acc, $node);
		}
	}
return 1;
}

# can_node(\@perm, $acc, $node)
# checks object permissions for current node
sub can_node
{
local ($rperm, $acc, $node)=@_;
# per-object permissions
local $otype=$obj_names2types{$node->{'name'}};
if ($acc->{'per_' . $otype . '_acls'}) {  
	local $name = $node->{'values'}->[0];
	if (!$name && $node->{'name'} eq 'group') {
		local @opts = &find("option", $node->{'members'});
		local ($dn) = grep { $_->{'values'}->[0] eq 'domain-name' }
				   @opts;
		if ($dn) {
			$name = $dn->{'values'}->[1];
			}
		else {
			$name = $node->{'index'};
			}
		}
	local $acl = $acc->{'ACL' . $otype . '_' . $name};
	foreach (@{$rperm}) {
		next if $_ eq 'c'; # skip creation perms for per-obj acls
		return 0 if index($acl, $_) == -1;
		}
	}
return 1;
}

# can_subtree(\@perm, $acc, $node)
# checks object permissions for subtree
sub can_subtree
{
local ($rperm, $acc, $node)=@_;
return 0 unless &can_node($rperm, $acc, $node); 
if($node->{'members'}) {
	# recursevly process this subtree
	foreach (@{$node->{'members'}}) {
		return 0 unless &can_subtree($rperm, $acc, $_);
		}
	}
return 1;	
}

# save_dhcpd_acl(permissions_string, obj_type, \%access, obj_name)
sub save_dhcpd_acl
{
$_[2]->{'ACL'.$_[1].'_'.$_[3]} = $_[0];
undef($can_cache);
return &save_module_acl($_[2]);
}

# drop_dhcpd_acl(obj_type, \%access, obj_name)
sub drop_dhcpd_acl
{
delete($_[1]->{'ACL'.$_[0].'_'.$_[2]});
undef($can_cache);
return &save_module_acl($_[1]);
}

# find_recursive(name, &config, [parent])
# Returns a list of all config entries with some name, no matter where they
# are in the hierarchy
sub find_recursive
{
local ($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'name'} eq $_[0]) {
		push(@rv, $c);
		}
	if ($c->{'type'}) {
		push(@rv, &find_recursive($_[0], $c->{'members'}, $c));
		}
	}
return @rv;
}

# find_parents(&object)
sub find_parents
{
local ($gidx, $uidx, $sidx);
local $p = $_[0]->{'parent'};
while($p) {
	$gidx = $p->{'index'} if ($p->{'name'} eq 'group');
	$uidx = $p->{'index'} if ($p->{'name'} eq 'subnet');
	$sidx = $p->{'index'} if ($p->{'name'} eq 'shared-network');
	$p = $p->{'parent'};
	}
return ($gidx, $uidx, $sidx);
}

# get_dhcpd_version(&out)
sub get_dhcpd_version
{
local $out = `$config{'dhcpd_path'} -v 2>&1`;
${$_[0]} = $out;
return $config{'version'} if ($config{'version'});
return undef if ($out !~ /DHCP/ || $out =~ /V1/);
return $out =~ /\sV([0-9\.]+)/ ? $1 :
       $out =~ /\sDHCP\s+Server\s+([0-9\.]+)/ ? $1 :
       $out =~ /-T/ ? 3 : 2;
}

# restart_dhcpd()
# Re-starts the DHCP server, and returns an error message if something fails
sub restart_dhcpd
{
local $out;
if ($config{'restart_cmd'}) {
	# Run the restart script
	$out = &backquote_logged("$config{'restart_cmd'} 2>&1");
	}
else {
	# Kill and re-run the server
	local $pid = &is_dhcpd_running();
	$pid && &kill_logged('TERM', $pid) ||
		return "$text{'restart_errmsg2'} $pid : $!";
	if ($config{'start_cmd'}) {
		$out = &backquote_logged("$config{'start_cmd'} 2>&1");
		}
	else {
		$out = &backquote_logged("$config{'dhcpd_path'} -cf $config{'dhcpd_conf'} -lf $config{'lease_file'} $config{'interfaces'} 2>&1");
		}
	}
if ($?) {
	return &parse_error_out($out);
	}
return undef;
}

# Find and add config file lines around those in an error message
sub parse_error_out
{
local ($out) = @_;
local $conftext;
if ($out =~ /(\S+)\s+line\s+(\d+):/) {
	local ($file, $line) = ($1, $2);
	local $lref = &read_file_lines($file, 1);
	local $start = $line - 5;
	local $end = $line + 5;
	$start = 0 if ($start < 0);
	$end = @$lref-1 if ($end > @$lref-1);
	$conftext = &text('restart_conftext', $line, $file)."<br>".
	    "<pre>".&html_escape(join("\n", @$lref[$start .. $end]))."</pre>";
	}
return "<pre>".&html_escape($out)."</pre>".$conftext;
}

# stop_dhcpd()
# Stop the running DHCP server. Returns undef on success, or an error message
# on failure.
sub stop_dhcpd
{
if ($config{'stop_cmd'}) {
	local $out = &backquote_logged("($config{'stop_cmd'} 2>&1)");
	return $? ? "<pre>$out</pre>" : undef;
	}
else {
	local $pid = &is_dhcpd_running();
	if ($pid && &kill_logged('TERM', $pid)) {
		return undef;
		}
	else {
		return $text{'stop_ekill'};
		}
	}
}

# start_dhcpd()
# Attempt to start the DHCP server, returning undef on success or an error
# message on failure.
sub start_dhcpd
{
if (!-r $config{'lease_file'}) {
	# first time.. need to create the lease file
	$config{'lease_file'} =~ /^(\S+)\/([^\/]+)$/;
	if (!-d $1) { mkdir($1, 0755); }
	open(LEASE, ">$config{'lease_file'}");
	close(LEASE);
	}
local $out;
if ($config{'start_cmd'}) {
	$out = &backquote_logged("($config{'start_cmd'} 2>&1)");
	}
else {
	$out = &backquote_logged("$config{'dhcpd_path'} -cf $config{'dhcpd_conf'} -lf $config{'lease_file'} $config{'interfaces'} 2>&1");
	}
if ($? || $out =~ /error|failed/i) {
	return &parse_error_out($out);
	}
else {
	return undef;
	}
}

# search_re(value, match)
sub search_re
{
if ($in{'match'} == 0) {
	return lc($_[0]) eq lc($_[1]);
	}
elsif ($in{'match'} == 1) {
	return $_[0] =~ /\Q$_[1]\E/i;
	}
else {
	return eval { $_[0] =~ /$_[1]/i };
	}
}

# get_pid_file()
# Returns the DHCP server PID file
sub get_pid_file
{
local $conf = &get_config();
local $file = &find_value("pid-file-name", $conf);
return $file || $config{'pid_file'};
}

sub expand_ip_range
{
local ($s, $e) = @_;
&foreign_require("net");
local $si = &net::ip_to_integer($s);
local $ei = &net::ip_to_integer($e);
return ( ) if ($si > $ei);
local @rv;
for(my $i=$si; $i<=$ei; $i++) {
	push(@rv, &net::integer_to_ip($i));
	}
return @rv;
}

# is_dhcpd_running()
# Returns the pid if the DHCP server is running
sub is_dhcpd_running
{
local $pidfile = &get_pid_file();
if ($pidfile) {
	return &check_pid_file($pidfile);
	}
else {
	local ($pid) = &find_byname("dhcpd");
	return $pid;
	}
}

sub get_all_config_files
{
my $conf = &get_config();
my @rv = ( $config{'dhcpd_conf'} );
push(@rv, map { $_->{'file'} } @$conf);
push(@rv, $config{'add_file'}) if ($config{'add_file'});
return &unique(@rv);
}

sub lock_all_files
{
foreach my $f (&get_all_config_files()) {
	&lock_file($f);
	}
}

sub unlock_all_files
{
foreach my $f (reverse(&get_all_config_files())) {
	&unlock_file($f);
	}
}

1;
