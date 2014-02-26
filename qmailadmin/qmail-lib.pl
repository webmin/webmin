# qmail-lib.pl
# Common functions for parsing qmail config files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do 'boxes-lib.pl';

$qmail_alias_dir = "$config{'qmail_dir'}/alias";
$qmail_bin_dir = "$config{'qmail_dir'}/bin";
$qmail_control_dir = "$config{'qmail_dir'}/control";
$qmail_routes_file = "$qmail_control_dir/smtproutes";
$qmail_virts_file = "$qmail_control_dir/virtualdomains";
$qmail_start_cmd = "$config{'qmail_dir'}/rc";
$qmail_mess_dir = "$config{'qmail_dir'}/queue/mess";
$qmail_info_dir = "$config{'qmail_dir'}/queue/info";
$qmail_local_dir = "$config{'qmail_dir'}/queue/local";
$qmail_remote_dir = "$config{'qmail_dir'}/queue/remote";
$qmail_users_dir = "$config{'qmail_dir'}/users";
$qmail_assigns_file = "$config{'qmail_dir'}/users/assign";

$config{'perpage'} ||= 20;      # a value of 0 can cause problems

# list_aliases()
# Returns a list of qmail alias file names
sub list_aliases
{
local @rv;
opendir(DIR, $qmail_alias_dir);
foreach $f (readdir(DIR)) {
	next if ($f !~ /^\.qmail-(\S+)$/);
	push(@rv, $1);
	}
closedir(DIR);
return @rv;
}

# get_alias(name)
sub get_alias
{
local $alias = { 'name' => $_[0],
		 'file' => "$qmail_alias_dir/.qmail-$_[0]",
		 'values' => [ ] };
open(ALIAS, $alias->{'file'});
while(<ALIAS>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/\S/) {
		push(@{$alias->{'values'}}, $_);
		}
	}
close(ALIAS);
return $alias;
}

# alias_form([alias])
# Display a form for editing or creating an alias. Each alias can map to
# 1 or more programs, files, lists or users
sub alias_form
{
local($a, @values, $v, $type, $val, @typenames);
$a = $_[0];
if ($a) { @values = @{$a->{'values'}}; }
@typenames = map { $text{"aform_type$_"} } (0 .. 6);
$typenames[0] = "&lt;$typenames[0]&gt;";

print "<form method=post action=save_alias.cgi>\n";
if ($a) { print "<input type=hidden name=old value='$a->{'name'}'>\n"; }
else { print "<input type=hidden name=new value=1>\n"; }
print "<table border>\n";
print "<tr $tb> <td><b>",$a ? $text{'aform_edit'}
			    : $text{'aform_create'},"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'aform_name'}</b></td>\n";
local $n = $a ? $a->{'name'} : '';
$n =~ s/:/./g;
local @virts = grep { $_->{'domain'} && !$_->{'user'} && $_->{'prepend'} }
		    &list_virts();
if ($n =~ /^(\S+)-(\S+)$/) {
	local ($pn, $bn) = ($1, $2);
	foreach $v (@virts) {
		if ($v->{'prepend'} eq $pn) {
			$virt = $v;
			$n = $bn;
			last;
			}
		}
	}
if (@virts) {
	printf "<td><input name=name size=20 value=\"%s\">\@", $n;
	print "<select name=virt>\n";
	printf "<option value='' %s>%s</option>\n",
		$virt ? "" : "checked", $text{'aform_novirt'};
	foreach $v (@virts) {
		printf "<option value='%s' %s>%s</option>\n",
			$v->{'prepend'}, $virt eq $v ? "selected" : "",
			$v->{'domain'};
		}
	print "</select></td> </tr>\n";
	}
else {
	printf "<td><input name=name size=20 value=\"%s\"></td> </tr>\n", $n;
	}

for($i=0; $i<=@values; $i++) {
	($type, $val) = $values[$i] ? &alias_type($values[$i]) : (0, "");
	print "<tr> <td valign=top><b>$text{'aform_val'}</b></td>\n";
	print "<td><select name=type_$i>\n";
	for($j=0; $j<@typenames; $j++) {
		printf "<option value=$j %s>$typenames[$j]</option>\n",
			$type == $j ? "selected" : "";
		}
	print "</select>\n";
	print "<input name=val_$i size=30 value=\"$val\">\n";
	if ($type == 5 && $a) {
		print "<a href='edit_rfile.cgi?file=$val&name=$a->{'name'}'>",
		      "$text{'aform_afile'}</a>\n";
		}
	elsif ($type == 6 && $a) {
		print "<a href='edit_ffile.cgi?file=$val&name=$a->{'name'}'>",
		      "$text{'aform_afile'}</a>\n";
		}
	print "</td> </tr>\n";
	}
print "<tr> <td colspan=2 align=right>\n";
if ($a) {
	print "<input type=submit value=$text{'save'}>\n";
	print "<input type=submit name=delete value=$text{'delete'}>\n";
	}
else { print "<input type=submit value=$text{'create'}>\n"; }
print "</td> </tr>\n";
print "</table></td></tr></table></form>\n";
}

