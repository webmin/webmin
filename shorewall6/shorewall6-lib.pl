# shorewall6-lib.pl
# Common functions for the shorewall6 configuration files
# FIXME:
# - rule sections
# - read_shorewall6_config & standard_parser do not allow quoted comment characters

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# Get the version
$shorewall6_version = &get_shorewall6_version(0);
%shorewall6_config = &read_shorewall6_config();
#&dump_shorewall6_config();

# get access permissions
%access = &get_module_acl();

@shorewall6_files = ( 'zones', 'interfaces', 'policy', 'rules', 'tos',
	   	      'proxyndp', 'routestopped',
	   	      'tunnels', 'hosts', 'blacklist',
		      'providers', 'params', 'shorewall6.conf' );
@comment_tables = ( 'rules', 'tcrules' );

sub debug_message
{
	print STDERR scalar(localtime).": shorewall6-lib: @_\n";
}

# version_atleast(v1, v2, v3, ...)
# - Check if the Shorewall version is greater than or equal to the one supplied.
sub version_atleast
{
local @vsp = split(/\./, $shorewall6_version);
local $i;
for($i=0; $i<@vsp || $i<@_; $i++) {
	return 0 if ($vsp[$i] < $_[$i]);
	return 1 if ($vsp[$i] > $_[$i]);
	}
return 1;	# same!
}

sub read_shorewall6_config
{
	local @ret;
	open(SHOREWALL_CONF, "$config{'config_dir'}/shorewall6.conf");
	while (<SHOREWALL_CONF>) {
		chomp;
		s/\r//;
		s/#.*$//;
		@F = split( /=/, $_, 2 );
		next if $#F != 1;
		push @ret, ( $F[0], $F[1] );
	}
	close(SHOREWALL_CONF);
	return @ret;
}

# dump_shorewall6_config()
# - Debugging code
sub dump_shorewall6_config
{
	for (sort keys %shorewall6_config) {
		print STDERR "$_=$shorewall6_config{$_}\n";
	}
}

# shorewall6_config(var)
sub shorewall6_config
{
	if (exists $shorewall6_config{$_[0]}  &&  defined $shorewall6_config{$_[0]}) {
		return $shorewall6_config{$_[0]};
	}
	return '';
}

# return true if new zones format is in use
sub new_zones_format
{
	return 1;
}

# read_table_file(table, &parserfunc)
sub read_table_file
{
local @rv;
local $func = $_[1];
open(FILE, "$config{'config_dir'}/$_[0]");
while(<FILE>) {
	s/\r|\n//g;
	local $l = &$func($_);
	push(@rv, $l) if ($l);
	}
close(FILE);
return @rv;
}

# read_table_struct(table, &parserfunc)
sub read_table_struct
{
if (!defined($read_table_cache{$_[0]})) {
	local @rv;
	local $func = $_[1];
	open(FILE, "$config{'config_dir'}/$_[0]");
	local $lnum = 0;
	while(<FILE>) {
		s/\r|\n//g;
		local $cmt;
		if (s/#\s*(.*)$//) {
			$cmt = $1;
			}
		local $l = &$func($_);
		if ($l) {
			push(@rv, { 'line' => $lnum,
				    'file' => "$config{'config_dir'}/$_[0]",
				    'table' => $_[0],
				    'index' => scalar(@rv),
				    'values' => $l,
				    'comment' => $cmt });
			}
		$lnum++;
		}
	close(FILE);
	$read_table_cache{$_[0]} = \@rv;
	}
return $read_table_cache{$_[0]};
}

# find_line_num(&lref, &parserfunc, index)
sub find_line_num
{
local $lref = $_[0];
local $func = $_[1];
local $idx = 0;
for($i=0; $i<@$lref; $i++) {
	if (&$func($lref->[$i])) {
		if ($idx++ == $_[2]) {
			return $i;
			}
		}
	}
return undef;
}

# delete_table_row(table, &parserfunc, index)
sub delete_table_row
{
local $lref = &read_file_lines("$config{'config_dir'}/$_[0]");
local $lnum = &find_line_num($lref, $_[1], $_[2]);
splice(@$lref, $lnum, 1) if (defined($lnum));
&flush_file_lines();
}

# delete_table_struct(&struct)
sub delete_table_struct
{
local $lref = &read_file_lines($_[0]->{'file'});
splice(@$lref, $_[0]->{'line'}, 1);
&flush_file_lines();
local $cache = $read_table_cache{$_[0]->{'table'}};
local $idx = &indexof($_[0], @$cache);
if ($idx >= 0) {
	splice(@$cache, $idx, 1);
	}
local $c;
foreach $c (@$cache) {
	$c->{'line'}-- if ($c->{'line'} > $_[0]->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $_[0]->{'index'});
	}
}

# create_table_row(table, &parserfunc, line, [insert-index])
sub create_table_row
{
local $lref = &read_file_lines("$config{'config_dir'}/$_[0]");
local ($i, $idx);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^#+\s*LAST\s+LINE/) {
		$idx = $i;
		last;
		}
	elsif ($lref->[$i] =~ /^SECTION\s+NEW/) {
		$idx = $i+1;
		last;
		}
	}
if (defined($_[3])) {
	local $lnum = &find_line_num($lref, $_[1], $_[3]);
	$lnum = $idx if (!defined($lnum));
	splice(@$lref, $lnum, 0, &simplify_line($_[2]));
	}
else {
	splice(@$lref, $idx, 0, &simplify_line($_[2]));
	}
&flush_file_lines();
}

# create_table_struct(&struct, parserfunc, [&insert-before])
sub create_table_struct
{
local $lref = &read_file_lines("$config{'config_dir'}/$_[0]->{'table'}");
local ($i, $idx);
for($i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^#+\s*LAST\s+LINE/) {
		$idx = $i;
		last;
		}
	}
if (!defined($idx)) {
	$idx = @$lref;
	}
local $cache = &read_table_struct($_[0]->{'table'}, $_[1]);
if ($_[2]) {
	# Insert into file
	splice(@$lref, $_[2]->{'line'}, 0, &make_struct($_[0]));
	$_[0]->{'file'} = "$config{'config_dir'}/$_[0]->{'table'}";
	$_[0]->{'line'} = $_[2]->{'line'};
	$_[0]->{'index'} = $_[2]->{'index'};
	local $c;
	foreach $c (@$cache) {
		$_[0]->{'line'}++ if ($c->{'line'} >= $_[2]->{'line'});
		$_[0]->{'index'}++ if ($c->{'index'} >= $_[2]->{'index'});
		}
	local $iidx = &indexof($_[2], @$cache);
	splice(@$cache, $iidx, 0, $_[0]);
	}
else {
	# Append to file
	splice(@$lref, $idx, 0, &make_struct($_[0]));
	$_[0]->{'file'} = "$config{'config_dir'}/$_[0]->{'table'}";
	$_[0]->{'line'} = $idx;
	$_[0]->{'index'} = @$cache;
	push(@$cache, $_[0]->{'index'});
	}
&flush_file_lines();
}

# modify_table_row(table, &parserfunc, index, line)
sub modify_table_row
{
local $lref = &read_file_lines("$config{'config_dir'}/$_[0]");
local $lnum = &find_line_num($lref, $_[1], $_[2]);
$lref->[$lnum] = &simplify_line($_[3]) if (defined($lnum));
&flush_file_lines();
}

# modify_table_struct(&newstruct, &oldstruct)
sub modify_table_struct
{
local $lref = &read_file_lines("$config{'config_dir'}/$_[1]->{'table'}");
$lref->[$_[1]->{'line'}] = &make_struct($_[0]);
if ($_[0] ne $_[1]) {
	$_[0]->{'line'} = $_[1]->{'line'};
	$_[0]->{'index'} = $_[1]->{'index'};
	local $cache = $read_table_cache{$_[1]->{'table'}};
	local $idx = &indexof($_[1], @$cache);
	$cache->[$idx] = $_[0];
	}
&flush_file_lines();
}

