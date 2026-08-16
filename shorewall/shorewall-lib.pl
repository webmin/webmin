# shorewall-lib.pl
# Common functions for the shorewall configuration files
# FIXME:
# - rule sections
# - read_shorewall_config & standard_parser do not allow quoted comment characters

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# Get the version
$shorewall_version = &get_shorewall_version(0);
%shorewall_config = &read_shorewall_config();

# get access permissions
%access = &get_module_acl();

@shorewall_files = ( 'zones', 'interfaces', 'policy', 'rules', 'tos',
	   	     'masq', 'nat', 'proxyarp', 'routestopped',
	   	     'tunnels', 'hosts', 'blacklist',
		     ( &version_atleast(2, 3) ? ( 'providers', 'route_rules' )
					      : ( ) ),
	   	     'params', 'shorewall.conf',
		   );
@comment_tables = ( 'masq', 'nat', 'rules', 'tcrules' );

sub debug_message
{
	print STDERR scalar(localtime).": shorewall-lib: @_\n";
}

# version_atleast(v1, v2, v3, ...)
# - Check if the Shorewall version is greater than or equal to the one supplied.
sub version_atleast
{
return &compare_version_numbers($shorewall_version, join(".", @_)) >= 0;
}

# read_shorewall_config()
# Returns an array of hash refs for the global Shorewall config
sub read_shorewall_config
{
my @ret;
open(SHOREWALL_CONF, "<$config{'config_dir'}/shorewall.conf");
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

# shorewall_config(var)
sub shorewall_config
{
if (exists $shorewall_config{$_[0]}  &&  defined $shorewall_config{$_[0]}) {
	return $shorewall_config{$_[0]};
	}
return '';
}

# return true if new zones format is in use
sub new_zones_format
{
# Shorewall 3.4.0 - 3.4.4 have a bug that prevents the old format from being used.
if (&version_atleast(3, 4)  &&  !&version_atleast(3, 4, 5)) {
	return 1;
	}
# Zones table is in new format in Shorewall 3, unless shorewall.conf has
# IPSECFILE=ipsec
if (!&version_atleast(3)  ||  &shorewall_config('IPSECFILE') eq 'ipsec') {
	return 0;
	}
return 1;
}

# read_table_file(table, &parserfunc)
# Read lines from a file and call the parser function on each one, and put the
# results into an array
sub read_table_file
{
my ($table, $func) = @_;
my @rv;
open(FILE, "<$config{'config_dir'}/$table");
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
my ($table, $func) = @_;
if (!defined($read_table_cache{$table})) {
	my @rv;
	open(FILE, "<$config{'config_dir'}/$table");
	my $lnum = 0;
	while(<FILE>) {
		s/\r|\n//g;
		local $cmt;
		if (s/#\s*(.*)$//) {
			$cmt = $1;
			}
		local $l = &$func($_);
		if ($l) {
			push(@rv, { 'line' => $lnum,
				    'file' => "$config{'config_dir'}/$table",
				    'table' => $table,
				    'index' => scalar(@rv),
				    'values' => $l,
				    'comment' => $cmt });
			}
		$lnum++;
		}
	close(FILE);
	$read_table_cache{$table} = \@rv;
	}
return $read_table_cache{$table};
}

# find_line_num(&lref, &parserfunc, index)
sub find_line_num
{
my ($lref, $func, $wantidx) = @_;
my $idx = 0;
for(my $i=0; $i<@$lref; $i++) {
	if (&$func($lref->[$i])) {
		if ($idx++ == $wantidx) {
			return $i;
			}
		}
	}
return undef;
}

# delete_table_row(table, &parserfunc, index)
# Delete the line for one row from a table
sub delete_table_row
{
my ($table, $func, $idx) = @_;
my $lref = &read_file_lines("$config{'config_dir'}/$table");
my $lnum = &find_line_num($lref, $func, $idx);
splice(@$lref, $lnum, 1) if (defined($lnum));
&flush_file_lines("$config{'config_dir'}/$table");
}

# delete_table_struct(&struct)
# Delete the line corresponding to some structure from a config file
sub delete_table_struct
{
my ($str) = @_;
my $lref = &read_file_lines($str->{'file'});
splice(@$lref, $str->{'line'}, 1);
&flush_file_lines($str->{'file'});
my $cache = $read_table_cache{$str->{'table'}};
my $idx = &indexof($str, @$cache);
if ($idx >= 0) {
	splice(@$cache, $idx, 1);
	}
foreach my $c (@$cache) {
	$c->{'line'}-- if ($c->{'line'} > $str->{'line'});
	$c->{'index'}-- if ($c->{'index'} > $str->{'index'});
	}
}

# create_table_row(table, &parserfunc, line, [insert-index])
# Add a row to a config table, at the end or before some index
sub create_table_row
{
my ($table, $pfunc, $line, $insert) = @_;
my $lref = &read_file_lines("$config{'config_dir'}/$table");
my $idx = -1;
for(my $i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^#+\s*LAST\s+LINE/) {
		$idx = $i;
		last;
		}
	elsif ($lref->[$i] =~ /^\??SECTION\s+NEW/) {
		$idx = $i+1;
		last;
		}
	elsif ($lref->[$i] =~ /^\??FORMAT\s+[1-2]/) {
		$idx = $i+1;
		last;
		}
	}
my $txt = &simplify_line($line);
if (defined($insert)) {
	my $lnum = &find_line_num($lref, $pfunc, $insert);
	$lnum = $idx if (!defined($lnum));
	if ($lnum < 0) {
		push(@$lref, $txt);
		}
	else {
		splice(@$lref, $lnum, 0, $txt);
		}
	}
else {
	if ($idx < 0) {
		push(@$lref, $txt);
		}
	else {
		splice(@$lref, $idx, 0, $txt);
		}
	}
&flush_file_lines("$config{'config_dir'}/$table");
}

