# cfengine-lib.pl
# Functions for parsing the cfengine config file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

@known_sections = ( 'groups', 'control', 'homeservers', 'binservers',
		    'mailserver', 'mountables', 'broadcast', 'resolve',
		    'defaultroute', 'directories', 'miscmounts', 'files',
		    'ignore', 'tidy', 'required', 'links', 'disable',
		    'shellcommands', 'editfiles', 'processes', 'copy' );
@known_sections = sort { $text{"section_$a"} cmp $text{"section_$b"} }
		       @known_sections;

@known_cfd_sections = ( 'control', 'groups', 'admit', 'deny' );
@known_cfd_sections = sort { $text{"section_$a"} cmp $text{"section_$b"} }
		       @known_cfd_sections;

$cfengine_conf = $config{'cfengine_conf'} ? $config{'cfengine_conf'} :
			"$config{'cfengine_dir'}/cfengine.conf";
$cfd_conf = $config{'cfd_conf'} ? $config{'cfd_conf'} :
			"$config{'cfengine_dir'}/cfd.conf";
$cfrun_hosts = $config{'cfrun_hosts'} ? $config{'cfrun_hosts'} :
			"$config{'cfengine_dir'}/cfrun.hosts";

# get_config()
# Parses the cfengine.conf file into a list of sections, each containing
# a list of classes, each containing options for the section type.
sub get_config
{
if (!scalar(@get_config_cache)) {
	@get_config_cache = &get_config_file($cfengine_conf);
	}
return \@get_config_cache;
}

# get_cfd_config()
# Parses the cfd.conf file
sub get_cfd_config
{
if (!scalar(@get_cfd_config_cache)) {
	@get_cfd_config_cache = &get_config_file($cfd_conf);
	}
return \@get_cfd_config_cache;
}