# swap_table_rows(table, &parserfunc, index1, index2)
sub swap_table_rows
{
local $lref = &read_file_lines("$config{'config_dir'}/$_[0]");
local $lnum1 = &find_line_num($lref, $_[1], $_[2]);
local $lnum2 = &find_line_num($lref, $_[1], $_[3]);
($lref->[$lnum1], $lref->[$lnum2]) = ($lref->[$lnum2], $lref->[$lnum1]);
&flush_file_lines();
}

# make_struct(&struct)
sub make_struct
{
local $line = join("\t", @{$_[0]->{'values'}});
if ($_[0]->{'comment'}) {
	$line .= "\t# $_[0]->{'comment'}";
	}
return &simplify_line($line);
}

# simplify_line(line)
# Removes blank fields from the end of a line
sub simplify_line
{
local $rv = $_[0];
while($rv =~ s/\s+$// || $rv =~ s/\-$//) { }
return $rv;
}

sub lock_table
{
&lock_file("$config{'config_dir'}/$_[0]");
}

sub unlock_table
{
&unlock_file("$config{'config_dir'}/$_[0]");
}

# parser for whitespace-separated config files
sub standard_parser
{
local $l = $_[0];
$l =~ s/#.*$//;
local @sp = split(/\s+/, $l);
return undef if ($sp[0] eq "SECTION");
return @sp ? \@sp : undef;
}

# parser for shell-style config files
sub config_parser
{
    local $l = $_[0];
    $l =~ s/#\s*(.*?)\s*$//;		# save the comment we strip
    local @sp = split(/=/, $l, 2);
    if ($#sp > -1 && defined $1) {
	push @sp, $1;			# add back the saved comment, if present
	}
    return @sp ? \@sp : undef;
}

# determine which parser function to use
sub get_parser_func
{
    local $hashref = $_[0];
    &get_clean_table_name($hashref);
    local $pfunc = $hashref->{'tableclean'}."_parser";
    if (!defined(&$pfunc)) {
	if ($hashref->{'tableclean'} =~ /^(params|shorewall6_conf)$/) {
	    $pfunc = "config_parser";
	}
	else {
	    $pfunc = "standard_parser";
	}
    }
    return $pfunc;
}

# ensure that the passed string contains only characters valid in shell variable identifiers
sub clean_name
{
    local $str = $_[0];
    $str =~ s/\W/_/g;
    return $str;
}

# get a table name that is clean enough to use as a function prefix
sub get_clean_table_name
{
    local $hashref = $_[0];
    if (!exists hashref->{'tableclean'}) {
	$hashref->{'tableclean'} = &clean_name($in{'table'});
    }
}

# zone_field(name, value, othermode, simplemode)
sub zone_field
{
local @ztable = &read_table_file("zones", \&zones_parser);
local $found = 0;

print "<select name=$_[0]>\n";
if ($_[3] == 2) {
	$found = !$_[1];
	}
elsif ($_[3] == 1) {
	printf "<option value=- %s>%s</option>\n",
		$_[1] eq '-' ? "selected" : "", "&lt;$text{'list_any'}&gt;";
	$found = !$_[1] || $_[1] eq '-';
	}
elsif ($_[3] == 0) {
	printf "<option value=all %s>%s</option>\n",
		$_[1] eq 'all' ? "selected" : "", "&lt;$text{'list_any'}&gt;";
	printf "<option value=\$FW %s>%s</option>\n",
		&is_fw($_[1]) ? "selected" : "", "&lt;$text{'list_fw'}&gt;";
	$found = !$_[1] || $_[1] eq 'all' || &is_fw($_[1]);
	}
foreach $z (@ztable) {
	printf "<option value=%s %s>%s</option>\n",
		$z->[0], $_[1] eq $z->[0] ? "selected" : "", &convert_zone($z->[0]);
	$found++ if ($_[1] eq $z->[0]);
	}
if ($_[2]) {
	printf "<option value='' %s>%s</option>\n",
		$found ? "" : "selected", $text{'list_other'};
	}
else {
	print "<option value=$_[1] selected>$_[1]</option>\n" if (!$found);
	}
print "</select>\n";
return $found;
}

# iface_field(name, value)
sub iface_field
{
local @itable = &read_table_file("interfaces", \&standard_parser);
print "<select name=$_[0]>\n";
local $found = !$_[1];
foreach $i (@itable) {
	printf "<option value=%s %s>%s</option>\n",
		$i->[1], $_[1] eq $i->[1] ? "selected" : "", $i->[1];
	$found++ if ($_[1] eq $i->[1]);
	}
print "<option value=$_[1] selected>$_[1]</option>\n" if (!$found);
print "</select>\n";
}

# convert_zone(name)
# Given a zone name, returns a description
# FIXME: inefficient - should be able to pass ztable into this function
sub convert_zone
{
local @ztable = &read_table_file("zones", \&zones_parser);
foreach $z (@ztable) {
	if ($_[0] eq $z->[0]) {
		if (&new_zones_format()) {
			# No descriptions in new format - use comment field if present
			if (defined $z->[6]  &&  $z->[6] ne "") {
				$ret = $_[0]." - ".$z->[6];
				}
			else {
				$ret = $_[0];
				}
			}
		else {
			$ret = $z->[1];
			}
		}
	}
if (&is_fw($_[0])) {
	$ret = $text{'list_fw'};
	}
return $ret || $_[0];
}

# nice_host_list(list)
# Convert a comma-separate host string to space-separated
sub nice_host_list
{
local @hosts = split(/,/, $_[0]);
if (@host > 5) {
	return join(", ", @hosts[0..5]).", ...";
	}
else {
	return join(", ", @hosts);
	}
}

# is_fw(zone)
# - Checks if the supplied zone is the firewall zone.
#   Now handles renaming of firewall zone in shorewall6.conf.
sub is_fw
{
	local $fw = &shorewall6_config('FW');
	$fw = 'fw' if ($fw eq '');
	return $_[0] eq '$FW' || $_[0] eq $fw;
}

################################# zones #######################################

sub zones_parser
{
if (&new_zones_format()) {
	# New format
	local $l = $_[0];
	$l =~ s/#\s*(.*?)\s*$//;	# save the stripped comment
	local $comment = $1 if defined $1;
	local @r = split(/\s+/, $l, 6);
	if ($#r > -1) {
	    local $zone = shift @r;

	    # split out parent if it is present in the zone field
	    local $parent;
	    $zone =~ m/(.*?):(.*)/;
	    if (defined $2) {
		$zone = $1;
		$parent = $2;
		}
	    else {
		$parent = "";
		}
	    unshift @r, $zone, $parent;

	    # put the saved comment back
	    if (defined $comment) {
		# ensure option fields are present
		while ($#r < 5) {
		    push @r, "";
		}

		# add the comment field
		push @r, $comment;
		}
	    }
	return scalar(@r) ? \@r : undef;
	}
else {
	# Old format
	local $l = $_[0];
	$l =~ s/#.*$//;
	if ($l =~ /^(\S+)\s+(\S+)\s*(.*)/) {
		return [ $1, $2, $3 ];
		}
	else {
		return undef;
		}
	}
}

sub zones_columns
{
return &new_zones_format() ? 4 : 3;
}

# format a parsed row for display in list form
sub zones_row
{
if (&new_zones_format()) {
	return ( $_[0], $_[1], $text{'zones_'.$_[2]} || $_[2], $_[6] );
	}
else {
	return @_;
	}
}

sub zones_colnames
{
return ( $text{'zones_0'}, $text{'zones_1new'}, $text{'zones_2new'},
	$text{'zones_6new'} );
}

sub zones_form
{
# Shorewall 3 zones format
print "<tr> <td><b>$text{'zones_0'}</b></td>\n";
print "<td>",&ui_textbox("id", $_[0], 8),"</td>\n";

print "<td><b>$text{'zones_1new'}</b></td>\n";
print "<td>\n";
&zone_field("parent", $_[1], 0, 1);
print "</td> </tr>\n";

print "<td><b>$text{'zones_2new'}</b></td>\n";
print "<td>",&ui_select("type", $_[2],
	[ [ "ipv6", $text{'zones_ipv6'} ],
	  [ "ipsec", $text{'zones_ipsec'} ],
	  [ "ipsec6", $text{'zones_ipsec6'} ],
	  [ "bport", $text{'zones_bport'} ],
	  [ "bport6", $text{'zones_bport6'} ],
	  [ "firewall", $text{'zones_firewall'} ] ]),"</td> </tr>\n";

print "<tr> <td><b>$text{'zones_3new'}</b></td>\n";
print "<td>",&ui_textbox("opts", $_[3], 50),"</td> </tr>\n";

print "<tr> <td><b>$text{'zones_4new'}</b></td>\n";
print "<td>",&ui_textbox("opts_in", $_[4], 50),"</td> </tr>\n";

print "<tr> <td><b>$text{'zones_5new'}</b></td>\n";
print "<td>",&ui_textbox("opts_out", $_[5], 50),"</td> </tr>\n";

print "<tr> <td><b>$text{'zones_6new'}</b></td>\n";
print "<td>",&ui_textbox("comment", $_[6], 50),"</td> </tr>\n";

}

sub zones_validate
{
$in{'id'} =~ /^\S+$/ || &error($text{'zones_eid'});
&is_fw($in{'id'}) && &error($text{'zones_efwid'});
if (&new_zones_format()) {
	# Parse new format
	$in{'opts'} =~ /^\S*$/ || &error($text{'zones_eopts'});
	$in{'opts_in'} =~ /^\S*$/ || &error($text{'zones_eopts_in'});
	$in{'opts_out'} =~ /^\S*$/ || &error($text{'zones_eopts_out'});
	if (!defined $in{'parent'} || $in{'parent'} eq "-") {
	    return ( $in{'id'}, $in{'type'}, $in{'opts'},
		     $in{'opts_in'}, $in{'opts_out'}, "# $in{'comment'}" );
	    }
	else {
	    return ( $in{'id'}.":".$in{'parent'}, $in{'type'}, $in{'opts'},
		     $in{'opts_in'}, $in{'opts_out'}, "# $in{'comment'}" );
	    }
	}
else {
	# Parse old format
	$in{'name'} =~ /^\S+$/ || &error($text{'zones_ename'});
	$in{'desc'} =~ /\S/ || &error($text{'zones_edesc'});
	return ( $in{'id'}, $in{'name'}, $in{'desc'} );
	}
}

################################# interfaces ###################################

sub interfaces_row
{
return ( $_[1],
	 $_[0] eq '-' ? $text{'list_any'} : $_[0],
	 $_[3] ? $_[3] : $text{'list_none'} );
}

@interfaces_opts = ( 'dhcp', 'forward', 'ignore', 'optional' );
if (&version_atleast(4, 4, 7)) {
        push(@interfaces_opts, "bridge");
        }
if (&version_atleast(4, 4, 10)) {
        push(@interfaces_opts, "required");
        }
if (&version_atleast(4, 4, 13)) {
        push(@interfaces_opts, "blacklist");
        }

sub interfaces_form
{
print "<tr> <td><b>$text{'interfaces_0'}</b></td>\n";
print "<td><input name=iface size=6 value='$_[1]'></td>\n";

local @ztable = &read_table_file("zones", \&zones_parser);
print "<td><b>$text{'interfaces_1'}</b></td>\n";
print "<td>\n";
&zone_field("zone", $_[0], 0, 1);
print "</td> </tr>\n";


# options
local %opts = map { $_, 1 } split(/,/, $_[3]);
print "<tr> <td valign=top><b>$text{'interfaces_2'}</b></td> <td colspan=3>\n";
&options_input("opts", $_[3], \@interfaces_opts);
print "</td> </tr>\n";
}

sub interfaces_validate
{
$in{'iface'} =~ /^[a-z]+\d*(\.\d+)?$/ ||
	$in{'iface'} =~ /^[a-z]+\+$/ || &error($text{'interfaces_eiface'});
return ( $in{'zone'}, $in{'iface'}, '-',
	 join(",", split(/\0/, $in{'opts'})) );
}

################################# policy #######################################

sub policy_row
{
return ( $_[0] eq 'all' ? $text{'list_any'} :
	  &is_fw($_[0]) ? $text{'list_fw'} : $_[0],
	 $_[1] eq 'all' ? $text{'list_any'} :
	  &is_fw($_[1]) ? $text{'list_fw'} : $_[1],
	 $_[2], $_[3] eq '-' || $_[3] eq '' ? $text{'list_none'} : $_[3],
	 $_[4] =~ /(\d+):(\d+)/ ? &text('policy_limit', "$1", "$2")
				: $text{'list_none'} );
}

@policy_list = ( "ACCEPT", "DROP", "REJECT", "QUEUE", "NFQUEUE", "CONTINUE", "NONE" );

sub policy_form
{
local $found;

print "<tr> <td><b>$text{'policy_0'}</b></td>\n";
print "<td>\n";
&zone_field("source", $_[0], 0);
print "</td>\n";

print "<td><b>$text{'policy_1'}</b></td>\n";
print "<td>\n";
&zone_field("dest", $_[1], 0);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'policy_2'}</b></td>\n";
print "<td><select name=policy>\n";
$found = !$_[2];
foreach $p (@policy_list) {
	printf "<option value=%s %s>%s</option>\n",
		$p, lc($p) eq lc($_[2]) ? "selected" : "", $p;
	$found++ if (lc($p) eq lc($_[2]));
	}
print "<option value=$_[2] selected>$_[2]</option>\n" if (!$found);
print "</select></td>\n";

print "<td><b>$text{'policy_3'}</b></td>\n";
print "<td><select name=log>\n";
printf "<option value=- %s>%s</option>\n",
	$_[3] eq '-' || !$_[3] ? "selected" : "", "&lt;$text{'policy_nolog'}&gt;";
#printf "<option value=ULOG %s>%s</option>\n",
#	$_[3] eq 'ULOG' ? "selected" : "", "&lt;$text{'policy_ulog'}&gt;";
#$found = !$_[3] || $_[3] eq '-' || $_[3] eq 'ULOG';
&foreign_require("syslog", "syslog-lib.pl");
foreach $l (&syslog::list_priorities()) {
	printf "<option value=%s %s>%s</option>\n",
		$l, $_[3] eq $l ? "selected" : "", $l;
	$found++ if ($_[3] eq $l);
	}
print "<option value=$_[3] selected>$_[3]</option>\n" if (!$found);
print "</select></td> </tr>\n";

local ($l, $b) = $_[4] =~ /(\d+):(\d+)/ ? ($1, $2) : ( );
print "<tr> <td><b>$text{'policy_4'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=limit_def value=1 %s> %s\n",
	$l eq '' ? "checked" : "", $text{'list_none'};
printf "<input type=radio name=limit_def value=0 %s>\n",
	$l eq '' ? "" : "checked";
print &text('policy_limit',
	    "<input name=limit size=5 value='$l'>",
	    "<input name=burst size=5 value='$b'>"),"</td> </tr>\n";
}