# create_table_struct(&struct, parserfunc, [&insert-before])
# Convert a strucutre to lines to add to a config table
sub create_table_struct
{
my ($str, $pfunc, $before) = @_;
my $lref = &read_file_lines("$config{'config_dir'}/$str->{'table'}");
my $idx = -1;
for(my $i=0; $i<@$lref; $i++) {
	if ($lref->[$i] =~ /^#+\s*LAST\s+LINE/) {
		$idx = $i;
		last;
		}
	}
if ($idx < 0) {
	# Add at end
	$idx = scalar(@$lref);
	}
my $cache = &read_table_struct($str->{'table'}, $pfunc);
if ($_[2]) {
	# Insert into file
	splice(@$lref, $before->{'line'}, 0, &make_struct($str));
	$str->{'file'} = "$config{'config_dir'}/$str->{'table'}";
	$str->{'line'} = $before->{'line'};
	$str->{'index'} = $before->{'index'};
	foreach my $c (@$cache) {
		$str->{'line'}++ if ($c->{'line'} >= $before->{'line'});
		$str->{'index'}++ if ($c->{'index'} >= $before->{'index'});
		}
	my $iidx = &indexof($before, @$cache);
	splice(@$cache, $iidx, 0, $str);
	}
else {
	# Append to file
	splice(@$lref, $idx, 0, &make_struct($str));
	$str->{'file'} = "$config{'config_dir'}/$str->{'table'}";
	$str->{'line'} = $idx;
	$str->{'index'} = @$cache;
	push(@$cache, $str->{'index'});
	}
&flush_file_lines("$config{'config_dir'}/$str->{'table'}");
}

# modify_table_row(table, &parserfunc, index, line)
# Update one row in a config table
sub modify_table_row
{
my ($table, $pfunc, $idx, $line) = @_;
my $lref = &read_file_lines("$config{'config_dir'}/$table");
my $lnum = &find_line_num($lref, $pfunc, $idx);
$lref->[$lnum] = &simplify_line($line) if (defined($lnum));
&flush_file_lines("$config{'config_dir'}/$table");
}

# modify_table_struct(&newstruct, &oldstruct)
# Replace one structure in a table with another
sub modify_table_struct
{
my ($oldstr, $newstr) = @_;
my $lref = &read_file_lines("$config{'config_dir'}/$newstr->{'table'}");
$lref->[$newstr->{'line'}] = &make_struct($oldstr);
if ($oldstr ne $newstr) {
	$oldstr->{'line'} = $newstr->{'line'};
	$oldstr->{'index'} = $newstr->{'index'};
	my $cache = $read_table_cache{$newstr->{'table'}};
	my $idx = &indexof($newstr, @$cache);
	$cache->[$idx] = $oldstr;
	}
&flush_file_lines("$config{'config_dir'}/$newstr->{'table'}");
}

# swap_table_rows(table, &parserfunc, index1, index2)
# Swap two config lines in some table
sub swap_table_rows
{
my ($table, $pfunc, $idx1, $idx2) = @_;
my $lref = &read_file_lines("$config{'config_dir'}/$table");
my $lnum1 = &find_line_num($lref, $pfunc, $idx1);
my $lnum2 = &find_line_num($lref, $pfunc, $idx2);
($lref->[$lnum1], $lref->[$lnum2]) = ($lref->[$lnum2], $lref->[$lnum1]);
&flush_file_lines("$config{'config_dir'}/$table");
}

# make_struct(&struct)
# Convert a config structure into a line string
sub make_struct
{
my ($str) = @_;
my $line = join("\t", @{$_[0]->{'values'}});
if ($_[0]->{'comment'}) {
	$line .= "\t# $_[0]->{'comment'}";
	}
return &simplify_line($line);
}