# alias_type(string)
# Return the type and destination of some alias string
sub alias_type
{
local @rv;
if ($_[0] =~ /^\&(.*)/) {
	@rv = (1, $1);
	}
elsif ($_[0] =~ /^\|$module_config_directory\/autoreply.pl\s+(\S+)/) {
	@rv = (5, $1);
	}
elsif ($_[0] =~ /^\|$module_config_directory\/filter.pl\s+(\S+)/) {
	@rv = (6, $1);
	}
elsif ($_[0] =~ /^\|(.*)$/) {
	@rv = (4, $1);
	}
elsif ($_[0] =~ /^(\/.*)\/$/) {
	@rv = (2, $1);
	}
elsif ($_[0] =~ /^(\/.*)$/) {
	@rv = (3, $1);
	}
else {
	@rv = (1, $_[0]);
	}
return wantarray ? @rv : $rv[0];
}

# create_alias(&alias)
# Creates a new qmail alias file
sub create_alias
{
local $f = "$qmail_alias_dir/.qmail-$_[0]->{'name'}";
&open_lock_tempfile(FILE, ">$f");
foreach $v (@{$_[0]->{'values'}}) {
	&print_tempfile(FILE, $v,"\n");
	}
&close_tempfile(FILE);
&set_ownership_permissions(undef, undef, 0644, $f);
}

# modify_alias(&old, &alias)
# Modifies an existing qmail alias
sub modify_alias(&old, &alias)
{
if ($_[0]->{'name'} ne $_[1]->{'name'}) {
	&lock_file($_[0]->{'file'});
	unlink($_[0]->{'file'});
	&unlock_file($_[0]->{'file'});
	}
&create_alias($_[1]);
}

# delete_alias(&alias)
# Deletes an existing qmail alias file
sub delete_alias
{
&lock_file($_[0]->{'file'});
unlink("$_[0]->{'file'}");
&unlock_file($_[0]->{'file'});
}

# get_control_file(file)
# Returns the value from a qmail single-line control file
sub get_control_file
{
open(FILE, "$qmail_control_dir/$_[0]") || return undef;
local $line = <FILE>;
close(FILE);
$line =~ s/\r|\n//g;
return $line;
}

# set_control_file(file, value)
# Sets the value in a qmail single-line control file
sub set_control_file
{
&lock_file("$qmail_control_dir/$_[0]");
if (defined($_[1])) {
	&open_tempfile(FILE, ">$qmail_control_dir/$_[0]");
	&print_tempfile(FILE, $_[1],"\n");
	&close_tempfile(FILE);
	}
else {
	unlink("$qmail_control_dir/$_[0]");
	}
&unlock_file("$qmail_control_dir/$_[0]");
}

# list_control_file()
# Returns the contents of a multi-line control file
sub list_control_file
{
local @lines;
open(FILE, "$qmail_control_dir/$_[0]") || return undef;
while(<FILE>) {
	s/\r|\n//g;
	s/#.*$//g;
	push(@lines, $_) if (/\S/);
	}
close(FILE);
return \@lines;

}