sub policy_validate
{
&is_fw($in{'source'}) && &is_fw($in{'dest'}) && &error($text{'policy_efw'});
if (!$in{'limit_def'}) {
	$in{'limit'} =~ /^\d+$/ || &error($text{'policy_elimit'});
	$in{'burst'} =~ /^\d+$/ || &error($text{'policy_eburst'});
	}
return ( $in{'source'}, $in{'dest'}, $in{'policy'}, $in{'log'}, 
	 $in{'limit_def'} ? ( ) : ( "$in{'limit'}:$in{'burst'}" ) );
}

################################# rules #######################################

sub rules_row
{
return ( $_[0] =~ /^(\S+):/ ? "$1" : $_[0],
	 &is_fw($_[1]) ? $text{'list_fw'} :
	  $_[1] eq 'all' ? $text{'list_any'} :
	  $config{'display_zone_descriptions'} == 0 ? $_[1] :
	  $_[1] =~ /^([^:]+):(\S+)$/ ?
	  &text('rules_hosts', &convert_zone("$1"), &nice_host_list("$2")) :
	  &text('rules_zone', &convert_zone($_[1])),
	 &is_fw($_[2]) ? $text{'list_fw'} :
	  $_[2] eq 'all' ? $text{'list_any'} :
	  $_[2] =~ /^\d+$/ ? &text('rules_rport', $_[2]) :
	  $config{'display_zone_descriptions'} == 0 ? $_[2] :
	  $_[2] =~ /^([^:]+):(\S+)$/ ?
	  &text('rules_hosts', &convert_zone("$1"), &nice_host_list("$2")) :
	  &text('rules_zone', &convert_zone($_[2])),
	 $_[3] eq 'all' ? $text{'list_any'} :
	  $_[3] eq 'related' ? $text{'rules_related'} : uc($_[3]),
	 $_[3] eq 'all' || $_[3] eq 'related' ? "" :
	  $_[5] eq '-' || $_[5] eq '' ? $text{'list_any'} : $_[5],
	 $_[4] eq '-' || $_[4] eq '' ? "" : $_[4],
		$_[7] eq "-" ? "" : $_[7],
		$_[8] eq "-" ? "" : $_[8] 
	);
}

