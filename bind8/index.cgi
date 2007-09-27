#!/usr/local/bin/perl
# index.cgi
# Display a list of domains and links to options

require './bind8-lib.pl';
&ReadParse();

$need_create = !-r &make_chroot($config{'named_conf'}) ||
	       $in{'create'};

# Check if bind is installed
if (!-x $config{'named_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("bind", "doc", "google"));
	print "<p>",&text('index_enamed', "<tt>$config{'named_path'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link("bind", $text{'index_bind'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check if BIND is the right version.. Only BIND 8/9 offers the -f option
# Is there a better way to do this?
if ($out = &check_bind_8()) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("bind", "doc", "google"));
	print "<p>",&text('index_eversion', "<tt>$config{'named_path'}</tt>",
			  "/dnsadmin/", "<tt>$config{'named_path'} -help</tt>",
			  "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Try to get the version number
$out = `$config{'named_path'} -v 2>&1`;
if ($out =~ /(bind|named)\s+([0-9\.]+)/i) {
	$bind_version = $2;
	}
&open_tempfile(VERSION, ">$module_config_directory/version");
&print_tempfile(VERSION, "$bind_version\n");
&close_tempfile(VERSION);

# Get the list of zones
@allzones = &list_zone_names();
@zones = grep { $_->{'type'} ne 'view' &&
		&can_edit_zone($_) &&
		(!$access{'ro'} || $_->{'name'} ne '.') } @allzones;
@views = grep { $_->{'type'} eq 'view' } @allzones;
($hashint) = grep { $_->{'type'} ne 'view' &&
		    $_->{'name'} eq '.' } @allzones;

if (@zones == 1 && $access{'zones'} ne '*' && !$access{'defaults'} &&
    !$access{'views'} && $access{'apply'} != 1 && !$access{'master'} &&
    !$access{'slave'} && !$access{'forward'} && $access{'noconfig'}) {
	# Only one zone, so go direct to it
	&redirect("edit_master.cgi?index=$zones[0]->{'index'}");
	exit;
	}

$chroot = &get_chroot();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("bind", "doc", "google"), undef, undef,
	&text($chroot eq "/" || !$chroot ? 'index_version' : 'index_chroot',
	      $bind_version, "<tt>$chroot</tt>"));

# If the named.conf file does not exist, offer to create it
if ($need_create) {
	print &text('index_eempty',
		    "<tt>".&make_chroot($config{'named_conf'})."</tt>"),"<p>\n";
	print "<form action=\"dns_boot.cgi\">\n";
	print "<input type=radio name=real value=0> $text{'index_local'}<p>\n";
	print "<input type=radio name=real value=1 checked> ",
	      "$text{'index_download'}<p>\n";
	print "<input type=radio name=real value=2> $text{'index_webmin'}<p>\n";
	print "<center><input type=submit value=\"$text{'index_create'}\">",
	      "</center></form>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

if ($access{'defaults'}) {
	# display global options
	print &ui_subheading($text{'index_opts'});
	@olinks = ("conf_servers.cgi", "conf_logging.cgi", "conf_acls.cgi",
		   "conf_files.cgi", "conf_forwarding.cgi", "conf_net.cgi",
		   "conf_misc.cgi", "conf_controls.cgi", "conf_keys.cgi",
		   "conf_zonedef.cgi", "list_slaves.cgi",
		   ($bind_version >= 9 ? ( "conf_rndc.cgi" ) : ( )),
		   "conf_manual.cgi" );
	@otitles = map { /(conf|list)_(\S+).cgi/; $text{$2."_title"} } @olinks;
	@oicons = map { /^(conf|list)_(\S+).cgi/; "images/$2.gif"; } @olinks;
	&icons_table(\@olinks, \@otitles, \@oicons, 6);
	print "<hr>\n";
	}

# Work out what creation links we have
@crlinks = ( );
if ($access{'master'} && !$access{'ro'}) {
	push(@crlinks,
	     "<a href=\"master_form.cgi\">$text{'index_addmaster'}</a>");
	}
if ($access{'slave'} && !$access{'ro'}) {
	push(@crlinks,
	     "<a href=\"slave_form.cgi\">$text{'index_addslave'}</a>");
	push(@crlinks,
	     "<a href=\"stub_form.cgi\">$text{'index_addstub'}</a>");
	}
if ($access{'forward'} && !$access{'ro'}) {
	push(@crlinks,
	     "<a href=\"forward_form.cgi\">$text{'index_addfwd'}</a>");
	}
if ($access{'delegation'} && !$access{'ro'} && &version_atleast(9, 2, 1)) {
	push(@crlinks,
	     "<a href=\"delegation_form.cgi\">$text{'index_adddele'}</a>");
	}
if ($access{'master'} && !$access{'ro'} &&
    $hashint < (@views ? scalar(@views) : 1)) {
	push(@crlinks,
	     "<a href=\"hint_form.cgi\">$text{'index_addhint'}</a>");
	}
if (@crlinks) {
	push(@crlinks,
	     "<a href=\"mass_form.cgi\">$text{'index_addmass'}</a>");
	}

if (@zones > $config{'max_zones'}) {
	# Too many zones, show search form
	print &ui_subheading($text{'index_zones'});
	print "<p>$text{'index_toomany'}<p>\n";
	print "<form action=find_zones.cgi>\n";
	print "<b>$text{'index_find'}</b>\n";
	print "<input name=search size=20>\n";
	print "<input type=submit value='$text{'index_search'}'></form>\n";
	print &ui_links_row(\@crlinks);
	}
elsif (@zones && (!@views || !$config{'by_view'})) {
	# Show all zones
	print &ui_subheading($text{'index_zones'});
	foreach $z (@zones) {
		$v = $z->{'name'};
		$t = $z->{'type'};
		next if (!$t);
		$t = "delegation" if ($t eq "delegation-only");
		local $zn = $v eq "." ? "<i>$text{'index_root'}</i>"
				      : &ip6int_to_net(&arpa_to_ip($v));
		if ($z->{'view'}) {
			local $vw = $z->{'viewindex'};
			push(@zlinks, "edit_$t.cgi?index=$z->{'index'}".
				      "&view=$vw");
			push(@ztitles, $zn." ".
			       &text('index_view', "<tt>$z->{'view'}</tt>"));
			push(@zdels, &can_edit_zone($z, $vw) ?
				$z->{'index'}." ".$z->{'view'} : undef);
			}
		else {
			push(@zlinks, "edit_$t.cgi?index=$z->{'index'}");
			push(@ztitles, $zn);
			push(@zdels, &can_edit_zone($z) ?
				$z->{'index'} : undef);
			}
		push(@zsort, $t eq 'hint' ? undef : $ztitles[$#ztitles]);
		push(@zicons, "images/$t.gif");
		push(@ztypes, $text{"index_$t"});
		$zhash{$zn} = $z;
		$ztitlehash{$zn} = $ztitles[$#ztitles];
		$zlinkhash{$zn} = $zlinks[$#zlinks];
		$ztypeshash{$zn} = $ztypes[$#ztypes];
		$zdelhash{$zn} = $zdels[$#ztypes];
		$len++;
		}

	# sort list of zones
	@zorder = sort { &compare_zones($zsort[$a], $zsort[$b]) } (0 .. $len-1);
	@zlinks = map { $zlinks[$_] } @zorder;
	@ztitles = map { $ztitles[$_] } @zorder;
	@zicons = map { $zicons[$_] } @zorder;
	@ztypes = map { $ztypes[$_] } @zorder;
	@zdels = map { $zdels[$_] } @zorder;

	print &ui_form_start("mass_delete.cgi", "post");
	@links = ( &select_all_link("d", 0),
		   &select_invert_link("d", 0),
		   @crlinks );
	print &ui_links_row(\@links);

	if ($config{'show_list'} == 1) {
		# display as list
		$mid = int((@zlinks+1)/2);
		print "<table width=100%><tr><td width=50% valign=top>\n";
		&zones_table([ @zlinks[0 .. $mid-1] ],
			     [ @ztitles[0 .. $mid-1] ],
			     [ @ztypes[0 .. $mid-1] ],
			     [ @zdels[0 .. $mid-1] ] );
		print "</td><td width=50% valign=top>\n";
		if ($mid < @zlinks) {
			&zones_table([ @zlinks[$mid .. $#zlinks] ],
				     [ @ztitles[$mid .. $#ztitles] ],
				     [ @ztypes[$mid .. $#ztypes] ],
				     [ @zdels[$mid .. $#zdels] ]);
			}
		print "</td></tr></table>\n";
		}
	elsif ($config{'show_list'} == 2) {
		# Show as collapsible tree, broken down by domain parts
		%heiropen = map { $_, 1 } &get_heiropen();
		$heiropen{""} = 1;
		foreach $z (grep { $_->{'type'} } @zones) {
			local $v = $z->{'name'};
			local @p = split(/\./, &ip6int_to_net(&arpa_to_ip($v)));
			for($i=1; $i<=@p; $i++) {
				local $ch = join(".", @p[$i-1 .. $#p]);
				local $par = $i == @p ?
					"" : join(".", @p[$i .. $#p]);
				@{$ztree{$par}} = &unique(@{$ztree{$par}}, $ch);
				}
			}
		print "<table>\n";
		&recursive_tree("");
		print "</table>\n";
		}
	else {
		# display as icons
		@befores = map { $_ ? &ui_checkbox("d", $_, "", 0) : "" }
			       @zdels;
		&icons_table(\@zlinks, \@ztitles, \@zicons, 5, undef, 
			     undef, undef, \@befores);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_massdelete'} ],
			     [ "update", $text{'index_massupdate'} ],
			     [ "create", $text{'index_masscreate'} ] ]);
	}
elsif (@zones) {
	# Show zones under views
	print &ui_subheading($text{'index_zones'});
	foreach $vw (@views) {
		local (@zorder, @zlinks, @ztitles, @zicons, @ztypes, @zsort, $len);
		local @zv = grep { $_->{'view'} eq $vw->{'name'} } @zones;
		next if (!@zv);
		print "<b>",&text('index_inview',
				  "<tt>$vw->{'name'}</tt>"),"</b><br>\n";
		foreach $z (@zv) {
			$v = $z->{'name'};
			$t = $z->{'type'};
			local $zn = $v eq "." ? "<i>$text{'index_root'}</i>"
					      : &ip6int_to_net(&arpa_to_ip($v));
			push(@zlinks, "edit_$t.cgi?index=$z->{'index'}".
				      "&view=$z->{'viewindex'}");
			push(@ztitles, $zn);
			push(@zsort, $t eq 'hint' ? undef : $ztitles[$#ztitles]);
			push(@zicons, "images/$t.gif");
			push(@ztypes, $text{"index_$t"});
			push(@zdels, $z->{'index'}." ".$z->{'viewindex'});
			$len++;
			}

		# sort list of zones
		@zorder = sort { &compare_zones($zsort[$a], $zsort[$b]) }
			       (0 .. $len-1);
		@zlinks = map { $zlinks[$_] } @zorder;
		@ztitles = map { $ztitles[$_] } @zorder;
		@zicons = map { $zicons[$_] } @zorder;
		@ztypes = map { $ztypes[$_] } @zorder;
		@zdels = map { $zdels[$_] } @zorder;

		print &ui_form_start("mass_delete.cgi", "post");
		print &ui_links_row(\@crlinks);
		if ($config{'show_list'}) {
			# display as list
			$mid = int((@zlinks+1)/2);
			print "<table width=100%><tr><td width=50% valign=top>\n";
			&zones_table([ @zlinks[0 .. $mid-1] ],
				     [ @ztitles[0 .. $mid-1] ],
				     [ @ztypes[0 .. $mid-1] ],
				     [ @zdels[0 .. $mid-1] ]);
			print "</td><td width=50% valign=top>\n";
			if ($mid < @zlinks) {
				&zones_table([ @zlinks[$mid .. $#zlinks] ],
					     [ @ztitles[$mid .. $#ztitles] ],
					     [ @ztypes[$mid .. $#ztypes] ],
					     [ @zdels[$mid .. $#zdels] ]);
				}
			print "</td></tr></table>\n";
			}
		else {
			# display as icons
			@befores = map { $_ ? &ui_checkbox("d", $_, "", 0) : "" }
				       @zdels;
			&icons_table(\@zlinks, \@ztitles, \@zicons, 5, undef,
				     undef, undef, \@befores);
			}
		print &ui_links_row(\@crlinks);
		print &ui_form_end([
			[ "delete", $text{'index_massdelete'} ],
			[ "update", $text{'index_massupdate'} ],
			[ "create", $text{'index_masscreate'} ] ]);
		}
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row(\@crlinks);
	}

if ($access{'views'} && $bind_version >= 9) {
	# Display list of views
	print "<hr>\n";
	print &ui_subheading($text{'index_views'});
	@views = grep { &can_edit_view($_) } @views;
	foreach $v (@views) {
		push(@vlinks, "edit_view.cgi?index=$v->{'index'}");
		push(@vtitles, $v->{'name'});
		push(@vicons, "images/view.gif");
		}
	@links = ( );
	push(@links, "<a href=\"view_form.cgi\">$text{'index_addview'}</a>")
		if (!$access{'ro'} && $access{'views'} != 2);
	if (@views) {
		print &ui_links_row(\@links);
		&icons_table(\@vlinks, \@vtitles, \@vicons, 5);
		}
	else {
		print "<b>$text{'index_vnone'}</b><p>\n";
		}
	print &ui_links_row(\@links);
	}

# read the PID
if (!$access{'ro'} && ($access{'apply'} == 1 || $access{'apply'} == 3)) {
	print "<hr>\n";
	print &ui_buttons_start();
	if (&is_bind_running()) {
		# named is running .. show restart and stop button
		if ($access{'remote'}) {
			@servers = &list_slave_servers();
			}
		print &ui_buttons_row("restart.cgi", $text{'index_apply'},
				      @servers ? $text{'index_applymsg2'}
					       : $text{'index_applymsg'});
		if ($access{'apply'} == 1) {
			print &ui_buttons_row("stop.cgi", $text{'index_stop'},
					      $text{'index_stopmsg'});
			}
		}
	elsif ($access{'apply'} == 1) {
		# named is not running .. show start button
		print &ui_buttons_row("start.cgi", $text{'index_start'},
				      $text{'index_startmsg'});
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{"index"});

sub dump_config
{
local($c);
foreach $c (@{$_[0]}) {
	print "$_[1]$c->{'name'} ",
		join(',', @{$c->{'values'}});
	if ($c->{'type'}) {
		print " {\n";
		&dump_config($c->{'members'}, "$_[1]\t");
		print "$_[1]}\n";
		}
	else { print "\n"; }
	}
}

sub compare_zones
{
local @sp0 = split(/\./, lc($_[0]));
local @sp1 = split(/\./, lc($_[1]));
for($i=0; $i<@sp0 || $i<@sp1; $i++) {
	if ($sp0[$i] =~ /^\d+$/ && $sp1[$i] =~ /^\d+$/) {
		return -1 if ($sp0[$i] < $sp1[$i]);
		return 1 if ($sp0[$i] > $sp1[$i]);
		}
	else {
		local $c = $sp0[$i] cmp $sp1[$i];
		return $c if ($c);
		}
	}
return 0;
}

sub recursive_tree
{
local ($name, $depth) = @_;
print "<tr> <td>", "&nbsp;&nbsp;" x $depth;
if ($_[0] ne "") {
	print "<a name=\"$name\"></a>\n";
	$name =~ /^([^\.]+)/;
	if (!$ztree{$name}) {
		# Has no children
		print "<img border=0 src=images/smallicon.gif>&nbsp; $1</td>\n",
		}
	else {
		# Has children
		local $act = $heiropen{$name} ? "close" : "open";
		print "<a href=\"$act.cgi?what=",&urlize($name),"\">";
		print "<img border=0 src=images/$act.gif></a>&nbsp; $1</td>\n",
		}
	}
else {
	# Is the root
	print "<img src=images/close.gif> <i>$text{'index_all'}</i></td>\n";
	}
if ($zhash{$name}) {
	local $cb = $zdelhash{$name} ?
		&ui_checkbox("d", $zdelhash{$name}, "", 0)." " : "";
	print "<td>$cb<a href='$zlinkhash{$name}'>$ztitlehash{$name} ($ztypeshash{$name})</a></td> </tr>\n";
	}
else {
	print "<td><br></td> </tr>\n";
	}
if ($heiropen{$name}) {
	foreach $sz (@{$ztree{$name}}) {
		&recursive_tree($sz, $depth+1);
		}
	}
}