# save_control_file(file, &lines)
# Saves the contents of a multi-line control file
sub save_control_file
{
&lock_file("$qmail_control_dir/$_[0]");
if (defined($_[1])) {
	&open_tempfile(FILE, ">$qmail_control_dir/$_[0]");
	foreach $l (@{$_[1]}) {
		&print_tempfile(FILE, $l,"\n");
		}
	&close_tempfile(FILE);
	}
else {
	unlink("$qmail_control_dir/$_[0]");
	}
&unlock_file("$qmail_control_dir/$_[0]");
}

# list_routes()
# Returns a list of all SMTP routes
sub list_routes
{
if (!scalar(@list_routes_cache)) {
	local $lnum = 0;
	local @rv;
	open(ROUTES, $qmail_routes_file);
	while(<ROUTES>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^(\S*):(\S*):(\d+)/) {
			push(@rv, { 'from' => $1,
				    'to' => $2,
				    'port' => $3,
				    'idx' => scalar(@rv),
				    'line' => $lnum });
			}
		elsif (/^(\S*):(\S*)/) {
			push(@rv, { 'from' => $1,
				    'to' => $2,
				    'idx' => scalar(@rv),
				    'line' => $lnum });
			}
		$lnum++;
		}
	close(ROUTES);
	@list_routes_cache = @rv;
	}
return @list_routes_cache;
}

# create_route(&route)
sub create_route
{
&list_routes();	# force cache init
&lock_file($qmail_routes_file);
local $lref = &read_file_lines($qmail_routes_file);
push(@$lref, $_[0]->{'from'}.':'.$_[0]->{'to'}.
	     ($_[0]->{'port'} ? ':'.$_[0]->{'port'} : ''));
&flush_file_lines();
&unlock_file($qmail_routes_file);

# Update in memory cache
$_[0]->{'line'} = @$lref-1;
$_[0]->{'idx'} = scalar(@list_routes_cache);
push(@list_routes_cache, $_[0]);
}

# modify_route(&old, &route)
sub modify_route
{
&lock_file($qmail_routes_file);
local $lref = &read_file_lines($qmail_routes_file);
splice(@$lref, $_[0]->{'line'}, 1,
       $_[1]->{'from'}.':'.$_[1]->{'to'}.
       ($_[1]->{'port'} ? ':'.$_[1]->{'port'} : ''));
&flush_file_lines();
&unlock_file($qmail_routes_file);

# Update in memory cache
if ($_[0] ne $_[1]) {
	$_[1]->{'line'} = $_[0]->{'line'};
	$_[1]->{'idx'} = $_[0]->{'idx'};
	$list_routes_cache[$_[1]->{'idx'}] = $_[1];
	}
}

# delete_route(&route)
sub delete_route
{
&lock_file($qmail_routes_file);
local $lref = &read_file_lines($qmail_routes_file);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
&unlock_file($qmail_routes_file);

# delete from cache
splice(@list_routes_cache, $_[0]->{'idx'}, 1);
foreach my $v (@list_routes_cache) {
	$v->{'line'}-- if ($v->{'line'} > $_[0]->{'line'});
	$v->{'idx'}-- if ($v->{'idx'} > $_[0]->{'idx'});
	}
}