@rules_actions = ( 'ACCEPT', 'DROP', 'REJECT', 'DNAT', 'DNAT-', 'REDIRECT', 'CONTINUE', 
                   'ACCEPT+', 'NONAT', 'REDIRECT-', 'LOG', 'DNAT-', 'SAME', 'SAME-' ,
                   'QUEUE');

@rules_protos = ( 'all', 'related', 'tcp', 'udp', 'ipv6-icmp' );

sub rules_form
{
local $found;
local @ztable = &read_table_file("zones", \&zones_parser);

local ($action, $log) = split(/:/, $_[0]);
local $macroarg;
if ($action =~ /^(.*)\/(.*)$/) {
	$action = $1;
	$macroarg = $2;
	}

# Rule action
print "<tr> <td><b>$text{'rules_0'}</b></td>\n";
print "<td colspan=3><select name=action>\n";
$found = !$_[0];
foreach $a ((sort { $a cmp $b } @rules_actions),
	    "-------- Actions --------",
	    &list_standard_actions(),
	    (&version_atleast(3) ? ( "-------- Macros --------",
				     &list_standard_macros() ) : ( ) )) {
	printf "<option value=%s %s>%s</option>\n",
		$a, $action eq $a ? "selected" : "", $a;
	$found++ if ($action eq $a);
	}
print "<option value=$action selected>$action</option>\n" if (!$found);
print "</select>\n";

# Logging level
print "<b>$text{'rules_log'}</b> <select name=log>\n";
printf "<option value='' %s>%s</option>\n",
	!$log ? "selected" : "", "&lt;$text{'rules_nolog'}&gt;";
printf "<option value=ULOG %s>%s</option>\n",
	$log eq 'ULOG' ? "selected" : "", "&lt;$text{'policy_ulog'}&gt;";
$found = !$log || $log eq '-' || $log eq 'ULOG';
&foreign_require("syslog", "syslog-lib.pl");
foreach $l (&syslog::list_priorities()) {
	printf "<option value=%s %s>%s</option>\n",
		$l, $log eq $l ? "selected" : "", $l;
	$found++ if ($log eq $l);
	}
print "<option value=$log selected>$log</option>\n" if (!$found);
print "</select></td> </tr>\n";

if (&version_atleast(3)) {
	print "<tr> <td valign=top><b>$text{'rules_macro'}</b></td>\n";
	print "<td colspan=3 nowrap>\n";
	print &ui_select("macro", $macroarg,
		[ [ "", "&lt;$text{'rules_none2'}&gt;" ],
		  map { [ $_ ] } (sort { $a cmp $b } @rules_actions) ],
		1, 0, $macroarg);
	print "</td> </tr>\n";
	}

# Source zone and hosts
local ($zone, $host) = split(/:/, $_[1], 2);
print "<tr> <td valign=top><b>$text{'rules_1z'}</b></td>\n";
print "<td colspan=3 nowrap>\n";
$found = &zone_field("source", $zone, 1);
printf "<input name=sother size=10 value='%s'>\n",
	$found ? "" : $zone;

print "<br><b>$text{'rules_inzone'}</b>\n";
printf "<input type=checkbox name=sinzone_def value=1 %s> %s\n",
	$host ? "checked" : "", $text{'rules_addr'};
printf "<input name=sinzone size=50 value='%s'></td> </tr>\n",
	join(" ", split(/,/, $host));

($zone, $host) = split(/:/, $_[2], 2);
print "<tr> <td valign=top><b>$text{'rules_2z'}</b></td>\n";
print "<td colspan=3 nowrap>\n";
$found = &zone_field("dest", $zone, 1);
printf "<input name=dother size=10 value='%s'>\n",
	$found ? "" : $zone;

print "<br><b>$text{'rules_inzone'}</b>\n";
printf "<input type=checkbox name=dinzone_def value=1 %s> %s\n",
	$host ? "checked" : "", $text{'rules_addr'};
printf "<input name=dinzone size=50 value='%s'>\n",
	join(" ", split(/,/, $host));
print "<br>$text{'rules_dnat_dest'}</td> </tr>\n";

print "<tr> <td><b>$text{'rules_3'}</b></td>\n";
print "<td colspan=3><select name=proto>\n";
$found = !$_[3];
foreach $p (@rules_protos) {
	printf "<option value=%s %s>%s</option>\n",
		$p, $p eq $_[3] ? "selected" : "",
		$p eq 'all' ? "&lt;$text{'list_any'}&gt;" :
		 $p eq 'related' ? "&lt;$text{'rules_related'}&gt;" : uc($p);
	$found++ if ($p eq $_[3]);
	}
printf "<option value='' %s>%s</option>\n",
	$found ? "" : "selected", $text{'list_other'};
print "</select>\n";
printf "<input name=pother size=5 value='%s'></td> </tr>\n",
	$found ? "" : $_[3];

print "<tr> <td><b>$text{'rules_4'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=sport_def value=1 %s> %s\n",
	$_[5] eq '' || $_[5] eq '-' ? "checked" : "", $text{'list_any'};
printf "<input type=radio name=sport_def value=0 %s> %s\n",
	$_[5] eq '' || $_[5] eq '-' ? "" : "checked", $text{'rules_ranges'};
printf "<input name=sport size=30 value='%s'></td> </tr>\n",
	$_[5] eq '' || $_[5] eq '-' ? "" : join(" ", split(/,/, $_[5]));

print "<tr> <td><b>$text{'rules_5'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=dport_def value=1 %s> %s\n",
	$_[4] eq '' || $_[4] eq '-' ? "checked" : "", $text{'list_any'};
printf "<input type=radio name=dport_def value=0 %s> %s\n",
	$_[4] eq '' || $_[4] eq '-' ? "" : "checked", $text{'rules_ranges'};
printf "<input name=dport size=30 value='%s'>\n",
	$_[4] eq '' || $_[4] eq '-' ? "" : join(" ", split(/,/, $_[4]));
print "<br>$text{'rules_dnat_port'}</td> </tr>\n";

print "<tr> <td><b>$text{'rules_dnat'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=dnat_def value=1 %s> %s\n",
	$_[6] eq '' || $_[6] eq '-' ? "checked" : "", $text{'list_none'};
printf "<input type=radio name=dnat_def value=0 %s>\n",
	$_[6] eq '' || $_[6] eq '-' ? "" : "checked";
printf "<input name=dnat size=30 value='%s'></td> </tr>\n",
	$_[6] eq '' || $_[6] eq '-' ? "" : $_[6];

if (&version_atleast(1, 4, 7)) {
	print "<tr> <td><b>$text{'rules_rate'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=rate_def value=1 %s> %s\n",
		$_[7] eq "-" || !$_[7] ? "checked" : "", $text{'rules_norate'};
	printf "<input type=radio name=rate_def value=0 %s>\n",
		$_[7] eq "-" || !$_[7] ? "" : "checked";
	printf "<input name=rate size=15 value='%s'></td> </tr>\n",
		$_[7] eq "-" ? "" : $_[7];

	print "<tr> <td><b>$text{'rules_set'}</b></td> <td colspan=3>\n";
	printf "<input type=radio name=set_def value=1 %s> %s\n",
		$_[8] eq "-" || !$_[8] ? "checked" : "", $text{'rules_noset'};
	printf "<input type=radio name=set_def value=0 %s>\n",
		$_[8] eq "-" || !$_[8] ? "" : "checked";
	printf "<input name=set size=15 value='%s'></td> </tr>\n",
		$_[8] eq "-" ? "" : $_[8];
	}
}