# get_config_file(file)
# Parses on specified cfengine config file
sub get_config_file
{
# Parse file into tokens
local $lnum = 0;
local @toks;
open(CONFIG, $_[0]);
while(<CONFIG>) {
	s/\r|\n//g;
	s/(^|\s+)#.*$//g;
	local ($s, $q) = &split_str($_);
	local $i;
	for($i=0; $i<@$s; $i++) {
		push(@toks, [ $s->[$i], $lnum, $q->[$i] ]);
		}
	$lnum++;
	}
close(CONFIG);
	
# Parse tokens into the config
local (@rv, $sec, $cls, $i);
push(@rv, { 'type' => 'dummy',	# dummy record so that config is never empty
	    'index' => 0,
	    'line' => -1,
	    'eline' => -1,
	    'file' => $_[0] } );
for($i=0; $i<@toks; $i++) {
	local $t = $toks[$i];
	if ($t->[0] =~ /^(\S+)::$/) {
		# Start of a class
		$cls = { 'name' => $1,
			 'type' => 'class',
			 'index' => scalar(@{$sec->{'cls'}}),
			 'line' => $t->[1],
			 'eline' => $t->[1],
			 'file' => $_[0] };
		$sec->{'eline'} = $t->[1];
		push(@{$sec->{'cls'}}, $cls);
		}
	elsif ($t->[0] =~ /^(\S+):$/) {
		# Start of a section
		$sec = { 'name' => $1,
			 'type' => 'section',
			 'index' => scalar(@rv),
			 'cls' => [ ],
			 'line' => $t->[1],
			 'eline' => $t->[1],
			 'file' => $_[0] };
		undef($cls);
		push(@rv, $sec);
		}
	else {
		# Some kind of text within a class .. create all:: if needed
		if (!$sec) {
			&error("Unknown directive at line ",
				($t->[1]+1)," in $_[0]");
			}
		if (!$cls) {
			$cls = { 'name' => 'any',
				 'type' => 'class',
				 'implied' => 1,
				 'index' => scalar(@{$sec->{'cls'}}),
				 'line' => $t->[1],
				 'eline' => $t->[1],
				 'file' => $_[0] };
			push(@{$sec->{'cls'}}, $cls);
			}

		if ($i+2 < @toks &&
		    $toks[$i+1]->[0] eq '=' &&
		    $toks[$i+2]->[0] eq '(') {
			# A definition with multiple values
			local $def = { 'name' => $t->[0],
				       'line' => $t->[1],
				       'file' => $_[0] };
			$i += 3;
			while($i < @toks && $toks[$i]->[0] ne ')') {
				push(@{$def->{'values'}}, $toks[$i]->[0]);
				push(@{$def->{'valuequotes'}}, $toks[$i]->[2]);
				push(@{$def->{'valuequoted'}},
			            &quote_str($toks[$i]->[0], $toks[$i]->[2]));
				$i++;
				}
			$sec->{'eline'} = $cls->{'eline'} = $toks[$i]->[1];
			push(@{$cls->{'defs'}}, $def);
			}
		elsif ($t->[0] eq '{') {
			# A { } quoted list
			local $list = { 'line' => $t->[1],
					'file' => $_[0] };
			$i++;
			while($i < @toks && $toks[$i]->[0] ne '}') {
				push(@{$list->{'values'}}, $toks[$i]->[0]);
				push(@{$list->{'valuelines'}}, $toks[$i]->[1]);
				push(@{$list->{'valuequotes'}}, $toks[$i]->[2]);
				push(@{$list->{'valuequoted'}},
			            &quote_str($toks[$i]->[0], $toks[$i]->[2]));
				$i++;
				}
			$sec->{'eline'} = $cls->{'eline'} = $toks[$i]->[1];
			push(@{$cls->{'lists'}}, $list);
			}
		else {
			# A single value
			push(@{$cls->{'values'}}, $t->[0]);
			push(@{$cls->{'valuelines'}}, $t->[1]);
			push(@{$cls->{'valuequotes'}}, $t->[2]);
			push(@{$cls->{'valuequoted'}},
				&quote_str($t->[0], $t->[2]));
			$sec->{'eline'} = $cls->{'eline'} = $t->[1];
			}
		}
	}

# Expand import: sections
local @imps = &find("import", \@rv);
foreach $i (@imps) {
	foreach $c (@{$i->{'cls'}}) {
		next if ($c->{'name'} ne 'any');	# XXX only do 'any::'
		foreach $v (@{$c->{'values'}}) {
			local $fn = $v;
			if ($fn !~ /^\//) {
				# Assume relative to current config file
				$fn = "$config{'cfengine_dir'}/$fn";
				}
			local @inc = &get_config_file($fn);
			map { $_->{'index'} += scalar(@rv) } @inc;
			push(@rv, @inc);
			}
		}
	}

return @rv;
}

# find(name, &config)
sub find
{
local ($c, @rv);
foreach $c (@{$_[1]}) {
	push(@rv, $c) if ($c->{'name'} eq $_[0]);
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @f = &find($_[0], $_[1]);
return wantarray ? () : undef if (!@f);
return wantarray ? @{$f[0]->{'values'}} : $f[0]->{'values'}->[0];
}

# save_directive(&config, &old, &new)
# Updates or adds an entire class or section to the config file
sub save_directive
{
local $file = $_[1] ? $_[1]->{'file'} : $_[0]->[0]->{'file'};
local $lref = &read_file_lines($file);
local @lines = &directive_lines($_[2]) if ($_[2]);
if ($_[1]) {
	splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'} - $_[1]->{'line'} + 1,
	       @lines);
	}
else {
	splice(@$lref, $_[0]->[@{$_[0]}-1]->{'eline'}+1, 0, @lines);
	}
}

# swap_directives(&config, &directive1, &directive2)
# Swaps two directives in the config file
sub swap_directives
{
local $lref = &read_file_lines($_[1]->{'file'});
local @lines1 = @$lref[$_[1]->{'line'} .. $_[1]->{'eline'}];
local @lines2 = @$lref[$_[2]->{'line'} .. $_[2]->{'eline'}];
if ($_[1]->{'line'} < $_[2]->{'line'}) {
	splice(@$lref, $_[2]->{'line'}, scalar(@lines2), @lines1);
	splice(@$lref, $_[1]->{'line'}, scalar(@lines1), @lines2);
	}
elsif ($_[1]->{'line'} > $_[2]->{'line'}) {
	splice(@$lref, $_[1]->{'line'}, scalar(@lines1), @lines2);
	splice(@$lref, $_[2]->{'line'}, scalar(@lines2), @lines1);
	}
}