# route_form([&route])
sub route_form
{
print "<form method=post action=save_route.cgi>\n";
if ($_[0]) { print "<input type=hidden name=idx value='$_[0]->{'idx'}'>\n"; }
else { print "<input type=hidden name=new value=1>\n"; }

print "<table border>\n";
print "<tr $tb> <td><b>",$a ? $text{'rform_edit'}
			    : $text{'rform_create'},"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'rform_from'}</b></td>\n";
printf "<td><input name=from size=30 value='%s'></td> </tr>\n",
	$_[0] ? $_[0]->{'from'} : "";

print "<tr> <td><b>$text{'rform_to'}</b></td>\n";
printf "<td><input type=radio name=to_def value=1 %s> %s\n",
	$_[0] && $_[0]->{'to'} ? "" : "checked", $text{'routes_direct'};
printf "<input type=radio name=to_def value=0 %s>\n",
	$_[0] && $_[0]->{'to'} ? "checked" : "";
printf "<input name=to size=30 value='%s'></td>\n",
	$_[0] ? $_[0]->{'to'} : "";

print "<td><b>$text{'rform_port'}</b></td>\n";
printf "<td><input type=radio name=port_def value=1 %s> %s\n",
	$_[0] && $_[0]->{'port'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=port_def value=0 %s>\n",
	$_[0] && $_[0]->{'port'} ? "checked" : "";
printf "<input name=port size=4 value='%s'></td> </tr>\n",
	$_[0] ? $_[0]->{'port'} : "";

print "<tr> <td colspan=4 align=right>\n";
if ($_[0]) {
	print "<input type=submit value=$text{'save'}>\n";
	print "<input type=submit name=delete value=$text{'delete'}>\n";
	}
else { print "<input type=submit value=$text{'create'}>\n"; }
print "</td> </tr>\n";
print "</table></td></tr></table></form>\n";
}

# list_virts()
# Returns a list of all virtualdomains file entries
sub list_virts
{
if (!scalar(@list_virts_cache)) {
	local $lnum = 0;
	local @rv;
	open(VIRTS, $qmail_virts_file);
	while(<VIRTS>) {
		s/\r|\n//g;
		s/#.*$//;
		if (/^(\S+)\@(\S+):(\S*)/) {
			push(@rv, { 'user' => $1,
				    'domain' => $2,
				    'from' => "$1\@$2",
				    'prepend' => $3,
				    'line' => $lnum,
				    'idx' => scalar(@rv) } );
			}
		elsif (/^(\S*):(\S*)/) {
			push(@rv, { 'domain' => $1,
				    'from' => $1,
				    'prepend' => $2,
				    'line' => $lnum,
				    'idx' => scalar(@rv) } );
			}
		$lnum++;
		}
	close(VIRTS);
	@list_virts_cache = @rv;
	}
return @list_virts_cache;
}

# create_virt(&virt)
sub create_virt
{
&list_virts();	# force cache init
&lock_file($qmail_virts_file);
local $lref = &read_file_lines($qmail_virts_file);
push(@$lref, join(":", $_[0]->{'user'} ? "$_[0]->{'user'}\@$_[0]->{'domain'}"
				       : $_[0]->{'domain'},
		       $_[0]->{'prepend'}));
&flush_file_lines();
&unlock_file($qmail_virts_file);

# Update in memory cache
$_[0]->{'line'} = @$lref-1;
$_[0]->{'idx'} = scalar(@list_virts_cache);
push(@list_virts_cache, $_[0]);
}

# delete_virt(&virt)
sub delete_virt
{
&lock_file($qmail_virts_file);
local $lref = &read_file_lines($qmail_virts_file);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
&unlock_file($qmail_virts_file);

# delete from cache
splice(@list_virts_cache, $_[0]->{'idx'}, 1);
foreach my $v (@list_virts_cache) {
	$v->{'line'}-- if ($v->{'line'} > $_[0]->{'line'});
	$v->{'idx'}-- if ($v->{'idx'} > $_[0]->{'idx'});
	}
}

# modify_virt(&old, &virt)
sub modify_virt
{
&lock_file($qmail_virts_file);
local $lref = &read_file_lines($qmail_virts_file);
splice(@$lref, $_[0]->{'line'}, 1,
	     join(":", $_[1]->{'user'} ? "$_[1]->{'user'}\@$_[1]->{'domain'}"
				       : $_[1]->{'domain'},
		       $_[1]->{'prepend'}));
&flush_file_lines();
&unlock_file($qmail_virts_file);

# Update in memory cache
if ($_[0] ne $_[1]) {
	$_[1]->{'line'} = $_[0]->{'line'};
	$_[1]->{'idx'} = $_[0]->{'idx'};
	$list_virts_cache[$_[1]->{'idx'}] = $_[1];
	}
}

# virt_form(&virt)
sub virt_form
{
print "<form method=post action=save_virt.cgi>\n";
if ($_[0]) { print "<input type=hidden name=idx value='$_[0]->{'idx'}'>\n"; }
else { print "<input type=hidden name=new value=1>\n"; }

print "<table border>\n";
print "<tr $tb> <td><b>",$a ? $text{'vform_edit'}
			    : $text{'vform_create'},"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td valign=top><b>$text{'vform_from'}</b></td> <td>\n";
printf "<input type=radio name=from_mode value=0 %s> %s<br>\n",
	$_[0] && !$_[0]->{'from'} ? "checked" : "", $text{'vform_all'};
printf "<input type=radio name=from_mode value=1 %s> %s\n",
	!$_[0] || $_[0]->{'domain'} && !$_[0]->{'user'} ? "checked" : "",
	$text{'vform_domain'};
printf "<input name=domain size=20 value='%s'><br>\n",
	$_[0] && $_[0]->{'domain'} && !$_[0]->{'user'} ? $_[0]->{'domain'} : "";
printf "<input type=radio name=from_mode value=2 %s> %s\n",
	$_[0] && $_[0]->{'user'} ? "checked" : "",
	$text{'vform_user'};
printf "<input name=user size=15 value='%s'>@",
	$_[0] && $_[0]->{'user'} ? $_[0]->{'user'} : "";
printf "<input name=domain2 size=20 value='%s'></td> </tr>",
	$_[0] && $_[0]->{'user'} ? $_[0]->{'domain'} : "";

print "<tr> <td valign=top><b>$text{'vform_to'}</b></td> <td>\n";
printf "<input type=radio name=prepend_mode value=0 %s> %s<br>\n",
	$_[0] && !$_[0]->{'prepend'} ? "checked" : "", $text{'vform_none'};
if (!$_[0]) {
	printf "<input type=radio name=prepend_mode value=2 %s> %s<br>\n",
		"checked", $text{'vform_auto'};
	}
printf "<input type=radio name=prepend_mode value=1 %s> %s\n",
	$_[0] && $_[0]->{'prepend'} ? "checked" : "", $text{'vform_prepend'};
printf "<input name=prepend size=15 value='%s'></td> </tr>\n",
	$_[0] && $_[0]->{'prepend'} ? $_[0]->{'prepend'} : "";

print "<tr> <td colspan=2 align=right>\n";
if ($_[0]) {
	print "<input type=submit value=$text{'save'}>\n";
	print "<input type=submit name=delete value=$text{'delete'}>\n";
	}
else { print "<input type=submit value=$text{'create'}>\n"; }
print "</td> </tr>\n";
print "</table></td></tr></table></form>\n";
}

# list_queue()
# Returns an array of structures for entries in the mail queue
sub list_queue
{
local (@rv, %qmap);
@rv = ( );
opendir(DIR, $qmail_mess_dir);
foreach $m (readdir(DIR)) {
	next if ($m !~ /^\d+$/);
	opendir(DIR2, "$qmail_mess_dir/$m");
	foreach $m2 (readdir(DIR2)) {
		$qmap{$m2} = "$qmail_mess_dir/$m/$m2"
			if ($m2 =~ /^\d+$/);
		}
	closedir(DIR2);
	}
closedir(DIR);
open(QUEUE, "$qmail_bin_dir/qmail-qread |");
while(<QUEUE>) {
	if (/^(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\S+)\s+#(\d+)\s+(\d+)\s+(.*)/) {
		local $q = { 'from' => $10,
			     'id' => $8,
			     'file' => $qmap{$8},
			     'date' => "$1 $2 $3 $4:$5:$6" };
		$_ = <QUEUE>;
		if (/^\s*(\S+)\s+(.*)/) {
			$q->{'source'} = $1;
			$q->{'to'} = $2;
			push(@rv, $q);
			}
		}
	}
close(QUEUE);
return @rv;
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
local @rv;
local $w = $_[1];
foreach $rest (split(/\n/, $_[0])) {
	if ($rest =~ /\S/) {
		while($rest =~ /^(.{1,$w}\S*)\s*([\0-\377]*)$/) {
			push(@rv, $1);
			$rest = $2;
			}
		}
	else {
		# Empty line .. keep as it is
		push(@rv, $rest);
		}
	}
return @rv;
}

# link_urls(text)
sub link_urls
{
local $r = $_[0];
$r =~ s/((http|ftp|https|mailto):[^><"'\s]+[^><"'\s\.])/<a href="$1">$1<\/a>/g;
return $r;
}

# list_assigns()
# Returns a list of qmail user assignments
sub list_assigns
{
if (!scalar(@list_assigns_cache)) {
	local @rv;
	local $lnum = 0;
	open(ASSIGNS, $qmail_assigns_file);
	while(<ASSIGNS>) {
		s/\r|\n//g;
		last if ($_ eq '.');
		local @line = split(/:/, $_, 8);
		if ($line[0] =~ /^([\+=])(\S*)/) {
			local $asn = { 'address' => $2,
				       'mode' => $1,
				       'user' => $line[1],
				       'uid' => $line[2],
				       'gid' => $line[3],
				       'home' => $line[4],
				       'dash' => $line[5],
				       'preext' => $line[6],
				       'idx' => scalar(@rv),
				       'line' => $lnum };
			push(@rv, $asn);
			}
		$lnum++;
		}
	close(ASSIGNS);
	@list_assigns_cache = @rv;
	}
return @list_assigns_cache;
}

# create_assign(&assign)
sub create_assign
{
&list_assigns();	# force cache init
&lock_file($qmail_assigns_file);
local $lref = &read_file_lines($qmail_assigns_file);
local $dot;
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] eq '.') {
		$dot++;
		last;
		}
	}
splice(@$lref, $i, 0, join(":", "$_[0]->{'mode'}$_[0]->{'address'}",
				$_[0]->{'user'}, $_[0]->{'uid'}, $_[0]->{'gid'},
				$_[0]->{'home'}, $_[0]->{'dash'},
				$_[0]->{'preext'}, ''));
push(@$lref, ".") if (!$dot);
&flush_file_lines();
&unlock_file($qmail_assigns_file);

# Update in memory cache
$_[0]->{'line'} = @$lref-1;
$_[0]->{'idx'} = scalar(@list_assigns_cache);
push(@list_assigns_cache, $_[0]);
}