sub rules_validate
{
$in{'action'} !~ /----/ || &error($text{'rules_eaction'});
$in{'source'} || $in{'sother'} =~ /^\S+$/ || &error($text{'rules_esother'});
!$in{'sinzone_def'} || $in{'sinzone'} =~ /\S/ || &error($text{'rules_esinzone'});
$in{'dest'} || $in{'dother'} =~ /^\S+$/ || &error($text{'rules_edother'});
!$in{'dinzone_def'} || $in{'dinzone'} =~ /\S/ || &error($text{'rules_edinzone'});
$in{'proto'} || $in{'pother'} =~ /^\S+$/ || &error($text{'rules_epother'});
$in{'sport_def'} || $in{'sport'} =~ /\S/ || &error($text{'rules_esport'});
$in{'dport_def'} || $in{'dport'} =~ /\S/ || &error($text{'rules_edport'});
$in{'dnat_def'} || &check_ip6address($in{'dnat'}) ||
	($in{'dnat'} =~ /^([0-9\.]+):([0-9\.]+)$/ &&
	 &check_ip6address("$1") && &check_ip6address("$2")) ||
	($in{'dnat'} =~ /^\!([0-9\.]+)$/ && &check_ip6address("$1")) ||
	($in{'dnat'} =~ /^\!([0-9\.]+),([0-9\.]+)(\/\d+)?$/ &&
	 &check_ip6address("$1") && &check_ip6address("$2")) ||
	($in{'dnat'} =~ /^\!([0-9\.,]+)$/ &&
         scalar(grep { &check_ip6address($_) } split(/,/, $1))) ||
	&error($text{'rules_ednat'});
$in{'action'} ne 'DNAT' && $in{'action'} ne 'REDIRECT' && $in{'action'} ne 'DNAT-' && 
	!$in{'dnat_def'} && &error($text{'rules_ednat2'});

$in{'sinzone'} =~ s/\s+/,/g;
$in{'dinzone'} =~ s/\s+/,/g;
$in{'sport'} =~ s/\s+/,/g;
$in{'dport'} =~ s/\s+/,/g;
if (&version_atleast(1, 4, 7)) {
	$in{'rate_def'} || $in{'rate'} =~ /^\S+$/ ||
		&error($text{'rules_erate'});
	$in{'set_def'} || $in{'set'} =~ /^\S+$/ ||
		&error($text{'rules_eset'});
	}
if ($in{'macro'} && &indexof($in{'action'}, &list_standard_macros()) >= 0) {
	$in{'action'} .= "/".$in{'macro'};
	$in{'proto'} = $in{'pother'} = undef;
	}
return ( $in{'log'} ? "$in{'action'}:$in{'log'}" : $in{'action'},
	 ($in{'source'} || $in{'sother'}).
	  ($in{'sinzone_def'} ? ":$in{'sinzone'}" : ""),
	 ($in{'dest'} || $in{'dother'}).
	  ($in{'dinzone_def'} ? ":$in{'dinzone'}" : ""),
	 $in{'proto'} || $in{'pother'} || '-',
	 $in{'dport_def'} ? "-" : $in{'dport'},
	 $in{'sport_def'} ? "-" : $in{'sport'},
	 $in{'dnat_def'} ? "-" : $in{'dnat'},
	 &version_atleast(1, 4, 7) ? (
		( $in{'rate_def'} ? "-" : $in{'rate'} ),
		( $in{'set_def'} ? "-" : $in{'set'} )
		) : ( )
	);
}

sub rules_columns
{
return &version_atleast(1, 4, 7) ? 6 : 8;
}

################################# tos #########################################

%tos_map = ( 0, 'Normal-Service',
	     2, 'Minimize-Cost',
	     4, 'Maximize-Reliability',
	     8, 'Maximize-Throughput',
	     16, 'Minimize-Delay' );
@tos_protos = ( 'tcp', 'udp', 'ipv6-icmp' );

sub tos_row
{
return ( &is_fw($_[0]) ? $text{'list_fw'} :
	  $_[0] eq 'all' ? $text{'list_any'} :
	  $_[0] =~ /^([^:]+):(\S+)$/ ? &text('rules_hosts', "$1", "$2") :
	  &text('rules_zone', $_[0]),
	 &is_fw($_[1]) ? $text{'list_fw'} :
	  $_[1] eq 'all' ? $text{'list_any'} :
	  $_[1] =~ /^([^:]+):(\S+)$/ ? &text('rules_hosts', "$1", "$2") :
	  &text('rules_zone', $_[1]),
	 uc($_[2]),
	 $_[3] eq '-' || $_[3] eq '' ? $text{'list_any'} : $_[3],
	 $_[4] eq '-' || $_[4] eq '' ? $text{'list_any'} : $_[4],
	 $tos_map{$_[5]} || $_[5],
	 $_[6] eq '-' ? $text{'list_none'} : $_[6] );
}

sub tos_form
{
local ($zone, $host) = split(/:/, $_[0], 2);
print "<tr> <td valign=top><b>$text{'tos_0z'}</b></td>\n";
print "<td colspan=3 nowrap>\n";
$found = &zone_field("source", $zone, 1);
printf "<input name=sother size=10 value='%s'>\n",
	$found ? "" : $zone;

print "<br><b>$text{'rules_inzone'}</b>\n";
printf "<input type=checkbox name=sinzone_def value=1 %s> %s\n",
	$host ? "checked" : "", $text{'rules_addr'};
printf "<input name=sinzone size=50 value='%s'></td> </tr>\n",
	join(" ", split(/,/, $host));

($zone, $host) = split(/:/, $_[1], 2);
print "<tr> <td valign=top><b>$text{'tos_1z'}</b></td>\n";
print "<td colspan=3 nowrap>\n";
$found = &zone_field("dest", $zone, 1);
printf "<input name=dother size=10 value='%s'>\n",
	$found ? "" : $zone;

print "<br><b>$text{'rules_inzone'}</b>\n";
printf "<input type=checkbox name=dinzone_def value=1 %s> %s\n",
	$host ? "checked" : "", $text{'rules_addr'};
printf "<input name=dinzone size=50 value='%s'></td> </tr>\n",
	join(" ", split(/,/, $host));

print "<tr> <td><b>$text{'tos_2'}</b></td>\n";
print "<td><select name=proto>\n";
$found = !$_[2];
foreach $p (@tos_protos) {
	printf "<option value=%s %s>%s</option>\n",
		$p, $p eq $_[2] ? "selected" : "", uc($p);
	$found++ if ($p eq $_[2]);
	}
printf "<option value='' %s>%s</option>\n",
	$found ? "" : "selected", $text{'list_other'};
print "</select>\n";
printf "<input name=pother size=5 value='%s'></td> </tr>\n",
	$found ? "" : $_[2];

print "<tr> <td><b>$text{'tos_3'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=sport_def value=1 %s> %s\n",
	$_[3] eq '' || $_[3] eq '-' ? "checked" : "", $text{'list_any'};
printf "<input type=radio name=sport_def value=0 %s> %s\n",
	$_[3] eq '' || $_[3] eq '-' ? "" : "checked", $text{'rules_ranges'};
printf "<input name=sport size=30 value='%s'></td> </tr>\n",
	$_[3] eq '' || $_[3] eq '-' ? "" : join(" ", split(/,/, $_[3]));

print "<tr> <td><b>$text{'tos_4'}</b></td> <td colspan=3>\n";
printf "<input type=radio name=dport_def value=1 %s> %s\n",
	$_[4] eq '' || $_[4] eq '-' ? "checked" : "", $text{'list_any'};
printf "<input type=radio name=dport_def value=0 %s> %s\n",
	$_[4] eq '' || $_[4] eq '-' ? "" : "checked", $text{'rules_ranges'};
printf "<input name=dport size=30 value='%s'></td> </tr>\n",
	$_[4] eq '' || $_[4] eq '-' ? "" : join(" ", split(/,/, $_[4]));

print "<tr> <td><b>$text{'tos_5'}</b></td>\n";
print "<td><select name=tos>\n";
$found = !$_[5];
foreach $t (sort { $a <=> $b } keys %tos_map) {
	printf "<option value=%s %s>%s</option>\n",
		$t, $_[5] == $t ? "selected" : "", $tos_map{$t};
	$found++ if ($_[5] == $t);
	}
print "<option value=$_[5] selected>$_[5]</option>\n" if (!$found);
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'tos_6'}</b></td>\n";
printf "<td><input name=mark size=50 value='%s'></td> </tr>\n",
	$_[6] eq "-" ? "" : $_[6];
}