# directive_lines(&section|&class)
# Returns an array of the lines for some section or class
sub directive_lines
{
local (@rv, $d, $l, $i);
if ($_[0]->{'type'} eq 'section') {
	push(@rv, "$_[0]->{'name'}:");
	if (defined($_[0]->{'text'})) {
		return (@rv, split(/\n/, $_[0]->{'text'}));
		}
	foreach $c (@{$_[0]->{'cls'}}) {
		push(@rv, &directive_lines($c));
		}
	}
elsif ($_[0]->{'type'} eq 'class') {
	local $id = $_[0]->{'implied'} ? "\t" : "\t\t";
	push(@rv, "\t$_[0]->{'name'}::") if (!$_[0]->{'implied'});
	if (defined($_[0]->{'text'})) {
		return (@rv, split(/\n/, $_[0]->{'text'}));
		}
	foreach $d (@{$_[0]->{'defs'}}) {
		local @v;
		local $i;
		for($i=0; $i<@{$d->{'values'}}; $i++) {
			push(@v, &quote_str($d->{'values'}->[$i],
					    $d->{'valuequotes'}->[$i]));
			}
		push(@rv, "$id$d->{'name'} = ( ".join(" ", @v)." )");
		}
	foreach $l (@{$_[0]->{'lists'}}) {
		push(@rv, $id."{");
		push(@rv, &value_lines($l->{'values'}, $l->{'valuelines'},
				       $l->{'valuequotes'}, $id));
		push(@rv, $id."}");
		}
	push(@rv, &value_lines($_[0]->{'values'}, $_[0]->{'valuelines'},
			       $_[0]->{'valuequotes'}, $id));
	}
return @rv;
}

# value_lines(&values, &lines, &quotes, indent)
sub value_lines
{
local @lines;
local $i;
for($i=0; $i<@{$_[0]}; $i++) {
	local $l = $_[1]->[$i] -
		   $_[1]->[0];
	if ($lines[$l] eq "") {
		$lines[$l] = $_[3];
		}
	else {
		$lines[$l] .= " ";
		}
	$lines[$l] .= &quote_str($_[0]->[$i], $_[2]->[$i]);
	}
return @lines;
}

# quote_str(string, quote)
sub quote_str
{
if (defined($_[1])) {
	return $_[1].$_[0].$_[1];
	}
elsif ($_[0] =~ /^\S+$/) {
	return $_[0];
	}
elsif ($_[0] !~ /"/) {
	return "\"$_[0]\"";
	}
elsif ($_[0] !~ /'/) {
	return "'$_[0]'";
	}
else {
	return "`$_[0]`";
	}
}

# split_str(string)
sub split_str
{
local (@rv, @qu);
local $str = $_[0];
while($str =~ /^\s*(")([^"]*)"(.*)$/s ||
      $str =~ /^\s*(')([^"]*)'(.*)$/s ||
      $str =~ /^\s*(`)([^"]*)`(.*)$/s ||
      $str =~ /^\s*()(\S+)(.*)$/s) {
	push(@qu, $1);
	push(@rv, $2);
	$str = $3;
	}
return ( \@rv, \@qu );
}

# get_cfrun_hosts()
sub get_cfrun_hosts
{
local (@hosts, %opts);
open(HOSTS, $cfrun_hosts);
while(<HOSTS>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*(\S+)\s*=\s*(.*)/) {
		$opts{$1} = $2;
		}
	elsif (/^\s*(\S+)\s*(.*)/) {
		push(@hosts, [ $1, $2] );
		}
	}
close(HOSTS);
return ( \@hosts, \%opts );
}