# modify_assign(&old, &assign)
sub modify_assign
{
&lock_file($qmail_assigns_file);
local $lref = &read_file_lines($qmail_assigns_file);
$lref->[$_[0]->{'line'}] = join(":", "$_[1]->{'mode'}$_[1]->{'address'}",
				$_[1]->{'user'}, $_[1]->{'uid'}, $_[1]->{'gid'},
				$_[1]->{'home'}, $_[1]->{'dash'},
				$_[1]->{'preext'}, '');
&flush_file_lines();
&unlock_file($qmail_assigns_file);

# Update in memory cache
if ($_[0] ne $_[1]) {
	$_[1]->{'line'} = $_[0]->{'line'};
	$_[1]->{'idx'} = $_[0]->{'idx'};
	$list_assigns_cache[$_[1]->{'idx'}] = $_[1];
	}
}

# delete_assign(&assign)
sub delete_assign
{
&lock_file($qmail_assigns_file);
local $lref = &read_file_lines($qmail_assigns_file);
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
&unlock_file($qmail_assigns_file);

# delete from cache
splice(@list_assigns_cache, $_[0]->{'idx'}, 1);
foreach my $v (@list_assigns_cache) {
	$v->{'line'}-- if ($v->{'line'} > $_[0]->{'line'});
	$v->{'idx'}-- if ($v->{'idx'} > $_[0]->{'idx'});
	}
}