sub tos_validate
{
$in{'source'} || $in{'sother'} =~ /^\S+$/ || &error($text{'rules_esother'});
!$in{'sinzone_def'} || $in{'sinzone'} =~ /\S/ || &error($text{'rules_esinzone'});
$in{'dest'} || $in{'dother'} =~ /^\S+$/ || &error($text{'rules_edother'});
!$in{'dinzone_def'} || $in{'dinzone'} =~ /\S/ || &error($text{'rules_edinzone'});
$in{'proto'} || $in{'pother'} =~ /^\S+$/ || &error($text{'rules_epother'});
$in{'sport_def'} || $in{'sport'} =~ /\S/ || &error($text{'rules_esport'});
$in{'dport_def'} || $in{'dport'} =~ /\S/ || &error($text{'rules_edport'});
return ( ($in{'source'} || $in{'sother'}).
	  ($in{'sinzone_def'} ? ":$in{'sinzone'}" : ""),
	 ($in{'dest'} || $in{'dother'}).
	  ($in{'dinzone_def'} ? ":$in{'dinzone'}" : ""),
	 $in{'proto'} || $in{'pother'},
	 $in{'sport_def'} ? "-" : join(",", split(/\s+/, $in{'sport'})),
	 $in{'dport_def'} ? "-" : join(",", split(/\s+/, $in{'dport'})),
	 $in{'tos'},
	 $in{'mark'} || "-" );
}

################################# proxyndp #######################################

sub proxyndp_row
{
return ( $_[0],
	 $_[1] eq '-' || $_[1] eq '' ? $text{'list_auto'} : $_[1],
	 $_[2],
	 $_[4] =~ /yes/i ? $text{'yes'} : $text{'no'} );
}

sub proxyndp_form
{
print "<tr> <td><b>$text{'proxyndp_0'}</b></td>\n";
print "<td><input name=addr size=15 value='$_[0]'></td>\n";

print "<td><b>$text{'proxyndp_1'}</b></td>\n";
printf "<td><input type=radio name=int_def value=1 %s> %s\n",
	$_[1] eq '-' || $_[1] eq '' ? "checked" : "", $text{'list_auto'};
printf "<input type=radio name=int_def value=0 %s>\n",
	$_[1] eq '-' || $_[1] eq '' ? "" : "checked";
&iface_field("int", $_[1] eq '-' ? undef : $_[1]);
print "</td> </tr>";

local $have = $_[3] =~ /yes/i;
print "<tr> <td><b>$text{'proxyndp_have'}</b></td>\n";
printf "<td><input type=radio name=have value=1 %s> %s\n",
	$have ? "checked" : "", $text{'yes'};
printf "<input type=radio name=have value=0 %s> %s</td>\n",
	$have ? "" : "checked", $text{'no'};

print "<td><b>$text{'proxyndp_2'}</b></td>\n";
print "<td>";
&iface_field("ext", $_[2]);
print "</td> </tr>";

local $pers = $_[4] =~ /yes/i;
print "<tr> <td><b>$text{'proxyndp_pers'}</b></td>\n";
printf "<td><input type=radio name=pers value=1 %s> %s\n",
	$pers ? "checked" : "", $text{'yes'};
printf "<input type=radio name=pers value=0 %s> %s</td>\n",
	$pers ? "" : "checked", $text{'no'};
}

sub proxyndp_validate
{
&check_ip6address($in{'addr'}) || &error($text{'proxyndp_eaddr'});
return ( $in{'addr'},
	 $in{'int_def'} ? "-" : $in{'int'},
	 $in{'ext'},
	 $in{'have'} ? "yes" : "no",
	 $in{'pers'} ? "yes" : "no" 
	); 
	 
}

sub proxyndp_columns
{
return 4 ;
}

################################ routestopped ##################################

sub routestopped_row
{
return ( $_[0], $_[1],
	 $_[2] eq '-' || $_[2] eq '' ? $text{'default'} : $_[2],
	 $_[3] eq '-' || $_[3] eq '' ? $text{'tunnels_gnone'} : $_[3] );
}

sub routestopped_columns
{
return 2;
}

@routestopped_options = ( "routeback", "source", "dest", "critical" );

sub routestopped_form
{
print "<tr> <td valign=top><b>$text{'routestopped_0'}</b></td>\n";
print "<td valign=top>";
&iface_field("iface", $_[0]);
print "</td>\n";

local $none = $_[1] eq '' || $_[1] eq '-' || $_[1] eq '0.0.0.0/0';
print "<td valign=top><b>$text{'routestopped_1'}</b></td>\n";
printf "<td><input type=radio name=addr_def value=1 %s> %s<br>\n",
	$none ? "checked" : "", $text{'routestopped_all'};
printf "<input type=radio name=addr_def value=0 %s> %s<br>\n",
	$none ? "" : "checked", $text{'routestopped_list'};
print "<textarea name=addr rows=5 cols=20>",
	$none ? "" : join("\n", split(/,/, $_[1])),
	"</textarea></td> </tr>\n";

if (&version_atleast(3)) {
	print "<tr> <td valign=top><b>$text{'routestopped_2'}</b></td>\n";
	print "<td colspan=3>\n";
	&options_input("opts", $_[2], \@routestopped_options);
	print "</td> </tr>\n";
	}
}

sub routestopped_validate
{
$in{'addr_def'} || $in{'addr'} =~ /\S/ || &error($text{'routestopped_eaddr'});
return ( $in{'iface'},
	 $in{'addr_def'} ? "-" : join(",", split(/\s+/, $in{'addr'})),
	 join(",", split(/\0/, $in{'opts'})) );
}

################################ tunnels ##################################

sub tunnels_row
{
local $tt = $_[0];
$tt =~ s/^(openvpn|openvpnserver|openvpnclient|generic):.*$/$1/;
return ( $text{'tunnels_'.$tt} || $tt,
	 $_[1] eq '-' || $_[1] eq '' ? $text{'routestopped_all'} : $_[1],
	 $_[2], $_[3] );
}

