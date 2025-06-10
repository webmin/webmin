#!/usr/bin/perl
# $Id: index.cgi,v 1.6 2005/04/16 14:30:21 jfranken Exp $
# * List all subnets and shared networks
#
# File modified 2005-04-15 by Johannes Franken <jfranken@jfranken.de>:
# * Added support for DNS Zones (list, edit, create zone-directives)
# * Added a button to edit key-directives
# * Added a button to edit dhcp.conf in a text editor

require './dhcpd-lib.pl';
$display_max = $config{'display_max'} || 1000000000;
&ReadParse();
$horder = $in{'horder'};
$norder = $in{'norder'};
if ($horder eq "" && open(INDEX, "<$module_config_directory/hindex.".$remote_user)) {
	chop($horder = <INDEX>);
	close(INDEX);
	}
if (!$horder) {
	$horder = 0;
	}
if ($norder eq "" && open(INDEX, "<$module_config_directory/nindex.".$remote_user)) {
	chop($norder = <INDEX>);
	close(INDEX);
	}
if (!$norder) {
	$norder = 0;
	}
$nocols = $config{'dhcpd_nocols'} ? $config{'dhcpd_nocols'} : 5;
$conf = &get_config();
%access = &get_module_acl();

# Check if dhcpd is installed
if (!-x $config{'dhcpd_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("dhcpd", "man", "doc", "howto", "google"));
	print &text('index_dhcpdnotfound', $config{'dhcpd_path'},
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link("dhcpd", $text{'index_dhcpd'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# Check if it is the right version
@st = stat($config{'dhcpd_path'});
if ($st[7] != $config{'dhcpd_size'} || $st[9] != $config{'dhcpd_mtime'}) {
	# File has changed .. get the version
	local $ver = &get_dhcpd_version(\$out);
	if (!$ver) {
		&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
			&help_search_link("dhcpd", "man", "doc", "howto", "google"));
		print (&text('index_dhcpdver2',$config{'dhcpd_path'},
			     2, 3)),"<p>\n";
		print "<pre>$out</pre>\n";
		&ui_print_footer("/", $text{'index_return'});
		exit;
		}
	$config{'dhcpd_version'} = $ver;
	$config{'dhcpd_size'} = $st[7];
	$config{'dhcpd_mtime'} = $st[9];
	&write_file("$module_config_directory/config", \%config);
	}

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("dhcpd", "man", "doc", "howto", "google"),
	undef, undef, &text('index_version', $config{'dhcpd_version'}));

# Create lookup type HTML
# XXX change text, add to lookup_*
$matches = ui_select("match", $config{'match_default'} || 0,
		     [ [0, $text{'index_match0'} ],
                       [1, $text{'index_match1'} ],
                       [2, $text{'index_match2'} ] ]);

# get top-level hosts
foreach $h (&find("host", $conf)) {
	push(@host, $h);
	}
foreach $g (&find("group", $conf)) {
	push(@group, $g);
	foreach $h (&find("host", $g->{'members'})) {
		push(@host, $h);
		$group{$h} = $g->{'index'};
		$par{$h} = $g;
		push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
		}
	}

# get subnets and shared nets, and the hosts and groups within them
@subn = &find("subnet", $conf);
foreach $u (@subn) {
	$maxsubn = $maxsubn > $u->{'index'} ? $maxsubn : $u->{'index'};
	foreach $h (&find("host", $u->{'members'})) {
		$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
		$subnet{$h} = $u->{'index'};
		$par{$h} = $u;
		push(@host, $h);
		}
	foreach $g (&find("group", $u->{'members'})) {
		$maxgroup = $maxgroup > $g->{'index'} ? $maxgroup : $g->{'index'};
		$subnet{$g} = $u->{'index'};
		$par{$g} = $u;
		push(@group, $g);
		foreach $h (&find("host", $g->{'members'})) {
			$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
			$subnet{$h} = $u->{'index'};
			$group{$h} = $g->{'index'};
			$par{$h} = $g;
			push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
			push(@host, $h);
			}
		}
	}
@shan = &find("shared-network", $conf);
foreach $s (@shan) {
	$maxshar = $maxshar > $s->{'index'} ? $maxshar : $s->{'index'};
	foreach $h (&find("host", $s->{'members'})) {
		$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
		$shared{$h} = $s->{'index'};
		$par{$h} = $s;
		push(@host, $h);
		}
	foreach $g (&find("group", $s->{'members'})) {
		$maxgroup = $maxgroup > $g->{'index'} ? $maxgroup : $g->{'index'};
		$shared{$g} = $s->{'index'};
		$par{$g} = $s;
		push(@group, $g);
		foreach $h (&find("host", $g->{'members'})) {
			$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
			$group{$h} = $g->{'index'};
			$shared{$h} = $s->{'index'};
			$par{$h} = $g;
			push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
			push(@host, $h);
			}
		}
	foreach $u (&find("subnet", $s->{'members'})) {
		$maxsubn = $maxsubn > $u->{'index'} ? $maxsubn : $u->{'index'};
		$par{$u} = $s;
		push(@subn, $u);
		$shared{$u} = $s->{'index'};
		foreach $h (&find("host", $u->{'members'})) {
			$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
			$subnet{$h} = $u->{'index'};
			$shared{$h} = $s->{'index'};
			$par{$h} = $u;
			push(@host, $h);
			}
		foreach $g (&find("group", $u->{'members'})) {
			$maxgroup = $maxgroup > $g->{'index'} ? $maxgroup : $g->{'index'};
			$subnet{$g} = $u->{'index'};
			$shared{$g} = $s->{'index'};
			$par{$g} = $u;
			push(@group, $g);
			foreach $h (&find("host", $g->{'members'})) {
				$maxhost = $maxhost > $h->{'index'} ? $maxhost : $h->{'index'};
				$subnet{$h} = $u->{'index'};
				$group{$h} = $g->{'index'};
				$shared{$h} = $s->{'index'};
				$par{$h} = $g;
				push(@{$g->{'hosts'}}, $h->{'values'}->[0]);
				push(@host, $h);
				}
			}
		}
	}
foreach $s (@shan) {
	$s->{'order'} = (1 + $s->{'index'}) * (2 + $maxsubn);
	}
foreach $s (@subn) {
	$s->{'order'} = (defined($shared{$s}) ? (1 + $shared{$s}) * (2 + $maxsubn) : 0)
			+ 1 + $s->{'index'};
	}
if ($norder == 0) {
	@subn = (@subn, @shan);
	}
elsif ($norder == 1) {
	@subn = (@subn, @shan);
	@subn = sort { $a->{'order'} <=> $b->{'order'} } @subn;
	}
elsif ($norder == 2) {
	@subn = sort { $a->{'values'}->[0] <=> $b->{'values'}->[0] } @subn;
	@shan = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @shan;
	@subn = (@subn, @shan);
	}

# display subnets and shared nets
my @cansubn;
foreach $u (@subn) {
	local $can_view = &can('r', \%access, $u);
	next if !$can_view && $access{'hide'};
	local ($l, $t, $i);
	push(@cansubn, $u);
	if ($u->{'name'} eq "subnet") {
		push(@ulinks, $l = $can_view ? 
			"edit_subnet.cgi?idx=$u->{'index'}".
			($shared{$u} ne "" ? "&sidx=$shared{$u}" : "") :
			undef);
		push(@uicons, $i = "images/subnet.gif");
		push(@checkboxids, $u->{'index'}.
				   ($shared{$u} ne "" ? "/$shared{$u}" : ""));
		}
	else {
		push(@slinks, $l = $can_view ?
			"edit_shared.cgi?idx=$u->{'index'}" : undef);
		push(@sicons, $i = "images/shared.gif");
		push(@checkboxids, $u->{'index'});
		}
	if ($config{'desc_name'} == 0) {
		$t = $u->{'values'}->[0];
		}
	elsif ($config{'desc_name'} == 1) {
		$t = $u->{'comment'} || $u->{'values'}->[0];
		}
	else {
		$t = $u->{'values'}->[0].($u->{'comment'} ? " ($u->{'comment'})" : "");
		}
	push(@utitles, &html_escape($t));
	push(@uslinks, $l);	# so that ordering is preserved
	push(@ustitles, &html_escape($t));
	push(@usicons, $i);
	}
@checkboxes = map { &ui_checkbox("d", $_) } @checkboxids;
if ($access{'r_sub'} || $access{'c_sub'} ||
    $access{'r_sha'} || $access{'c_sha'}) {
	print &ui_subheading($text{'index_subtitle'});
	$sp = "";
	if (@ulinks < $display_max && @slinks < $display_max) {
		@links = @uslinks;
		@titles = @ustitles;
		@icons = @usicons;
		}
	elsif (@ulinks < $display_max) {
		@links = @ulinks;
		@titles = @utitles;
		@icons = @uicons;
		}
	elsif (@slinks < $display_max) {
		@links = @slinks;
		@titles = @stitles;
		@icons = @sicons;
		}
	if (@links) {
		# Show table of subnets and shared nets
		$show_subnet_delete = 1;
		print &ui_form_start("delete_subnets.cgi");
		&subnet_add_links();
		if ($config{'hostnet_list'} == 0) {
			&icons_table(\@links, \@titles, \@icons, $nocols,
				     undef, undef, undef, \@checkboxes);
			}
		else {
			&net_table(\@cansubn, 0, scalar(@cansubn), \@links,
				   \@titles, \@checkboxids);
			}
		}
	elsif (!@ulinks && !@slinks) {
		# No subnets or shared nets
		print "$text{'index_nosubdef'} <p>\n";
		}
	$show_subnet_shared = 1;
	}
&subnet_add_links();
if ($show_subnet_delete) {
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}

# Show too-many forms
if ($show_subnet_shared) {
	if (@ulinks >= $display_max) {
		# Could not show all subnets, so show lookup form
		print &ui_form_start("lookup_subnet.cgi", "get");
		print &ui_table_start(undef, undef, 2);
		print &ui_table_row($text{'index_subtoomany'}, &ui_submit($text{'index_sublook2'}));
		print &ui_table_row($matches, &ui_textbox("subnet", "", 30));
		    print &ui_table_end();
		print &ui_form_end(undef,undef,1);
		}
	if (@slinks >= $display_max) {
		# Could not show all shared nets, so show lookup form
		print &ui_form_start("lookup_shared.cgi", "get");
		print &ui_table_start(undef, undef, 2);
		print &ui_table_row($text{'index_shatoomany'}, &ui_submit($text{'index_shalook2'}));
		print &ui_table_row($matches, &ui_textbox("shared", "", 30));
		    print &ui_table_end();
		print &ui_form_end(undef,undef,1);
		}
	}

print &ui_hr();

foreach $g (@group) {
	$parent = (defined($subnet{$g}) ? 1 + $subnet{$g} : 0) +
		  (defined($shared{$g}) ? (1 + $shared{$g}) * (2 + $maxsubn) : 0);
	$g->{'order'} = $parent + (1 + $g->{'index'}) / (2 + $maxgroup);
	}
foreach $h (@host) {
	$parent = (defined($group{$h}) ? (1 + $group{$h}) / (2 + $maxgroup) : 0) +
		  (defined($subnet{$h}) ? 1 + $subnet{$h} : 0) +
		  (defined($shared{$h}) ? (1 + $shared{$h}) * (2 + $maxsubn) : 0);
	$h->{'order'} = $parent + (1 + $h->{'index'}) /
			((1 + @group) * (2 + $maxhost));
	}
if ($horder == 0) {
	@host = (@host, @group);
	}
elsif ($horder == 1) {
	@host = (@host, @group);
	@host = sort { $a->{'line'} <=> $b->{'line'} } @host;
	}
elsif ($horder == 2) {
	@host = sort { $a->{'values'}->[0] cmp $b->{'values'}->[0] } @host;
	@host = (@host, @group);
	}
elsif ($horder == 3) {
	@host = sort { &hardware($a) cmp &hardware($b) } @host;
	@host = (@host, @group);
	}
elsif ($horder == 4) {
	@host = sort { &ipaddress($a) cmp &ipaddress($b) } @host;
	@host = (@host, @group);
	}

# display hosts
my @canhost;
foreach $h (@host) {
	local $can_view = &can('r', \%access, $h);
	next if !$can_view && $access{'hide'};
	push(@canhost, $h);
	if ($h->{'name'} eq 'host') {
		# Add icon for a host
		push(@hlinks, $l = $can_view ?
			"edit_host.cgi?idx=$h->{'index'}".
			(defined($group{$h}) ? "&gidx=$group{$h}" : "").
			(defined($subnet{$h}) ? "&uidx=$subnet{$h}" : "").
			(defined($shared{$h}) ? "&sidx=$shared{$h}" : "") :
			undef);
		if ($config{'desc_name'} == 0) {
			$t = $h->{'values'}->[0];
			}
		elsif ($config{'desc_name'} == 1) {
			$t = $h->{'comment'} || $h->{'values'}->[0];
			}
		else {
			$t = $h->{'values'}->[0].($h->{'comment'} ? " ($h->{'comment'})" : "");
			}
		push(@htitles, &html_escape($t));
		if ($config{'show_ip'}) {
			$fv = &fixedaddr($h);
			$htitles[$#htitles] .= "<br>".$fv if ($fv);
			}
		if ($config{'show_mac'}) {
			local $hard = &find("hardware", $h->{'members'});
			$htitles[$#htitles] .= "<br>$hard->{'values'}->[1]"
				if ($hard);
			}
		$t = $htitles[$#htitles];
		push(@hicons, $i = "images/host.gif");
		push(@hgcheckboxids, join("/", $h->{'index'}, $group{$h},
					       $subnet{$h}, $shared{$h}));
		}
	else {
		# Add icon for a group
		push(@glinks, $l = $can_view ?
			"edit_group.cgi?idx=$h->{'index'}".
			(defined($subnet{$h}) ? "&uidx=$subnet{$h}" : "").
			(defined($shared{$h}) ? "&sidx=$shared{$h}" : "") :
			undef);
		$gm = @{$h->{'hosts'}};
		push(@gtitles, $t = &html_escape(&group_name($gm, $h)));
		push(@gicons, $i = "images/group.gif");
		push(@hgcheckboxids, join("/", $h->{'index'}, $subnet{$h},
					       $shared{$h}));
		}
	push(@hglinks, $l);
	push(@hgtitles, $t);
	push(@hgicons, $i);
	}
@hgcheckboxes = map { &ui_checkbox("d", $_) } @hgcheckboxids;
if ($access{'r_hst'} || $access{'c_hst'} ||
    $access{'r_grp'} || $access{'c_grp'}) {
	print &ui_subheading($text{'index_hst'});
	$sp = "";
	if (@hlinks < $display_max && @glinks < $display_max) {
		@links = @hglinks;
		@titles = @hgtitles;
		@icons = @hgicons;
		}
	elsif (@hlinks < $display_max) {
		@links = @hlinks;
		@titles = @htitles;
		@icons = @hicons;
		}
	elsif (@glinks < $display_max) {
		@links = @glinks;
		@titles = @gtitles;
		@icons = @gicons;
		}
	if (@links) {
		# Some hosts or groups to show
		&index_links($horder, "h", 5, $text{'index_hdisplay'},
			"norder=$norder");
		$show_host_delete = 1;
		print &ui_form_start("delete_hosts.cgi");
		&host_add_links();
		if ($config{'hostnet_list'} == 0) {
			&icons_table(\@links, \@titles, \@icons, $nocols,
				     undef, undef, undef, \@hgcheckboxes);
			}
		else {
			&host_table(\@canhost, 0, scalar(@canhost), \@links,
				    \@titles, \@hgcheckboxids);
			}
		}
	elsif (!@hlinks && !@glinks) {
		# None to show at all
		print "$text{'index_nohst'} <p>\n";
		}
	$show_host_group = 1;
	}
&host_add_links();
if ($show_host_delete) {
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}

# Show too-many forms
if ($show_host_group) {
	if (@hlinks >= $display_max) {
		# Could not show all hosts, so show lookup form
        print &ui_form_start("lookup_host.cgi", "get");
	    print &ui_table_start(undef, undef, 2);
        print &ui_table_row($text{'index_hsttoomany'}, &ui_submit($text{'index_hstlook2'}));
        print &ui_table_row($matches, &ui_textbox("host", "", 30));
	    print &ui_table_end();
        print &ui_form_end(undef,undef,1);
		}
	if (@glinks >= $display_max) {
		# Could not show all groups, so show lookup form
        print &ui_form_start("lookup_group.cgi", "get");
	    print &ui_table_start(undef, undef, 2);
        print &ui_table_row($text{'index_grptoomany'}, &ui_submit($text{'index_grplook2'}));
        print &ui_table_row($matches, &ui_textbox("group", "", 30));
	    print &ui_table_end();
        print &ui_form_end(undef,undef,1);
		}
	}

print &ui_hr();

############ START ZONES #####

if ($config{'dhcpd_version'} >= 3 && $access{'zones'}) {
	print &ui_subheading($text{'zone_key'});

	# get zones
	@zones = &find("zone", $conf);
	@zones = sort { $a->{'values'}->[0] <=> $b->{'values'}->[0] } @zones;
	if (@zones) {
		# display zones
        print &ui_link("edit_zones.cgi?new=1",$text{'index_addzone'})."&nbsp;&nbsp;\n" if $access{'c_sub'};
		foreach $z (@zones) {
			# print "ZONE: $z->{'value'} <br>";
			push(@zlinks, "edit_zones.cgi?idx=$z->{'index'}");
			push(@zicons, "images/files.gif");
			push(@ztitles, &html_escape($z->{'values'}->[0]));
			}
		if ($config{'hostnet_list'} == 0) {
			# user wants icons
			&icons_table(\@zlinks, \@ztitles, \@zicons, $nocols);
			}
		else {
			# user wants text
			&zone_table(\@zones, 0, scalar(@zones), \@zlinks, \@ztitles);
			}
		}
	else {
		print "<b>$text{'index_nozones'}</b><p>\n";
		}
    print &ui_link("edit_zones.cgi?new=1",$text{'index_addzone'})."&nbsp;&nbsp;\n" if $access{'c_sub'};
	print &ui_hr();

}

# Buttons for global actions
print &ui_buttons_start();

if ($access{'global'}) {
	# Edit global client options
	print &ui_buttons_row("edit_options.cgi",
		$text{'index_buttego'}, $text{'index_ego'},
		&ui_hidden("global", 1));
	}

if ($config{'dhcpd_version'} >= 3 && $access{'global'}) {
	# TSIG keys
	print &ui_buttons_row("edit_keys.cgi",
		$text{'index_buttekey'}, $text{'index_key'});
	}
if (!$access{'noconfig'}) {
	# Manually edit config file
	print &ui_buttons_row("edit_text.cgi",
		$text{'index_buttetext'}, $text{'index_text'});
	}
if (!$access{'noconfig'}) {
	# Select network interfaces
	print &ui_buttons_row("edit_iface.cgi",
		$text{'index_buttiface'}, $text{'index_iface'});
	}
if ($access{'r_leases'}) {
	# Show active leases
	print &ui_buttons_row("list_leases.cgi",
		$text{'index_buttlal'}, $text{'index_lal'});
	}
if ($access{'apply'}) {
	$pid = &is_dhcpd_running();
	if ($pid) {
		# Apply and stop buttons
		print &ui_buttons_row("restart.cgi",
			$text{'index_buttapply'}, $text{'index_apply'},
			&ui_hidden("pid", $pid));
		print &ui_buttons_row("stop.cgi",
			$text{'index_stop'}, $text{'index_stopdesc'},
			&ui_hidden("pid", $pid));
		}
	else {
		# Start button
		print &ui_buttons_row("start.cgi",
			$text{'index_buttstart'}, $text{'index_start'});
		}
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{'index_return'});

# Returns canonized hardware address.
sub hardware {
	local ($hconf, $addr);
	$hconf = $_[0]->{'members'} ? &find("hardware", $_[0]->{'members'}) : undef;
	if ($hconf) {
		$addr = uc($hconf->{'values'}->[1]);
		$addr =~ s/(^|\:)([0-9A-F])(?=$|\:)/$1\x30$2/g;
	}
	return $hconf ? $addr : undef;
}

# Returns ip address for sorting on
sub ipaddress
{
return undef if (!$_[0]->{'members'});
local $iconf = &find("fixed-address", $_[0]->{'members'});
return undef if (!$iconf);
return sprintf "%3.3d.%3.3d.%3.3d.%3.3d",
		split(/\./, $iconf->{'values'}->[0]);
}

sub fixedaddr {
	local ($fixed, $addr);
	$fixed = &find("fixed-address", $_[0]->{'members'});
	if ($fixed) {
		$addr = join(" ", grep { $_ ne "," } @{$fixed->{'values'}});
		return $addr;
	} else {
		return undef;
	}
}

sub netmask {
	return $_[0]->{'values'}->[2];
}

# index_links(current, name, max, txt, ref)
sub index_links
{
local (%linkname, $l);
local @links;
for (my $l = 0; $l < $_[2]; $l++) {
	my $msg = $text{"index_$_[1]order$l"};
	if ($l eq $_[0]) {
		push(@links, $msg);
		}
	else {
		push(@links, &ui_link("?$_[1]order=$l\&$_[4]",$msg) );
		}
	}
print "<b>$_[3]</b> ",&ui_links_row(\@links),"\n";
open(INDEX, "> $module_config_directory/$_[1]index.".$remote_user);
print INDEX "$_[0]\n";
close(INDEX);
}

sub host_table
{
local ($i, $h, $parent);
local @tds = ( "width=5" );
my $hascmt;
for ($i = $_[1]; $i < $_[2]; $i++) {
	$hascmt++ if ($_[4]->[$i] =~ /\(.*\)/);
	}
print &ui_columns_start([ "",
			  $text{'index_hostgroup'},
			  $hascmt ? ( $text{'index_comment'} ) : ( ),
			  $text{'index_parent'}, $text{'index_hardware'},
			  $text{'index_nameip'} ], 100, 0, \@tds);
for ($i = $_[1]; $i < $_[2]; $i++) {
	local @cols;
	local $firstcol;
	$parent = "";
	$par_type = "";
	$h = $_[0]->[$i];
	if ($h->{'name'} eq 'host') {
		$firstcol .= $sp;
		}
	else {
		$firstcol .= $text{'index_group'}." ";
		$sp = "\&nbsp;\&nbsp;";
		}
	my $cmt;
	if ($_[4]->[$i] =~ s/\s+\((.*)\)//) {
		$cmt = $1;
		}
	if ($_[3]->[$i]) {
		$firstcol .= &ui_link($_[3]->[$i], $_[4]->[$i]);
		}
	else {
		$firstcol .= $_[4]->[$i];
		}
	push(@cols, $firstcol);
	push(@cols, $cmt) if ($hascmt);

	if ($par{$h}->{'name'} eq "group") {		
	    $par_type = $text{'index_togroup'};
	    $parent = &group_name(scalar @{$par{$h}->{'hosts'}});
	} elsif ($par{$h}->{'name'} eq "subnet") {
	    $par_type = $text{'index_tosubnet'};
	    $parent = $par{$h}->{'values'}->[0];
	} elsif ($par{$h}->{'name'} eq "shared-network") {
	    $par_type = $text{'index_toshared'};
	    $parent = $par{$h}->{'values'}->[0];
	}

	if ($config{'desc_name'} && $par{$h}->{'comment'}) {
	    $parent = $par{$h}->{'comment'};
	}
	push(@cols, "$par_type  $parent");
	push(@cols, $_[3]->[$i] ? &hardware($h) : "");
	push(@cols, $_[3]->[$i] ? &fixedaddr($h) : "");
	print &ui_checked_columns_row(\@cols, \@tds, "d", $_[5]->[$i]);
	}
print &ui_columns_end();
}

#&net_table(\@subn, 0, scalar(@subn), \@links, \@titles, \@checkboxids);
sub net_table
{
local ($i, $n);
local @tds = ( "width=5" );
my $hascmt;
for ($i = $_[1]; $i < $_[2]; $i++) {
	$hascmt++ if ($_[4]->[$i] =~ /\(.*\)/);
	}
print &ui_columns_start([ "",
			  $text{'index_net'},
			  $hascmt ? ( $text{'index_comment'} ) : ( ),
			  $text{'index_netmask'},
			  $text{'index_desc'}, $text{'index_parent'} ], 100,
			0, \@tds);
for ($i = $_[1]; $i < $_[2]; $i++) {
	local @cols;
	$n = $_[0]->[$i];
	local $first;
	if ($n->{'name'} eq 'subnet') {
		$first = $sp;
		}
	else {
		$sp = "\&nbsp;\&nbsp;";
		}
	my $cmt;
	if ($_[4]->[$i] =~ s/\s+\((.*)\)//) {
		$cmt = $1;
		}
	if ($_[3]->[$i]) {
		$first .= &ui_link($_[3]->[$i],$_[4]->[$i]);
		}
	else {
		$first .= $_[4]->[$i];
		}
	push(@cols, $first);
	push(@cols, $cmt) if ($hascmt);
	push(@cols, $_[3]->[$i] ? &netmask($n) : "");
	push(@cols, $n->{'comment'});
	push(@cols, $par{$n} ? 
		"$text{'index_toshared'} $par{$n}->{'values'}->[0]" : "");
	print &ui_checked_columns_row(\@cols, \@tds, "d", $_[5]->[$i]);
	}
print &ui_columns_end();
}


#&zone_table(\@zones, 0, scalar(@zones), \@zlinks, \@ztitles);
sub zone_table
{
my $i;
print &ui_table_start($text{'index_zone'}, "width=95%", 2);
for ($i = $_[1]; $i < $_[2]; $i++) {
    print &ui_table_row(undef, &ui_link($_[3]->[$i],$_[4]->[$i]) );
	}
print &ui_table_end();
}

sub subnet_add_links
{
local @links;
if ($show_subnet_delete) {
	push(@links, &select_all_link("d"),
		     &select_invert_link("d"));
	}
push(@links, &ui_link("edit_subnet.cgi?new=1",$text{'index_addsub'}) )
	if $access{'c_sub'};
push(@links, &ui_link("edit_shared.cgi?new=1",$text{'index_addnet'}) )
	if $access{'c_sha'};
print &ui_links_row(\@links);
}

sub host_add_links
{
local @links;
if ($show_host_delete) {
	push(@links, &select_all_link("d", 1),
		     &select_invert_link("d", 1));
	}
push(@links, &ui_link("edit_host.cgi?new=1",$text{'index_addhst'}) )
	if $access{'c_hst'};
push(@links, &ui_link("edit_group.cgi?new=1",$text{'index_addhstg'}) )
	if $access{'c_grp'};
print &ui_links_row(\@links);
}