# assign_form([&assign])
sub assign_form
{
print "<form method=post action=save_assign.cgi>\n";
if ($_[0]) { print "<input type=hidden name=idx value='$_[0]->{'idx'}'>\n"; }
else { print "<input type=hidden name=new value=1>\n"; }

print "<table border>\n";
print "<tr $tb> <td><b>",$a ? $text{'sform_edit'}
			    : $text{'sform_create'},"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td valign=top><b>$text{'sform_address'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=mode value='=' %s> %s\n",
	!$_[0] || $_[0]->{'mode'} eq '=' ? 'checked' : '', $text{'sform_mode0'};
printf "<input name=address0 size=20 value='%s'><br>\n",
	$_[0] && $_[0]->{'mode'} eq '=' ? $_[0]->{'address'} : '';
printf "<input type=radio name=mode value='+' %s> %s\n",
	$_[0] && $_[0]->{'mode'} eq '+' ? 'checked' : '', $text{'sform_mode1'};
printf "<input name=address1 size=20 value='%s'></td> </tr>\n",
	$_[0] && $_[0]->{'mode'} eq '+' ? $_[0]->{'address'} : '';

print "<tr> <td><b>$text{'sform_user'}</b></td>\n";
print "<td>",&unix_user_input("user", $_[0] ? $_[0]->{'user'} : ''),"</td>\n";

print "<td><b>$text{'sform_home'}</b></td>\n";
printf "<td><input name=home size=25 value='%s'> %s</td> </tr>\n",
	$_[0] ? $_[0]->{'home'} : '', &file_chooser_button("home", 1);

print "<tr> <td><b>$text{'sform_uid'}</b></td>\n";
printf "<td><input name=uid size=6 value='%s'></td>\n",
	$_[0] ? $_[0]->{'uid'} : '';

print "<td><b>$text{'sform_gid'}</b></td>\n";
printf "<td><input name=gid size=6 value='%s'></td> </tr>\n",
	$_[0] ? $_[0]->{'gid'} : '';

print "<tr> <td colspan=4 align=right>\n";
if ($_[0]) {
	print "<input type=submit value='$text{'save'}'>\n";
	print "<input type=submit name=delete value='$text{'delete'}'>\n";
	}
else { print "<input type=submit value='$text{'create'}'>\n"; }
print "</td> </tr>\n";
print "</table></td></tr></table></form>\n";
}