sub tunnels_form
{
print "<tr> <td><b>$text{'tunnels_0'}</b></td>\n";
print "<td><select name=type>\n";
local $tt;
local $found = !$_[0];
local $ttype = $_[0];
local $tport;
if ($ttype =~ s/^(openvpn|openvpnserver|openvpnclient|generic):(.*)$/$1/) {
	$tport = $2;
	}
foreach $tt ('ipsec', 'ipsecnat',
	     'ipsec:ah',
	     'gre', 'l2tp', 'openvpn', 'openvpnclient', 'openvpnserver', 'generic') {
	printf "<option value=%s %s>%s</option>\n",
		$tt, $ttype eq $tt ? "selected" : "",
		$text{'tunnels_'.$tt.'_l'} || $text{'tunnels_'.$tt};
	$found++ if ($ttype eq $tt);
	}
print "<option value=$ttype selected>",uc($ttype),"</option>\n" if (!$found);
print "</select>\n";
print "<input name=tport size=10 value='$tport'>\n";
print "</td>\n";

print "<tr> <td><b>$text{'tunnels_1'}</b></td>\n";
print "<td>";
&zone_field("zone", $_[1], 0, 0);
print "</td> </tr>\n";

local $none = $_[2] eq '' || $_[2] eq '-';
print "<tr> <td><b>$text{'tunnels_2'}</b></td> <td valign=top>\n";
printf "<input type=radio name=gateway_def value=1 %s> %s\n",
	$none ? "checked" : "", $text{'default'};
printf "<input type=radio name=gateway_def value=0 %s> %s\n",
	$none ? "" : "checked", $text{'tunnels_sel'};
printf "<input name=gateway size=20 value='%s'></td> </tr>\n", $_[2];

local $none = $_[2] eq '' || $_[2] eq '-';
print "<tr> <td><b>$text{'tunnels_3'}</b></td> <td valign=top>\n";
printf "<input type=radio name=gzones_def value=1 %s> %s\n",
	$none ? "checked" : "", $text{'tunnels_gnone'};
printf "<input type=radio name=gzones_def value=0 %s> %s\n",
	$none ? "" : "checked", $text{'tunnels_gsel'};
printf "<input name=gzones size=50 value='%s'></td> </tr>\n",
	join(" ", split(/,/, $_[3]));
}

sub tunnels_validate
{
$in{'gateway_def'} || &check_ip6address($in{'gateway'}) ||
	($in{'gateway'} =~ /^(\S+)\/(\d+)$/ && &check_ip6address($1)) ||
		&error($text{'tunnels_egateway'});
if (($in{'type'} eq "openvpn") || ($in{'type'} eq "openvpnclient") || 
    ($in{'type'} eq "openvpnserver")) {
	$in{'tport'} =~ /^\d*$/ || &error($text{'tunnels_eopenvpn'});
	$in{'type'} .= ":".$in{'tport'} if ($in{'tport'});
	}
elsif ($in{'type'} eq 'generic') {
	$in{'tport'} =~ /^\S+$/ || &error($text{'tunnels_egeneric'});
	$in{'type'} .= ":".$in{'tport'};
	}
return ( $in{'type'}, $in{'zone'},
	 $in{'gateway_def'} ? '-' : $in{'gateway'},
	 $in{'gzones_def'} ? '-' : join(",", split(/\s+/, $in{'gzones'})) );
}

################################ hosts ##################################

sub hosts_row
{
return ( $_[0], $_[1] =~ /^(\S+):(\S+)$/ ? ( $1, $2 ) : ( undef, undef ) );
}

@host_options = ("routeback", "tcpflags", "ipsec");

sub hosts_form
{
print "<tr> <td><b>$text{'hosts_0'}</b></td>\n";
print "<td>";
&zone_field("zone", $_[0], 0, 2);
print "</td> </tr>\n";

local ($iface, $net) = split(/:/, $_[1]);
print "<tr> <td><b>$text{'hosts_1'}</b></td>\n";
print "<td>";
&iface_field("iface", $iface);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'hosts_2'}</b></td>\n";
print "<td><input name=net size=50 value='$net'></td> </tr>\n";

print "<tr> <td valign=top><b>$text{'hosts_opts'}</b></td> <td>\n";
&options_input("opts", $_[2], \@host_options);
print "</td> </tr>\n";
}

sub hosts_validate
{
&check_ip6address($in{'net'}) ||
	$in{'net'} =~ /^(\S+)\/(\d+)$/ && &check_ip6address($1) ||
	&error($text{'hosts_enet'});
return ( $in{'zone'}, $in{'iface'}.":".$in{'net'},
	 join(",", split(/\0/, $in{'opts'})) );
}

################################ blacklist ##################################

sub blacklist_row
{
return ( $_[0] eq '-' ? $text{'blacklist_any'} : $_[0],
	 uc($_[1]) || $text{'blacklist_any'},
	 $_[2] || $text{'blacklist_any'} );
}

@blacklist_protos = ( undef, 'tcp', 'udp', 'dccp', 'sctp', 'udplite' );

sub blacklist_form
{
print "<tr> <td valign=top><b>$text{'blacklist_host'}</b></td> <td colspan=3>\n";
local ($mode, $ipset, $mac, $ip);
if ($_[0] =~ /^\+(.*)/) {
	$mode = 2; $ipset = $1;
	}
elsif ($_[0] =~ /^\~(.*)$/) {
	$mode = 1; $mac = $1;
	}
elsif ($_[0] eq '-') {
	$mode = 3;
	}
else {
	$mode = 0; $ip = $_[0];
	}
print &ui_radio("host_def", $mode,
    [ [ 0, &text('hosts_ip', &ui_textbox("host", $ip, 30))."<br>" ],
      [ 1, &text('hosts_mac', &ui_textbox("mac", $mac, 30))."<br>" ],
      [ 3, $text{'hosts_any'}."<br>" ],
      [ 2, &text('hosts_ipset', &ui_textbox("ipset", $ipset, 15)) ],
    ]);
print "</td> </tr>\n";

print "<tr> <td><b>$text{'blacklist_proto'}</b></td>\n";
print "<td colspan=3><select name=proto>\n";
$found = !$_[1];
foreach $p (@blacklist_protos) {
	printf "<option value='%s' %s>%s</option>\n",
		$p, $p eq $_[1] ? "selected" : "",
		$p eq '' ? "&lt;$text{'list_any'}&gt;" : uc($p);
	$found++ if ($p eq $_[1]);
	}
printf "<option value='*' %s>%s</option>\n",
	$found ? "" : "selected", $text{'list_other'};
print "</select>\n";
printf "<input name=pother size=5 value='%s'></td> </tr>\n",
	$found ? "" : $_[1];

print "<tr> <td><b>$text{'blacklist_ports'}</b></td>\n";
print "<td colspan=3><input name=ports size=20 value='$_[2]'></td> </tr>\n";
}

sub blacklist_validate
{
local $host;
if ($in{'host_def'} == 0) {
	&check_ip6address($in{'host'}) ||
		$in{'host'} =~ /^(\S+)\/(\d+)$/ && &check_ip6address($1) ||
		&error($text{'blacklist_ehost'});
	$host = $in{'host'};
	}
elsif ($in{'host_def'} == 1) {
	$in{'mac'} =~ s/:/-/g;
	$in{'mac'} =~ /^[0-9a-f]{2}(\-[0-9a-f]{2}){5}$/ ||
		&error($text{'blacklist_emac'});
	$host = "~".$in{'mac'};
	}
elsif ($in{'host_def'} == 2) {
	$in{'ipset'} =~ /^\S+$/ || &error($text{'blacklist_eipset'});
	$host = "+".$in{'ipset'};
	}
elsif ($in{'host_def'} == 3) {
	$host = "-";
	}
local $proto;
if ($in{'proto'} eq '*') {
	$in{'pother'} =~ /^\d+$/ ||
	    defined(getprotobyname($in{'pother'})) ||
		&error($text{'blacklist_eproto'});
	$proto = lc($in{'pother'});
	}
else {
	$proto = lc($in{'proto'});
	}
if ($proto eq "tcp" || $proto eq "udp") {
	$in{'ports'} =~ /^\S+$/ || &error($text{'blacklist_eports'});
	}
elsif ($in{'ports'}) {
	&error($text{'blacklist_eports2'});
	}
return ( $host, $proto, $in{'ports'} );
}

################################ providers ##################################

sub providers_row
{
return ( $_[0], $_[1], $_[2], $_[4], $_[5] );
}

@providers_opts = ( "balance", "fallback", "track", "loose", "notrack", "tproxy" );