# simplify_line(line)
# Removes blank fields from the end of a line
sub simplify_line
{
my ($rv) = @_;
while($rv =~ s/\s+$// || $rv =~ s/\-$//) { }
return $rv;
}

# lock_table(table)
# Lock the config file for some table
sub lock_table
{
my ($table) = @_;
&lock_file("$config{'config_dir'}/$table");
}

# unlock_table(table)
# Release the lock on the config file for some table
sub unlock_table
{
my ($table) = @_;
&unlock_file("$config{'config_dir'}/$table");
}

# standard_parser(line)
# Parser for whitespace-separated config files. Converts a line of text
# into an array ref of values.
sub standard_parser
{
my ($l) = @_;
$l =~ s/#.*$//;
my @sp = split(/\s+/, $l);
return undef if ($sp[0] =~ /\??SECTION/ || $sp[0] =~ /\??FORMAT/);
return @sp ? \@sp : undef;
}

# config_parser(line)
# Parser for shell-style config files. Converts a line of text
# into an array ref of values.
sub config_parser
{
my ($l) = @_;
$l =~ s/#\s*(.*?)\s*$//;		# save the comment we strip
my @sp = split(/=/, $l, 2);
if ($#sp > -1 && defined $1) {
	push @sp, $1;			# add back the saved comment, if present
	}
return @sp ? \@sp : undef;
}

# get_parser_func(&hashref)
# Determine which parser function to use
sub get_parser_func
{
my ($hashref) = @_;
&get_clean_table_name($hashref);
my $pfunc = $hashref->{'tableclean'}."_parser";
if (!defined(&$pfunc)) {
	if ($hashref->{'tableclean'} =~ /^(params|shorewall_conf)$/) {
		$pfunc = "config_parser";
		}
	else {
		$pfunc = "standard_parser";
		}
	}
return $pfunc;
}

# clean_name(string)
# ensure that the passed string contains only characters valid in shell variable identifiers
sub clean_name
{
my ($str) = @_;
$str =~ s/\W/_/g;
return $str;
}

# get_clean_table_name(table)
# get a table name that is clean enough to use as a function prefix
sub get_clean_table_name
{
my ($hashref) = @_;
if (!exists $hashref->{'tableclean'}) {
	$hashref->{'tableclean'} = &clean_name($in{'table'});
	}
}

# zone_field(name, value, othermode, simplemode)
# Returns the HTML for a zone selector field, and a flag indicating
# if the current value is a valid zone.
sub zone_field
{
my ($name, $value, $other, $simple) = @_;
my @ztable = &read_table_file("zones", \&zones_parser);
my $found = 0;
my @opts;
if ($simple == 2) {
	$found = !$value;
	}
elsif ($simple == 1) {
	push(@opts, [ '-', "&lt;$text{'list_any'}&gt;" ]);
	$found = !$value || $value eq '-';
	}
elsif ($simple == 0) {
	push(@opts, [ 'all', "&lt;$text{'list_any'}&gt;" ]);
	push(@opts, [ '$FW', "&lt;$text{'list_fw'}&gt;" ]);
	$value = '$FW' if (&is_fw($value));
	$found = !$value || $value eq 'all' || $value eq '$FW';
	}
foreach my $z (@ztable) {
	push(@opts, [ $z->[0], &convert_zone($z->[0]) ]);
	$found++ if ($value eq $z->[0]);
	}
if ($other) {
	push(@opts, [ '', $text{'list_other'} ]);
	}
elsif (!$found) {
	push(@opts, [ $value, $value ]);
	}
my $sel = &ui_select($name, $value, \@opts);
return wantarray ? ($sel, $found) : $sel;
}

# iface_field(name, value)
# Returns HTML for a network interface selector
sub iface_field
{
my ($name, $value) = @_;
my @itable = &read_table_file("interfaces", \&standard_parser);
my @opts = map { $_->[1] } @itable;
return &ui_select($name, $value, \@opts, 1, 0, $value ? 1 : 0);
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
my @hosts = split(/,/, $_[0]);
if (@host > 5) {
	return join(", ", @hosts[0..5]).", ...";
	}
else {
	return join(", ", @hosts);
	}
}

# is_fw(zone)
# - Checks if the supplied zone is the firewall zone.
#   Now handles renaming of firewall zone in shorewall.conf.
sub is_fw
{
my ($zone) = @_;
my $fw = &shorewall_config('FW');
$fw = 'fw' if ($fw eq '');
return $zone eq '$FW' || $zone eq $fw;
}

################################# zones #######################################

sub zones_parser
{
my ($l) = @_;
if (&new_zones_format()) {
	# New format
	$l =~ s/#\s*(.*?)\s*$//;	# save the stripped comment
	my $comment = $1 if defined $1;
	my @r = split(/\s+/, $l, 6);
	if ($#r > -1) {
		my $zone = shift(@r);

		# split out parent if it is present in the zone field
		my $parent;
		$zone =~ m/(.*?):(.*)/;
		if (defined $2) {
			$zone = $1;
			$parent = $2;
			}
		else {
			$parent = "";
			}
		unshift(@r, $zone, $parent);

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
if (&new_zones_format()) {
	return ( $text{'zones_0'}, $text{'zones_1new'}, $text{'zones_2new'},
		$text{'zones_6new'} );
	}
else {
	return ( $text{'zones_0'}, $text{'zones_1'}, $text{'zones_2'} );
	}
}

sub zones_form
{
if (&new_zones_format()) {
	# Shorewall 3 zones format
	print &ui_table_row($text{'zones_0'},
		&ui_textbox("id", $_[0], 8));

	my $zf = &zone_field("parent", $_[1], 0, 1);
	print &ui_table_row($text{'zones_1new'}, $zf);

	print &ui_table_row($text{'zones_2new'},
	    &ui_select("type", $_[2],
			[ [ "ipv4", $text{'zones_ipv4'} ],
			  [ "ipsec", $text{'zones_ipsec'} ],
			  [ "firewall", $text{'zones_firewall'} ] ]));

	print &ui_table_row($text{'zones_3new'},
		&ui_textbox("opts", $_[3], 50));

	print &ui_table_row($text{'zones_4new'},
		&ui_textbox("opts_in", $_[4], 50));

	print &ui_table_row($text{'zones_5new'},
		&ui_textbox("opts_out", $_[5], 50));

	print &ui_table_row($text{'zones_6new'},
		&ui_textbox("comment", $_[6], 50));

	}
else {
	# Shorewall 2 zones format
	print &ui_table_row($text{'zones_0'},
		&ui_textbox("id", $_[0], 8));

	print &ui_table_row($text{'zones_1'},
		&ui_textbox("name", $_[1], 15));

	print &ui_table_row($text{'zones_2'},
		&ui_textbox("desc", $_[2], 70));
	}
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

sub new_interfaces_format
{
if (&version_atleast(4, 5, 3)) {
	open(FILE, "<$config{'config_dir'}/interfaces");
	while(<FILE>) {
		s/\r|\n//g;
		if ($_ =~ /\??FORMAT\s+2/) {
			return 1;
			}
		}
	close(FILE);
	}
return 0;
}

sub interfaces_row
{
if (&new_interfaces_format()) {
	return ( $_[1],
		$_[0] eq '-' ? $text{'list_any'} : $_[0],
		$_[2] eq '-' || $_[2] eq '' ? $text{'list_none'} : $_[2] );
	}
else {
	return ( $_[1],
		$_[0] eq '-' ? $text{'list_any'} : $_[0],
		$_[2] eq 'detect' ? $text{'list_auto'} :
		 $_[2] eq '-' || $_[2] eq '' ? $text{'list_none'} : $_[2],
		$_[3] eq '-' || $_[3] eq '' ? $text{'list_none'} : $_[3] );
	}
}

@interfaces_opts = ( 'dhcp', 'multi', 'routefilter',
		     'maclist', 'tcpflags', 'proxyarp' );
if (!&version_atleast(5, 0, 4)) {
	push(@interfaces_opts, 'noping', 'filterping', 'routestopped',
		       'norfc1918', 'dropunclean', 'logunclean', 'blacklist');
	}
if (&version_atleast(3)) {
	push(@interfaces_opts, "logmartians", "routeback", "arp_filter",
			       "arp_ignore", "nosmurfs", "detectnets", "upnp");
	}

sub interfaces_form
{
print &ui_table_row($text{'interfaces_0'},
	&ui_textbox("iface", $_[1], 6));

my $zf = &zone_field("zone", $_[0], 0, 1);
print &ui_table_row($text{'interfaces_1'}, $zf);

if (&new_interfaces_format()) {
	print &ui_table_row($text{'interfaces_3'},
		&options_input("opts", $_[2], \@interfaces_opts));
	}
else {
	my $bmode = $_[2] eq 'detect' ? 2 :
		    $_[2] eq '-' || $_[2] eq '' ? 1 : 0;
	print &ui_table_row($text{'interfaces_2'},
	     &ui_radio("broad_mode", $bmode,
		  [ [ 1, $text{'list_none'} ],
		    [ 2, $text{'list_auto'} ],
		    [ 0, &ui_textbox("broad", $bmode == 0 ? $_[2] : "", 50) ] ]));

	print &ui_table_row($text{'interfaces_3'},
		&options_input("opts", $_[3], \@interfaces_opts));
	}
}

sub interfaces_validate
{
$in{'iface'} =~ /^[a-z]+\d*(s\d*)?(\.\d+)?$/ ||
	$in{'iface'} =~ /^[a-z]+\+$/ || &error($text{'interfaces_eiface'});
my @result = ( $in{'zone'}, $in{'iface'});
if (!&new_interfaces_format()) {
	$in{'broad_mode'} || $in{'broad'} =~ /^[0-9\.,]+$/ ||
		&error($text{'interfaces_ebroad'});
	push(@result, $in{'broad_mode'} == 2 ? 'detect' :
		$in{'broad_mode'} == 1 ? '-' : $in{'broad'});
	}
push(@result, join(",", split(/\0/, $in{'opts'})));
return @result;
}

sub interfaces_columns
{
return &new_interfaces_format() ? 3 : 4;
}

sub interfaces_colnames
{
my @result = ( $text{'interfaces_0'},
	       $text{'interfaces_1'} );
if (!&new_interfaces_format()) {
	push(@result, $text{'interfaces_2'});
	}
push(@result, $text{'interfaces_3'});
return @result;
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

@policy_list = ( "ACCEPT", "DROP", "REJECT", "CONTINUE" );

sub policy_form
{
my $zf = &zone_field("source", $_[0], 0);
print &ui_table_row($text{'policy_0'}, $zf);

$zf = &zone_field("dest", $_[1], 0);
print &ui_table_row($text{'policy_1'}, $zf);

print &ui_table_row($text{'policy_2'},
	&ui_select("policy", uc($_[2]), \@policy_list, 1, 0, 1));

&foreign_require("syslog");
print &ui_table_row($text{'policy_3'},
	&ui_select("log", $_[3] || '-',
		[ [ '-', "&lt;$text{'policy_nolog'}&gt;" ],
		  [ 'ULOG', "&lt;$text{'policy_ulog'}&gt;" ],
		  &syslog::list_priorities() ], 1, 0, 1));

my ($l, $b) = $_[4] =~ /(\d+):(\d+)/ ? ($1, $2) : ( );
print &ui_table_row($text{'policy_4'},
	&ui_opt_textbox("limit", $l, 5, $text{'list_none'})." ".
	&ui_textbox("burst", $b, 5));
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
	 &version_atleast(1, 4, 7) ? (
		$_[7] eq "-" ? "" : $_[7],
		$_[8] eq "-" ? "" : $_[8] ) :
		( )
	);
}

@rules_actions = ( 'ACCEPT', 'DROP', 'REJECT', 'DNAT', 'DNAT-', 'REDIRECT' );
if (&version_atleast(2, 0, 0)) {
	push(@rules_actions, 'CONTINUE');
	push(@rules_actions, 'ACCEPT+');
	push(@rules_actions, 'NONAT');
	push(@rules_actions, 'REDIRECT-');
	push(@rules_actions, 'LOG');
	}
if (&version_atleast(3)) {
	push(@rules_actions, 'DNAT-');
	push(@rules_actions, 'SAME');
	push(@rules_actions, 'SAME-');
	push(@rules_actions, 'QUEUE');
	}
@rules_protos = ( 'all', 'related', 'tcp', 'udp', 'icmp' );

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
my ($zf, $found) = &zone_field("source", $zone, 1);
print $zf;
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
($zf, $found) = &zone_field("dest", $zone, 1);
print $zf;
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
$in{'dnat_def'} || &check_ipaddress($in{'dnat'}) ||
	($in{'dnat'} =~ /^([0-9\.]+):([0-9\.]+)$/ &&
	 &check_ipaddress("$1") && &check_ipaddress("$2")) ||
	($in{'dnat'} =~ /^\!([0-9\.]+)$/ && &check_ipaddress("$1")) ||
	($in{'dnat'} =~ /^\!([0-9\.]+),([0-9\.]+)(\/\d+)?$/ &&
	 &check_ipaddress("$1") && &check_ipaddress("$2")) ||
	($in{'dnat'} =~ /^\!([0-9\.,]+)$/ &&
         scalar(grep { &check_ipaddress($_) } split(/,/, $1))) ||
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
@tos_protos = ( 'tcp', 'udp', 'icmp' );

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
my ($zone, $host) = split(/:/, $_[0], 2);
my ($zf, $found) = &zone_field("source", $zone, 1);
print &ui_table_row($text{'tos_0z'},
	$zf." ".
	&ui_textbox("sother", $found ? "" : $zone, 10)."<br>\n".
	"<b>$text{'rules_inzone'}</b>\n".
	&ui_checkbox("sinzone_def", 1, $text{'rules_addr'}, $host ? 1 : 0)." ".
	&ui_textbox("sinzone", join(" ", split(/,/, $host)), 50),
	3);

($zone, $host) = split(/:/, $_[1], 2);
($zf, $found) = &zone_field("dest", $zone, 1);
print &ui_table_row($text{'tos_1z'},
        $zf." ".
        &ui_textbox("dother", $found ? "" : $zone, 10)."<br>\n".
        "<b>$text{'rules_inzone'}</b>\n".
        &ui_checkbox("dinzone_def", 1, $text{'rules_addr'}, $host ? 1 : 0)." ".
	&ui_textbox("dinzone", join(" ", split(/,/, $host)), 50),
        3);

my @opts;
my $found = !$_[2];
foreach my $p (@tos_protos) {
	push(@opts, [ $p, uc($p) ]);
	$found++ if ($p eq $_[2]);
	}
push(@opts, [ '', $text{'list_other'} ]);
print &ui_table_row($text{'tos_2'},
	&ui_select("proto", $found ? $_[2] : '', \@opts)." ".
	&ui_textbox("pother", $found ? "" : $_[2], 5));

print &ui_table_row($text{'tos_3'},
	&ui_opt_textbox("sport",
			$_[3] eq '-' ? '' : join(" ", split(/,/, $_[3])),
			30, $text{'list_any'}, $text{'rules_ranges'}));

print &ui_table_row($text{'tos_4'},
	&ui_opt_textbox("dport",
			$_[4] eq '-' ? '' : join(" ", split(/,/, $_[4])),
			30, $text{'list_any'}, $text{'rules_ranges'}));

@opts = ( );
foreach my $t (sort { $a <=> $b } keys %tos_map) {
	push(@opts, [ $t, $tos_map{$t} ]);
	}
print &ui_table_row($text{'tos_5'},
	&ui_select("tos", $_[5], \@opts, 1, 0, $_[5] ? 1 : 0));

print &ui_table_row($text{'tos_6'},
	&ui_textbox("mark", $_[6] eq "-" ? "" : $_[6], 50));
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

################################# masq #########################################

sub masq_row
{
return ( $_[0] =~ /^(\S+):(\S+)$/ ? &text('masq_in', "$1", "$2") : $_[0],
	 $_[1] =~ /^[0-9\.\/]+$/ ? $_[1] :
	  $_[1] =~ /^([a-z]+\d*)\!(\S+)$/ ? &text('masq_ex', "$1", "$2") :
	  &text('masq_iface', $_[1]),
	 $_[2] eq "" ? "" : $_[2] );
}

sub masq_columns
{
return 3;
}

sub masq_form
{
my ($iface, $net) = split(/:/, $_[0], 2);
print &ui_table_row($text{'masq_0'},
	&iface_field("iface", $iface)." ".
	&ui_checkbox("net_def", 1, $text{'masq_net'}, $net ? 1 : 0)." ".
	&ui_textbox("net", $net, 20));

my ($mnet, $miface, $mode);
if ($_[1] =~ /^[0-9\.\/]+(,[0-9\.\/]+)*$/) {
	$mnet = $_[1];
	$mode = 0;
	}
elsif ($_[1] =~ /^([a-z]+\d*)\!(\S+)$/) {
	$miface = $1;
	$mnet = $2;
	$mode = 1;
	}
else {
	$miface = $_[1];
	$mode = 1;
	}
print &ui_table_row($text{'masq_1'},
	&ui_radio_table("mode", $mode,
		[ [ 0, $text{'masq_mode0'},
		    &ui_textbox("mnet", $mode == 0 ? $mnet : "", 60) ],
		  [ 1, $text{'masq_mode1'},
		    &iface_field("miface", $mode == 1 ? $miface : undef)." ".
		    &ui_checkbox("mnet_def", 1, $text{'masq_except'},
				 $mode == 1 && $mnet ? 1 : 0)." ".
		    &ui_textbox("mnete",
			$mode == 1 ? join(" ", split(/,/, $mnet)) : "", 20) ],
		], 3));

print &ui_table_row($text{'masq_2'},
	&ui_opt_textbox("snat", $_[2] eq '-' ? '' : $_[2],
			15, $text{'list_none'}));

if (&version_atleast(3)) {
	print &ui_table_row($text{'masq_3'},
	      &ui_radio("proto_def", $_[3] ? 0 : 1,
			[ [ 1, $text{'masq_any'} ],
			  [ 0, " " ] ])."\n".
	      &ui_select("proto", $_[3],
			 [ map { [ $_, uc($_) ] } &list_protocols() ],
			 1, 0, $_[3] ? 1 : 0),
	      3);

	print &ui_table_row($text{'masq_4'},
		&ui_opt_textbox("ports", $_[4], 40, $text{'masq_all'}), 3);

	print &ui_table_row($text{'masq_5'},
		&ui_opt_textbox("ipsec", $_[5], 40, $text{'default'}), 3);
	}
}

sub masq_validate
{
!$in{'net_def'} || $in{'net'} =~ /^\S+$/ || &error($text{'masq_enet'});
if ($in{'mode'} == 0) {
	$in{'mnet'} =~ /^\S+$/ || &error($text{'masq_emnet'});
	}
else {
	!$in{'mnet_def'} || $in{'mnete'} =~ /\S/ ||&error($text{'masq_emnete'});
	}
$in{'snat_def'} || &check_ipaddress($in{'snat'}) || &error($text{'masq_esnat'});

local @rv = ( $in{'iface'}.(!$in{'net_def'} ? "" : ":$in{'net'}"),
	 $in{'mode'} == 0 ? $in{'mnet'} :
	  $in{'miface'}.(!$in{'mnet_def'} ? "" :
			 "!".join(",", split(/\s+/, $in{'mnete'}))),
	 $in{'snat_def'} ? ( "" ) : ( $in{'snat'} ) );
if (&version_atleast(3)) {
	push(@rv, $in{'proto_def'} ? "" : $in{'proto'});
	if ($in{'ports_def'}) {
		push(@rv, "");
		}
	else {
		$in{'ports'} =~ /^\S+$/ || &error($text{'masq_eports'});
		push(@rv, $in{'ports'});
		}
	if ($in{'ipsec_def'}) {
		push(@rv, "");
		}
	else {
		$in{'ipsec'} =~ /^\S+$/ || &error($text{'masq_eipsec'});
		push(@rv, $in{'ipsec'});
		}
	}
return @rv;
}

################################# nat #########################################

sub nat_form
{
print &ui_table_row($text{'nat_0'},
	&ui_textbox("ext", $_[0], 15));

if (&version_atleast(1, 3, 14)) {
	my ($iface, $virt) = split(/:/, $_[1]);
	print &ui_table_row($text{'nat_1'},
		&iface_field("iface", $iface)." ".
		"<b>$text{'nat_virt'}</b>\n".
		&ui_textbox("virt", $virt, 3));
	}
else {
	print &ui_table_row($text{'nat_1'},
		&iface_field("iface", $_[1]));
	}

print &ui_table_row($text{'nat_2'},
	&ui_textbox("int", $_[2], 15));

my $all = $_[3] eq '-' || $_[3] eq '' || $_[3] =~ /yes/i ? 1 : 0;
print &ui_table_row($text{'nat_all'},
	&ui_yesno_radio("all", $all));

my $local = $_[4] =~ /yes/i ? 1 : 0;
print &ui_table_row($text{'nat_local'},
	&ui_yesno_radio("local", $local));
}

sub nat_validate
{
&check_ipaddress($in{'ext'}) || &error($text{'nat_eext'});
&check_ipaddress($in{'int'}) || &error($text{'nat_eint'});
$in{'virt'} =~ /^\d*$/ || &error($text{'nat_evirt'});
return ( $in{'ext'},
	 $in{'virt'} ne '' ? $in{'iface'}.":".$in{'virt'} : $in{'iface'},
	 $in{'int'},
	 $in{'all'} ? "yes" : "no",
	 $in{'local'} ? "yes" : "no" );
}

################################# proxyarp #######################################

sub proxyarp_row
{
return ( $_[0],
	 $_[1] eq '-' || $_[1] eq '' ? $text{'list_auto'} : $_[1],
	 $_[2],
	 &version_atleast(2, 0, 0) ?
		( $_[4] =~ /yes/i ? $text{'yes'} : $text{'no'} ) : ( ) );
}

sub proxyarp_form
{
print &ui_table_row($text{'proxyarp_0'},
	&ui_textbox("addr", $_[0], 15));

print &ui_table_row($text{'proxyarp_1'},
	&ui_radio("int_def", $_[1] eq '-' || $_[1] eq '' ? 1 : 0,
		  [ [ 1, $text{'list_auto'} ],
		    [ 0, &iface_field("int", $_[1] eq '-' ? undef : $_[1]) ]
		  ]));

print &ui_table_row($text{'proxyarp_have'},
	&ui_yesno_radio("have", $_[3] =~ /yes/i ? 1 : 0));

print &ui_table_row($text{'proxyarp_2'},
	&iface_field("ext", $_[2]));

if (&version_atleast(2, 0, 0)) {
	print &ui_table_row($text{'proxyarp_pers'},
		&ui_yesno_radio("pers", $_[4] =~ /yes/i ? 1 : 0));
	}
}

sub proxyarp_validate
{
&check_ipaddress($in{'addr'}) || &error($text{'proxyarp_eaddr'});
return ( $in{'addr'},
	 $in{'int_def'} ? "-" : $in{'int'},
	 $in{'ext'},
	 $in{'have'} ? "yes" : "no",
	 &version_atleast(2, 0, 0) ? ( $in{'pers'} ? "yes" : "no" ) : ( )
	);

}

sub proxyarp_columns
{
return &version_atleast(2, 0, 0) ? 4 : 3;
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

our @routestopped_options = ( "routeback", "source", "dest", "critical" );

sub routestopped_form
{
print &ui_table_row($text{'routestopped_0'},
	&iface_field("iface", $_[0]));

my $none = $_[1] eq '' || $_[1] eq '-' || $_[1] eq '0.0.0.0/0';
print &ui_table_row($text{'routestopped_1'},
	&ui_radio("addr_def", $none ? 1 : 0,
		  [ [ 1, $text{'routestopped_all'} ],
		    [ 0, $text{'routestopped_list'} ] ])."<br>\n".
	&ui_textarea("addr", $none ? "" : join("\n", split(/,/, $_[1])),
		     5, 20));

if (&version_atleast(3)) {
	print &ui_table_row($text{'routestopped_2'},
		&options_input("opts", $_[2], \@routestopped_options), 3);
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
$tt =~ s/^(openvpn|generic):.*$/$1/;
return ( $text{'tunnels_'.$tt} || $tt,
	 $_[1] eq '-' || $_[1] eq '' ? $text{'routestopped_all'} : $_[1],
	 $_[2], $_[3] );
}

sub tunnels_form
{
my $ttype = $_[0];
my $tport;
if ($ttype =~ s/^(openvpn|generic):(.*)$/$1/) {
	$tport = $2;
	}
my @opts;
foreach my $tt ('ipsec', 'ipsecnat',
	        (&version_atleast(2, 0, 0) ? ( 'ipsec:noah', 'ipsecnat:noah' )
				           : ( )),
	        'ip', 'gre', 'pptpclient', 'pptpserver', 'generic',
	        (&version_atleast(1, 3, 14) ? ( 'openvpn' ) : ( )) ) {
	push(@opts, [ $tt, $text{'tunnels_'.$tt.'_l'} ||
			   $text{'tunnels_'.$tt} ]);
	}
print &ui_table_row($text{'tunnels_0'},
	&ui_select("type", $ttype, \@opts, 1, 0, $ttype ? 1 : 0)." ".
	&ui_textbox("tport", $tport, 10));

my $zf = &zone_field("zone", $_[1], 0, 0);
print &ui_table_row($text{'tunnels_1'}, $zf);

print &ui_table_row($text{'tunnels_2'},
	&ui_opt_textbox("gateway", $_[2] eq '-' ? '' : $_[2], 20,
		$text{'default'}, $text{'tunnels_sel'}));

print &ui_table_row($text{'tunnels_3'},
	&ui_opt_textbox("gzones",
		$_[2] eq '-' || $_[2] eq '' ? '' : join(" ", split(/,/, $_[3])),
		20,
		$text{'default'}, $text{'tunnels_gsel'}));
}

sub tunnels_validate
{
$in{'gateway_def'} || &check_ipaddress($in{'gateway'}) ||
	($in{'gateway'} =~ /^(\S+)\/(\d+)$/ && &check_ipaddress($1)) ||
		&error($text{'tunnels_egateway'});
if ($in{'type'} eq "openvpn") {
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

our @host_options = ( "maclist", "routeback" );
if (&version_atleast(3)) {
	push(@host_options, "norfc1918", "blacklist", "tcpflags",
			    "nosmurfs", "ipsec");
	}

sub hosts_form
{
my $zf = &zone_field("zone", $_[0], 0, 2);
print &ui_table_row($text{'hosts_0'}, $zf);

my ($iface, $net) = split(/:/, $_[1]);
print &ui_table_row($text{'hosts_1'},
	&iface_field("iface", $iface));

print &ui_table_row($text{'hosts_2'},
	&ui_textbox("net", $net, 50));

print &ui_table_row($text{'hosts_opts'},
	&options_input("opts", $_[2], \@host_options));
}

sub hosts_validate
{
&check_ipaddress($in{'net'}) ||
	$in{'net'} =~ /^(\S+)\/(\d+)$/ && &check_ipaddress($1) ||
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

@blacklist_protos = ( undef, 'tcp', 'udp', 'icmp' );

sub blacklist_form
{
my ($mode, $ipset, $mac, $ip);
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
print &ui_table_row(
    $text{'blacklist_host'},
    &ui_radio("host_def", $mode,
        [ [ 0, &text('hosts_ip', &ui_textbox("host", $ip, 30))."<br>" ],
          [ 1, &text('hosts_mac', &ui_textbox("mac", $mac, 30))."<br>" ],
          [ 3, $text{'hosts_any'}."<br>" ],
          &version_atleast(3) ?
           ( [ 2, &text('hosts_ipset', &ui_textbox("ipset", $ipset, 15)) ] ) :
	   ( ),
	]), 3);

my $found = !$_[1];
my @opts;
foreach my $p (@blacklist_protos) {
	push(@opts, [ $p, $p eq '' ? "&lt;$text{'list_any'}&gt;" : uc($p) ]);
	$found++ if ($p eq $_[1]);
	}
push(@opts, [ '*', $text{'list_other'} ]);
print &ui_table_row($text{'blacklist_proto'},
	&ui_select("proto", $found ? $_[1] : "*", \@opts)." ".
	&ui_textbox("pother", $found ? "" : $_[1], 5));

print &ui_table_row($text{'blacklist_ports'},
	&ui_textbox("ports", $_[2], 20));
}

sub blacklist_validate
{
my $host;
if ($in{'host_def'} == 0) {
	&check_ipaddress($in{'host'}) ||
		$in{'host'} =~ /^(\S+)\/(\d+)$/ && &check_ipaddress($1) ||
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
my $proto;
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

our @providers_opts = ( "track", "balance", "loose" );

sub providers_form
{
print &ui_table_row($text{'providers_name'},
	&ui_textbox("name", $_[0], 20));

print &ui_table_row($text{'providers_number'},
	&ui_textbox("number", $_[1], 4));

print &ui_table_row($text{'providers_iface'},
	&iface_field("iface", $_[4]));

print &ui_table_row($text{'providers_mark'},
	&ui_textbox("mark", $_[2], 4));

print &ui_table_row($text{'providers_gateway'},
	&ui_textbox("gateway", $_[5], 15));

my $ddef = $_[3] eq "-" || $_[3] eq "" ? 0 : $_[3] eq "main" ? 1 : 2;
print &ui_table_row($text{'providers_dup'},
	&ui_radio("dup_def", $ddef,
		  [ [ 0, $text{'default'} ],
		    [ 1, $text{'providers_main'} ],
		    [ 2, &ui_textbox("dup", $ddef == 2 ? $_[3] : "", 5) ] ]));

my %opts = map { $_, 1 } split(/,/, $_[6]);
my $ofield = "";
foreach my $o (@providers_opts) {
	$ofield .= &ui_checkbox("opts", $o, $text{'providers_'.$o}, $opts{$o})."<br>\n";
	delete($opts{$o});
	}
foreach my $o (keys %opts) {
	$ofield .= &ui_hidden("opts", $o),"\n";
	}
print &ui_table_row($text{'providers_opts'}, $ofield);

print &ui_table_row($text{'providers_copy'},
	&ui_textbox("copy", $_[7], 15));
}

sub providers_validate
{
$in{'name'} =~ /^\S+$/ || &error($text{'providers_ename'});
$in{'number'} =~ /^\d+$/ || &error($text{'providers_enumber'});
$in{'mark'} =~ /^\d+$/ || &error($text{'providers_emark'});
$in{'dup_def'} < 2 || $in{'dup'} =~ /^\S+$/ || &error($text{'providers_edup'});
&check_ipaddress($in{'gateway'}) || &error($text{'providers_egateway'});
return ( $in{'name'}, $in{'number'}, $in{'mark'},
	 $in{'dup_def'} == 0 ? '-' : $in{'dup_def'} == 1 ? 'main' : $in{'dup'},
	 $in{'iface'}, $in{'gateway'},
	 join(",", split(/\0/, $in{'opts'})) || "-",
	 $in{'copy'} || "-" );
}

############################## route_rules ################################

sub route_rules_row
{
return ( $_[0] eq "-" ? $text{'list_any'} : $_[0],
	 $_[1] eq "-" ? $text{'list_any'} : $_[1],
	 $_[2], $_[3], $_[4] );
}

sub route_rules_form
{
print &ui_table_row($text{'route_rules_src'},
	&ui_opt_textbox("src", $_[0] eq "-" ? "" : $_[0],
			20, $text{'list_any'}, $text{'route_rules_ip'}));

print &ui_table_row($text{'route_rules_dst'},
	&ui_opt_textbox("dst", $_[1] eq "-" ? "" : $_[1],
			20, $text{'list_any'}, $text{'route_rules_ip'}));

my @ptable = &read_table_file("providers", \&standard_parser);
print &ui_table_row($text{'route_rules_prov'},
	&ui_select("prov", $_[2] eq "254" ? "main" : $_[2],
		   [ [ "main", $text{'route_rules_main'} ],
		     map { $_->[0] } @ptable ]));

print &ui_table_row($text{'route_rules_pri'},
	&ui_textbox("pri", $_[3], 10));

print &ui_table_row($text{'route_rules_mark'},
	&ui_opt_textbox("mark", $_[4] eq "-" ? $_[4] : "", 10,
		        $text{'route_rules_nomark'}));
}

sub route_rules_validate
{
$in{'src_def'} || $in{'src'} =~ /^\S+$/ || &error($text{'route_rules_esrc'});
$in{'dst_def'} || $in{'dst'} =~ /^\S+$/ || &error($text{'route_rules_edst'});
$in{'pri'} =~ /^\d+$/ || &error($text{'route_rules_epri'});
$in{'mark_def'} || $in{'mark'} =~ /^\d+(\/\d+)?$/ ||
	&error($text{'route_rules_emark'});
return ( $in{'src_def'} ? "-" : $in{'src'},
	 $in{'dst_def'} ? "-" : $in{'dst'},
	 $in{'prov'},
	 $in{'pri'},
         $in{'mark_def'} ? ( ) : ( $in{'mark'} ) );
}



################################ shorewall.conf ##################################

sub conf_form
{
my ($msg1, $msg2, $msg3, $field1, $field2, $field3, $dummy) = @_;

print &ui_table_row($msg1, &ui_textbox("var", $field1, 50));

print &ui_table_row($msg2, &ui_textbox("val", $field2, 50));

print &ui_table_row($msg3, &ui_textbox("comment", $field3, 50));
}

################################ shorewall.conf ##################################

sub shorewall_conf_columns
{
return 3;
}

sub shorewall_conf_form
{
&conf_form($text{'shorewall_conf_0'}, $text{'shorewall_conf_1'}, $text{'shorewall_conf_2'}, @_);
}

sub shorewall_conf_validate
{
&error($text{'shorewall_conf_varname'}) unless $in{'var'} =~ /^\w+$/;
my $comment = "";
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
my $comment = "";
$comment = "\t# ".$in{'comment'} if (exists $in{'comment'} and $in{'comment'} ne "");
return ($in{'var'}.'='.$in{'val'}.$comment);
}


#############################################################################

# can_access(file)
# Returns 1 if the ACL allows access to some file
sub can_access
{
if ($access{'files'} eq '*') {
	return 1;
	}
else {
	my @acc = split(/\s+/, $access{'files'});
	return &indexof($_[0], @acc) >= 0;
	}
}

# run_before_apply_command()
# Runs the before-applying command, if any. If it fails, returns the error
# message output
sub run_before_apply_command
{
if ($config{'before_apply_cmd'}) {
	my $out = &backquote_logged("($config{'before_apply_cmd'}) </dev/null 2>&1");
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

# run_before_refresh_command()
# Runs the before-refresh command, if any. If it fails, returns the error
# message output
sub run_before_refresh_command
{
if ($config{'before_refresh_cmd'}) {
	my $out = &backquote_logged("($config{'before_refresh_cmd'}) </dev/null 2>&1");
	return $out if ($?);
	}
return undef;
}

# run_after_refresh_command()
# Runs the after-refresh command, if any
sub run_after_refresh_command
{
if ($config{'after_refresh_cmd'}) {
	&system_logged("($config{'after_refresh_cmd'}) </dev/null >/dev/null 2>&1");
	}
}

# list_standard_actions()
# Returns a list of standard Shorewall actions
sub list_standard_actions
{
my @rv;
foreach my $a (split(/\t+/, $config{'actions'})) {
	open(ACTIONS, "<".$a);
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
my @rv;
foreach my $a ($config{'config_dir'}, $config{'macros'}) {
	opendir(DIR, $a);
	foreach my $f (readdir(DIR)) {
		push(@rv, $1) if ($f =~ /^macro\.(.*)$/);
		}
	closedir(DIR);
	}
return &unique(sort(@rv));
}

our $BETA_STR = "-Beta";
our $BETA_NUM = "\.0000\.";

# get_shorewall_version(nocache)
# Returns the current Shorewall version, possibly from a local cache
sub get_shorewall_version
{
my ($nocache) = @_;
my $version;
if (!$nocache && open(VERSION, "<$module_config_directory/version")) {
	chop($version = <VERSION>);
	close(VERSION);
	}
if (!$version) {
	# Convert beta string to version number.
	my $out = &backquote_command(
		"$config{'shorewall'} version 2>&1 </dev/null");
	$out =~ s/\r//g;
	$out =~ s/$BETA_STR/$BETA_NUM/i;
	if ($out =~ /(\n|^)([0-9\.]+)\n/) {
		$version = $2;
		}
	}
return $version;
}

# Convert version number back to string.
sub get_printable_version($)
{
my ($out) = @_;
$out =~ s/$BETA_NUM/$BETA_STR/i;
return $out;
}

# list_protocols()
# Returns a list of network protocols
sub list_protocols
{
my @stdprotos = ( 'tcp', 'udp', 'icmp' );
my @otherprotos;
open(PROTOS, "</etc/protocols");
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
# Returns a 4-wide grid of checkboxes
sub options_input
{
my ($name, $value, $opts) = @_;
my @grid;
my %opts = map { $_, 1 } split(/,/, $value);
foreach my $o (@$opts) {
	push(@grid, &ui_checkbox($name, $o,
			$text{'opts_'.$o} || $o, $opts{$o}));
	delete($opts{$o});
	}
my $rv = &ui_grid_table(\@grid, 4);
foreach my $o (keys %opts) {
	$rv .= &ui_hidden($name, $o);
	}
return $rv;
}

1;