# user_mail_dir(username, ...)
# Returns the full path to a user's mail file or directory
sub user_mail_dir
{
if ($config{'mail_system'} == 1) {
	if (@_ > 1) {
		return "$_[7]/$config{'mail_dir_qmail'}/";
		}
	else {
		local @u = getpwnam($_[0]);
		return "$u[7]/$config{'mail_dir_qmail'}/";
		}
	}
else {
	return &user_mail_file(@_);
	}
}

# restart_qmail()
# Tells qmail to reload its configuration files by sending a HUP signal
sub restart_qmail
{
if ($config{'apply_cmd'}) {
	&system_logged("($config{'apply_cmd'}) >/dev/null 2>&1 </dev/null");
	}
else {
	&kill_byname_logged("qmail-send", HUP);
	}
}

# stop_qmail()
# Attempts to stop qmail, and returns an error message if it fails
sub stop_qmail
{
if ($config{'stop_cmd'}) {
	&system_logged("( $config{'stop_cmd'} ) >/dev/null 2>&1 </dev/null &");
	return undef;
	}
else {
	if (&kill_byname_logged("qmail-send", TERM)) {
		return undef;
		}
	else {
		return $text{'stop_err'};
		}
	}
}

# start_qmail()
# Attempts to start qmail, and returns an error message if it fails
sub start_qmail
{
if ($config{'start_cmd'}) {
	&system_logged("( $config{'start_cmd'} ) >/dev/null 2>&1 </dev/null &");
	}
else {
	&system_logged("$qmail_start_cmd >/dev/null 2>&1 </dev/null &");
	}
return undef;
}

# Returns the PID of qmail-send if running
sub is_qmail_running
{
local ($pid) = &find_byname("^\\S*qmail-send");
return kill(0, $pid) ? $pid : undef;
}

1;