sub providers_form
{
print "<tr> <td><b>$text{'providers_name'}</b></td>\n";
print "<td><input name=name size=20 value='$_[0]'></td>\n";

print "<td><b>$text{'providers_number'}</b></td>\n";
print "<td><input name=number size=4 value='$_[1]'></td> </tr>\n";

print "<tr> <td><b>$text{'providers_iface'}</b></td>\n";
print "<td>";
&iface_field("iface", $_[4]);
print "</td>\n";

print "<td><b>$text{'providers_mark'}</b></td>\n";
print "<td><input name=mark size=4 value='$_[2]'></td> </tr>\n";

print "<tr> <td><b>$text{'providers_gateway'}</b></td>\n";
print "<td><input name=gateway size=15 value='$_[5]'></td>\n";

local $ddef = $_[3] eq "-" || $_[3] eq "" ? 0 : $_[3] eq "main" ? 1 : 2;
print "<td><b>$text{'providers_dup'}</b></td>\n";
print "<td>",&ui_radio("dup_def", $ddef,
		[ [ 0, $text{'default'} ],
		  [ 1, $text{'providers_main'} ],
		  [ 2, &ui_textbox("dup", $ddef == 2 ? $_[3] : "", 5) ] ]),
      "</td> </tr>\n";

local %opts = map { $_, 1 } split(/,/, $_[6]);
print "<tr> <td valign=top><b>$text{'providers_opts'}</b></td> <td>\n";
foreach my $o (@providers_opts) {
	print &ui_checkbox("opts", $o, $text{'providers_'.$o}, $opts{$o})."<br>\n";
	delete($opts{$o});
	}
foreach my $o (keys %opts) {
	print &ui_hidden("opts", $o),"\n";
	}
print "</td>\n";

print "<td valign=top><b>$text{'providers_copy'}</b></td>\n";
print "<td valign=top><input name=copy size=15 value='$_[7]'></td> </tr>\n";
}

sub providers_validate
{
$in{'name'} =~ /^\S+$/ || &error($text{'providers_ename'});
$in{'number'} =~ /^\d+$/ || &error($text{'providers_enumber'});
$in{'mark'} =~ /^\d+$/ || &error($text{'providers_emark'});
$in{'dup_def'} < 2 || $in{'dup'} =~ /^\S+$/ || &error($text{'providers_edup'});
&check_ip6address($in{'gateway'}) || &error($text{'providers_egateway'});
return ( $in{'name'}, $in{'number'}, $in{'mark'},
	 $in{'dup_def'} == 0 ? '-' : $in{'dup_def'} == 1 ? 'main' : $in{'dup'},
	 $in{'iface'}, $in{'gateway'},
	 join(",", split(/\0/, $in{'opts'})) || "-",
	 $in{'copy'} || "-" );
}

################################ shorewall6.conf ##################################

sub conf_form
{
    local ($msg1, $msg2, $msg3, $field1, $field2, $field3, $dummy) = @_;

    $field1 =~ s/"/&#34;/g;
    print "<tr><td><b>$msg1</b></td>\n";
    print "<td><input name=var size=50 value=\"$field1\"></td></tr>\n";

    $field2 =~ s/"/&#34;/g;
    print "<tr><td><b>$msg2</b></td>\n";
    print "<td><input name=val size=50 value=\"$field2\"></td></tr>\n";

    $field3 =~ s/"/&#34;/g;
    print "<tr><td><b>$msg3</b></td>\n";
    print "<td><input name=comment size=50 value=\"$field3\"></td></tr>\n";

    print "</td></tr>\n";
}

################################ shorewall6.conf ##################################

sub shorewall6_conf_columns
{
    return 3;
}

sub shorewall6_conf_form
{
    &conf_form($text{'shorewall6_conf_0'}, $text{'shorewall6_conf_1'}, $text{'shorewall6_conf_2'}, @_);
}

sub shorewall6_conf_validate
{
    &error($text{'shorewall6_conf_varname'}) unless $in{'var'} =~ /^\w+$/;
    local $comment = "";
    $comment = "\t# ".$in{'comment'} if (exists $in{'comment'} and $in{'comment'} ne "");
    return ($in{'var'}.'='.$in{'val'}.$comment);
}

################################ params ##################################

sub params_columns
{
    return 3;
}

sub params_form
{
    &conf_form($text{'params_0'}, $text{'params_1'}, $text{'params_2'}, @_);
}

sub params_validate
{
    &error($text{'params_varname'}) unless $in{'var'} =~ /^\w+$/;
    local $comment = "";
    $comment = "\t# ".$in{'comment'} if (exists $in{'comment'} and $in{'comment'} ne "");
    return ($in{'var'}.'='.$in{'val'}.$comment);
}


#############################################################################

# can_access(file)
sub can_access
{
if ($access{'files'} eq '*') {
	return 1;
	}
else {
	local @acc = split(/\s+/, $access{'files'});
	return &indexof($_[0], @acc) >= 0;
	}
}

# run_before_apply_command()
# Runs the before-applying command, if any. If it failes, returns the error
# message output
sub run_before_apply_command
{
if ($config{'before_apply_cmd'}) {
	local $out = &backquote_logged("($config{'before_apply_cmd'}) </dev/null 2>&1");
	return $out if ($?);
	}
return undef;
}

# run_after_apply_command()
# Runs the after-applying command, if any
sub run_after_apply_command
{
if ($config{'after_apply_cmd'}) {
	&system_logged("($config{'after_apply_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# list_standard_actions()
# Returns a list of standard Shorewall actions
sub list_standard_actions
{
local @rv;
foreach my $a (split(/\t+/, $config{'actions'})) {
	open(ACTIONS, $a);
	while(<ACTIONS>) {
		s/\r|\n//g;
		s/#.*$//;
		s/\s+$//;
		if (/\S/) {
			push(@rv, $_);
			}
		}
	close(ACTIONS);
	}
if (&version_atleast(3)) {
	# Add built-in actions
	push(@rv, "allowBcast", "dropBcast", "dropNotSyn", "rejNotSyn",
		  "dropInvalid", "allowInvalid", "allowoutUPnP", "allowinUPnP",
		  "forwardUPnP");
	}
return &unique(@rv);
}

# list_standard_macros()
# Returns a list of all macro. actions
sub list_standard_macros
{
local @rv;
foreach my $a ($config{'config_dir'}, $config{'macros'}) {
	opendir(DIR, $a);
	foreach my $f (readdir(DIR)) {
		push(@rv, $1) if ($f =~ /^macro\.(.*)$/);
		}
	closedir(DIR);
	}
return &unique(@rv);
}

$BETA_STR = "-Beta";
$BETA_NUM = "\.0000\.";

# get_shorewall6_version(nocache)
sub get_shorewall6_version
{
local ($nocache) = @_;
local $version;
if (!$nocache && open(VERSION, "$module_config_directory/version")) {
	chop($version = <VERSION>);
	close(VERSION);
	}
if (!$version) {
	local $out = `$config{'shorewall6'} version 2>&1`;
	$out =~ s/\r//g;
	$out =~ s/$BETA_STR/$BETA_NUM/i;		# Convert beta string to version number.
	if ($out =~ /(\n|^)([0-9\.]+)\n/) {
		$version = $2;
		}
	}
return $version;
}

sub get_printable_version($)
{
	local $out = $_[0];
	$out =~ s/$BETA_NUM/$BETA_STR/i;		# Convert version number back to string.
	return $out;
}

sub list_protocols
{
local @stdprotos = ( 'tcp', 'udp', 'ipv6-icmp' );
local @otherprotos;
open(PROTOS, "/etc/protocols");
while(<PROTOS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@otherprotos, $1) if (/^(\S+)\s+(\d+)/);
	}
close(PROTOS);
@otherprotos = sort { lc($a) cmp lc($b) } @otherprotos;
return &unique(@stdprotos, @otherprotos);
}

# options_input(name, value, &opts)
sub options_input
{
local ($name, $value, $opts) = @_;
local %opts = map { $_, 1 } split(/,/, $value);
print "<table width=100%>\n";
local $i = 0;
foreach my $o (@$opts) {
	print "<tr>\n" if ($i%3 == 0);
	printf "<td><input type=checkbox name=$name value=%s %s> %s</td>\n",
		$o, $opts{$o} ? "checked" : "", $text{'opts_'.$o} || $o;
	print "</tr>\n" if ($i%3 == 2);
	delete($opts{$o});
	$i++;
	}
foreach $o (keys %opts) {
	print "<input type=hidden name=opts value=$o>\n";
	}
print "</table>\n";
}

1;