# save_cfrun_hosts(&hosts, &opts)
sub save_cfrun_hosts
{
open(HOSTS, ">$cfrun_hosts");
foreach $o (keys %{$_[1]}) {
	print HOSTS $o,"=".$_[1]->{$o},"\n";
	}
foreach $h (@{$_[0]}) {
	print HOSTS $h->[0]," ",$h->[1],"\n";
	}
close(HOSTS);
}

# show_classes_table(&config, cfd, readonly)
sub show_classes_table
{
if (@{$_[0]}) {
	&show_button($_[1]) if (!$_[2]);
	print "<table border width=100%>\n";
	print "<tr $tb> ",
	      ($_[1] ? "" : "<td><b>$text{'index_active'}</b></td>"),
	      "<td><b>$text{'index_section'}</b></td> ",
	      "<td><b>$text{'index_classes'}</b></td> ",
	      "<td><b>$text{'index_details'}</b></td> </tr>\n";
	local $s;
	local %active;
	foreach $s (@{$_[0]}) {
		foreach $c (@{$s->{'cls'}}) {
			if ($s->{'name'} eq 'control') {
				local ($as) = &find("actionsequence",
						  $c->{'defs'});
				local $cc = $c->{'name'} eq 'any' ? 2 : 1;
				map { s/\..*$//; $active{$_} = $cc
					if ($cc > $active{$_}) }
				    @{$as->{'values'}} if ($as);
				}
			}
		}
	foreach $s (@{$_[0]}) {
		next if ($s->{'name'} =~ /^import/);
		local (@clist, @dlist);
		foreach $c (@{$s->{'cls'}}) {
			push(@clist, $_[2] ? $c->{'name'} : "<a href='edit_class.cgi?cfd=$_[1]&idx=$s->{'index'}&cidx=$c->{'index'}'>$c->{'name'}</a>");
			local $desc;
			if ($s->{'name'} eq 'links') {
				local @l = &parse_links($c);
				if (@l > 1) {
					$desc = &text('index_links2',
						      scalar(@l));
					}
				elsif (@l) {
					$desc = &text('index_links',
						"<tt>$l[0]->{'_linkfrom'}</tt>",
						"<tt>$l[0]->{'_linkto'}</tt>");
					}
				}
			elsif ($s->{'name'} eq 'directories' ||
			       $s->{'name'} eq 'files' ||
			       $s->{'name'} eq 'disable' ||
			       $s->{'name'} eq 'shellcommands' ||
			       $s->{'name'} eq 'tidy' ||
			       $s->{'name'} eq 'required' ||
			       $s->{'name'} eq 'disks') {
				local @dirs = &parse_directories($c);
				if (@dirs > 1) {
					$desc = &text('index_'.$s->{'name'}.'2',
							scalar(@dirs));
					}
				elsif (@dirs) {
					$desc = &text('index_'.$s->{'name'},
						"<tt>$dirs[0]->{'_dir'}</tt>");
					}
				}
			elsif ($s->{'name'} eq 'control' && $_[1]) {
				local ($cmd) = &find("cfrunCommand",
						$c->{'defs'});
				if ($cmd) {
					$desc = &text('index_cfrun',
					    "<tt>$cmd->{'values'}->[0]</tt>");
					}
				}
			elsif ($s->{'name'} eq 'control' && !$_[1]) {
				local ($as) = &find("actionsequence",
						  $c->{'defs'});
				if ($as) {
					local @v = @{$as->{'values'}};
					if (@v > 1) {
						$desc = &text('index_control2',
							  scalar(@v));
						}
					else {
						$desc = &text('index_control',
							  "<tt>$v[0]</tt>");
						}
					}
				}
			elsif ($s->{'name'} eq 'editfiles') {
				local @files = map { $_->{'values'}->[0] }
						   @{$c->{'lists'}};
				if (@files > 1) {
					$desc = &text('index_editfiles2',
						      scalar(@files));
					}
				elsif (@files) {
					$desc = &text('index_editfiles',
							"<tt>$files[0]</tt>");
					}
				}
			elsif ($s->{'name'} eq 'grant' ||
			       $s->{'name'} eq 'admit' ||
			       $s->{'name'} eq 'deny') {
				local @dirs = grep { /\// } @{$c->{'values'}};
				if (@dirs > 1) {
					$desc = &text('index_'.$s->{'name'}.'2',
						      scalar(@dirs));
					}
				elsif (@dirs) {
					$desc = &text('index_'.$s->{'name'},
							"<tt>$dirs[0]</tt>");
					}
				}
			elsif ($s->{'name'} eq 'groups' ||
			       $s->{'name'} eq 'classes') {
				local @grs = map { $_->{'name'} }
						 @{$c->{'defs'}};
				if (@grs) {
					$desc = &text('index_groups',
						join(", ", map { "<tt>$_</tt>" }
							       @grs));
					}
				}
			elsif ($s->{'name'} eq 'copy') {
				local @copies = &parse_directories($c);
				if (@copies > 1) {
					$desc = &text('index_copy2',
						      scalar(@copies));
					}
				elsif (@copies) {
					$desc = &text('index_copy',
					    "<tt>$copies[0]->{'_dir'}</tt>",
					    "<tt>$copies[0]->{'dest'}</tt>");
					}
				}
			elsif ($s->{'name'} eq 'ignore') {
				$desc = &text('index_ignore',
					 scalar(@{$c->{'values'}}));
				}
			elsif ($s->{'name'} eq "processes") {
				local @procs = grep { !$_->{'_options'} }
						    &parse_processes($c);
				if (@procs > 1) {
					$desc = &text('index_procs2',
						  scalar(@procs));
					}
				elsif (@procs) {
					$desc = &text('index_procs',
					    "<tt>$procs[0]->{'_match'}</tt>");
					}
				}
			elsif ($s->{'name'} eq 'miscmounts') {
				local @mnts = &parse_miscmounts($c);
				if (@mnts > 1) {
					$desc = &text('index_misc2',
						      scalar(@mnts));
					}
				elsif (@mnts) {
					$desc = &text('index_misc',
					         "<tt>$mnts[0]->{'_src'}</tt>");
					}
				}
			elsif ($s->{'name'} eq 'defaultroute') {
				$desc = &text('index_route',
					    "<tt>$c->{'values'}->[0]</tt>");
				}
			$desc = "&nbsp;" if (!$desc);
			push(@dlist, $desc);
			}
		next if (!@clist);

		local $t = $text{"section_".$s->{'name'}."_".$_[1]};
		$t = $text{"section_".$s->{'name'}} if (!$t);
		print "<tr $cb>\n";
		if (!$_[1]) {
			printf "<td rowspan=%d valign=top>\n", scalar(@clist);
			local $a = $active{$s->{'name'}};
			print $s->{'name'} =~ /^control/ ? "<br>" : $a == 0 ? "<font color=#ff0000>$text{'no'}</font>" : $a == 1 ? "<font color=#333333>$text{'index_maybe'}</font>" : $text{'yes'};
			print "</td>\n";
			}
		printf "<td rowspan=%d valign=top>\n", scalar(@clist);
		print "<table cellpadding=0 cellspacing=0 width=100%><tr>\n";
		print "<td>",$t ? "$t ($s->{'name'})" : $s->{'name'},"</td>\n";
		print "<td align=right>\n";
		#if ($s eq $_[0]->[@{$_[0]}-1]) {
		#	print "<img src=images/gap.gif>";
		#	}
		#else {
		#	print "<a href='down.cgi?cfd=$_[1]&idx=$s->{'index'}'>",
		#	      "<img src=images/down.gif border=0></a>";
		#	}
		#if ($s eq $_[0]->[0]) {
		#	print "<img src=images/gap.gif>";
		#	}
		#else {
		#	print "<a href='up.cgi?cfd=$_[1]&idx=$s->{'index'}'>",
		#	      "<img src=images/up.gif border=0></a>";
		#	}
		if (!$_[2]) {
			print "<a href='edit_class.cgi?cfd=$_[1]&idx=$s->{'index'}&new=1'>$text{'index_cadd'}</a></td>\n";
			}
		print "</tr></table></td>\n";

		for($i=0; $i<@clist; $i++) {
			print "<tr $cb>\n" if ($i != 0);
			print "<td>$clist[$i]</td>\n";
			print "<td>$dlist[$i]</td>\n";
			print "</tr>\n" if ($i == 0);
			}
		}
	print "</table>\n";
	}
elsif ($_[1]) {
	print "<p><b>$text{'cfd_none'}</b><p>\n";
	}
else {
	print "<p><b>$text{'index_none'}</b><p>\n";
	}
&show_button($_[1]) if (!$_[2]);
}

# show_button(cfd)
sub show_button
{
print "<form action=edit_class.cgi>\n";
print "<input type=hidden name=cfd value='$_[1]'>\n";
print "<input type=submit name=new value='$text{'index_add'}'>\n";
print "<select name=type>\n";
local $s;
foreach $s ($_[0] ? @known_cfd_sections : @known_sections) {
	local $tt = $text{"type_".$s."_".$_[0]};
	$tt = $text{"type_".$s} if (!$tt);
	next if (!$tt);
	local $t = $text{"section_".$s."_".$_[0]};
	$t = $text{"section_".$s} if (!$t);
	print "<option value=$s>$t ($s)\n";
	}
print "</select></form>\n";

}

# parse_links(&cls)
sub parse_links
{
local (@rv, $v);
foreach $v (@{$_[0]->{'values'}}) {
	if ($v =~ /^(\S+)=(\S+)$/) {
		if (defined($rv[$#rv]->{$1})) {
			$rv[$#rv]->{$1} .= "\0$2";
			}
		else {
			$rv[$#rv]->{$1} = $2;
			}
		}
	elsif ($v =~ /^[\+\-]>!?$/) {
		$rv[$#rv]->{'_linktype'} = $v;
		}
	else {
		if (!@rv || $rv[$#rv]->{'_linkfrom'} && $rv[$#rv]->{'_linkto'}) {
			push(@rv, { '_linkfrom' => $v } );
			}
		else {
			$rv[$#rv]->{'_linkto'} = $v;
			}
		}
	}
return @rv;
}
# unparse_links(&cls, link, ...)
sub unparse_links
{
local $cls = shift(@_);
local ($l, $vl = 0, @values, @valuelines);
foreach $l (@_) {
	push(@values, $l->{'_linkfrom'}, $l->{'_linktype'}, $l->{'_linkto'});
	push(@valuelines, $vl, $vl, $vl);
	foreach $k (keys %$l) {
		if ($k !~ /^_/) {
			local $z;
			foreach $z (split(/\0/, $l->{$k})) {
				push(@values, "$k=$z");
				push(@valuelines, $vl);
				}
			}
		}
	$vl++;
	}
$cls->{'values'} = \@values;
$cls->{'valuelines'} = \@valuelines;
$cls->{'valuequotes'} = [ ];
}

# parse_directories(&cls)
sub parse_directories
{
local (@rv, $v);
foreach $v (@{$_[0]->{'values'}}) {
	if ($v =~ /^(\S+)=(\S+)$/) {
		if (defined($rv[$#rv]->{$1})) {
			$rv[$#rv]->{$1} .= "\0$2";
			}
		else {
			$rv[$#rv]->{$1} = $2;
			}
		}
	else {
		push(@rv, { '_dir' => $v } );
		}
	}
return @rv;
}

# unparse_directories(&cls, dir, ...)
sub unparse_directories
{
local $cls = shift(@_);
local ($d, $vl = 0, @values, @valuelines);
foreach $d (@_) {
	push(@values, $d->{'_dir'});
	push(@valuelines, $vl);
	foreach $k (keys %$d) {
		if ($k !~ /^_/) {
			local $z;
			foreach $z (split(/\0/, $d->{$k})) {
				push(@values, "$k=$z");
				push(@valuelines, $vl);
				}
			}
		}
	$vl++;
	}
$cls->{'values'} = \@values;
$cls->{'valuelines'} = \@valuelines;
$cls->{'valuequotes'} = [ ];
return @rv;
}

# parse_processes(&cls, &optionstr)
sub parse_processes
{
local (@rv, $v, $i);
for($i=0; $i<@{$_[0]->{'values'}}; $i++) {
	$v = $_[0]->{'values'}->[$i];
	if ($v =~ /^(\S+)=(\S+)$/) {
		if (defined($rv[$#rv]->{$1})) {
			$rv[$#rv]->{$1} .= "\0$2";
			}
		else {
			$rv[$#rv]->{$1} = $2;
			}
		}
	elsif ($v eq "restart") {
		$rv[$#rv]->{'_restart'} = $_[0]->{'values'}->[++$i];
		}
	elsif ($v eq "SetOptionString") {
		push(@rv, { '_options' => $_[0]->{'values'}->[++$i] } );
		}
	else {
		push(@rv, { '_match' => $v } );
		}
	}
return @rv;
}

# unparse_processes(&cls, match, ...)
sub unparse_processes
{
local $cls = shift(@_);
local ($d, $vl = 0, @values, @valuelines, @valuequotes);
foreach $d (@_) {
	if ($d->{'_options'}) {
		push(@values, "SetOptionString", $d->{'_options'});
		push(@valuelines, $vl, $vl);
		push(@valuequotes, "", '"');
		}
	else {
		push(@values, $d->{'_match'});
		push(@valuelines, $vl);
		push(@valuequotes, '"');
		foreach $k (keys %$d) {
			if ($k !~ /^_/) {
				local $z;
				foreach $z (split(/\0/, $d->{$k})) {
					push(@values, "$k=$z");
					push(@valuelines, $vl);
					push(@valuequotes, "");
					}
				}
			}
		if ($d->{'_restart'}) {
			push(@values, "restart", $d->{'_restart'});
			push(@valuelines, $vl, $vl);
			push(@valuequotes, "", '"');
			}
		}
	$vl++;
	}
$cls->{'values'} = \@values;
$cls->{'valuelines'} = \@valuelines;
$cls->{'valuequotes'} = \@valuequotes;
return @rv;
}

# unparse_shellcommands(&cls, dir, ...)
sub unparse_shellcommands
{
local $cls = shift(@_);
local ($d, $vl = 0, @values, @valuelines, @valuequotes);
foreach $d (@_) {
	push(@values, $d->{'_dir'});
	push(@valuelines, $vl);
	push(@valuequotes, $d->{'_dir'} !~ /"/ ? '"' :
			   $d->{'_dir'} !~ /'/ ? "'" : "`");
	foreach $k (keys %$d) {
		if ($k !~ /^_/) {
			local $z;
			foreach $z (split(/\0/, $d->{$k})) {
				push(@values, "$k=$z");
				push(@valuelines, $vl);
				push(@valuequotes, undef);
				}
			}
		}
	$vl++;
	}
$cls->{'values'} = \@values;
$cls->{'valuelines'} = \@valuelines;
$cls->{'valuequotes'} = \@valuequotes;
return @rv;
}

# parse_miscmounts(&cls)
sub parse_miscmounts
{
local (@rv, $v);
foreach $v (@{$_[0]->{'values'}}) {
	if ($v =~ /^(\S+)=(\S+)$/) {
		if (defined($rv[$#rv]->{$1})) {
			$rv[$#rv]->{$1} .= "\0$2";
			}
		else {
			$rv[$#rv]->{$1} = $2;
			}
		}
	elsif ($v !~ /\//) {
		$rv[$#rv]->{'mode'} = $v;
		}
	else {
		if (@rv && $rv[$#rv]->{'_src'} && !$rv[$#rv]->{'_dest'}) {
			$rv[$#rv]->{'_dest'} = $v;
			}
		else {
			push(@rv, { '_src' => $v } );
			}
		}
	}
return @rv;
}

# unparse_miscmounts(&cls, dir, ...)
sub unparse_miscmounts
{
local $cls = shift(@_);
local ($d, $vl = 0, @values, @valuelines);
foreach $d (@_) {
	push(@values, $d->{'_src'}, $d->{'_dest'});
	push(@valuelines, $vl, $vl);
	foreach $k (keys %$d) {
		if ($k !~ /^_/) {
			local $z;
			foreach $z (split(/\0/, $d->{$k})) {
				push(@values, "$k=$z");
				push(@valuelines, $vl);
				}
			}
		}
	$vl++;
	}
$cls->{'values'} = \@values;
$cls->{'valuelines'} = \@valuelines;
$cls->{'valuequotes'} = [ ];
return @rv;
}

# list_cfengine_hosts()
# Returns a list of all webmin hosts running cfengine known to this module
sub list_cfengine_hosts
{
local (@rv, $f);
local $hdir = "$module_config_directory/hosts";
opendir(DIR, $hdir);
foreach $f (readdir(DIR)) {
	if ($f =~ /^(\S+)\.host$/) {
		local %host = ( 'id', $1 );
		&read_file("$hdir/$f", \%host);
		push(@rv, \%host);
		}
	}
closedir(DIR);
return @rv;
}

# list_servers()
# Returns a list of all servers from the webmin servers module that can be
# managed, plus this server
sub list_servers
{
local @servers = &foreign_call("servers", "list_servers");
return ( { 'id' => 0, 'desc' => $text{'this_server'}, 'type' => 'unknown' },
	 grep { $_->{'user'} } @servers );
}

# server_name(&server)
sub server_name
{
return $_[0]->{'desc'} ? $_[0]->{'desc'} : $_[0]->{'host'};
}

# save_cfengine_host(&host)
# Add or update a managed host
sub save_cfengine_host
{
local $hdir = "$module_config_directory/hosts";
mkdir($hdir, 0700);
&write_file("$hdir/$_[0]->{'id'}.host", $_[0]);
}

# delete_cfengine_host(&host)
sub delete_cfengine_host
{
unlink("$module_config_directory/hosts/$_[0]->{'id'}.host");
}

# cfengine_host_version(&server)
sub cfengine_host_version
{
local $out = &remote_eval($_[0]->{'host'}, "cfengine", '`$config{"cfengine"} -V 2>&1`');
return $out =~ /cfengine-(\S+)/ || $out =~ /GNU\s+(\S+)/ ? $1 : undef;
}

# show_run_form()
sub show_run_form
{
print "<tr> <td><b>$text{'run_dry'}</b></td>\n";
print "<td><input type=radio name=dry value=1> $text{'yes'}\n";
print "<td><input type=radio name=dry value=0 checked> $text{'no'}</td>\n";

print "<td><b>$text{'run_noifc'}</b></td>\n";
print "<td><input type=radio name=noifc value=0 checked> $text{'yes'}\n";
print "<td><input type=radio name=noifc value=1> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'run_nomnt'}</b></td>\n";
print "<td><input type=radio name=nomnt value=0 checked> $text{'yes'}\n";
print "<td><input type=radio name=nomnt value=1> $text{'no'}</td>\n";

print "<td><b>$text{'run_nocmd'}</b></td>\n";
print "<td><input type=radio name=nocmd value=0 checked> $text{'yes'}\n";
print "<td><input type=radio name=nocmd value=1> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'run_notidy'}</b></td>\n";
print "<td><input type=radio name=notidy value=0 checked> $text{'yes'}\n";
print "<td><input type=radio name=notidy value=1> $text{'no'}</td>\n";

print "<td><b>$text{'run_nolinks'}</b></td>\n";
print "<td><input type=radio name=nolinks value=0 checked> $text{'yes'}\n";
print "<td><input type=radio name=nolinks value=1> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'run_verbose'}</b></td>\n";
print "<td><input type=radio name=verbose value=1 checked> $text{'yes'}\n";
print "<td><input type=radio name=verbose value=0> $text{'no'}</td>\n";
}

# get_cfengine_version(&dummy)
sub get_cfengine_version
{
local $out = `$config{'cfengine'} -V 2>&1`;
${$_[0]} = $out;
return $out =~ /cfengine-(\S+)/ || $out =~ /GNU\s+(\S+)/ ? $1 : undef;
}

1;

