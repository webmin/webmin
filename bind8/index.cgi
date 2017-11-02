#!/usr/local/bin/perl
# Display a list of domains, views, and icons for global options.
use strict;
use warnings;
our (%access, %text, %config, %gconfig, %in);
our ($module_name, $module_config_directory);

require './bind8-lib.pl';
&ReadParse();

my $need_create = !-r &make_chroot($config{'named_conf'}) ||
	       $in{'create'};

# XXX Globals used across subroutine boundaries.
my (%ztree, %zhash, %ztypeshash, %zstatushash, %ztitlehash, %zdelhash, %zlinkhash);

# Check if bind is installed
if (!-x $config{'named_path'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("bind", "doc", "google"));
	print "<p>",&text('index_enamed', "<tt>$config{'named_path'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	my $lnk = &software::missing_install_link("bind", $text{'index_bind'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check if BIND is the right version.. Only BIND 8/9 offers the -f option
# Is there a better way to do this?
if (my $out = &check_bind_8()) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("bind", "doc", "google"));
	print "<p>",&text('index_eversion', "<tt>$config{'named_path'}</tt>",
			  "/dnsadmin/", "<tt>$config{'named_path'} -help</tt>",
			  "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Try to get the version number, and save for later calls
my $bind_version = &get_bind_version();
if ($bind_version && $bind_version =~ /^(\d+\.\d+)\./) {
	# Convert to properly formatted number
	$bind_version = $1;
	}
my $VERSION;
&open_tempfile($VERSION, ">$module_config_directory/version");
&print_tempfile($VERSION, "$bind_version\n");
&close_tempfile($VERSION);

# Get the list of zones
my @allzones = &list_zone_names();
my @zones = grep { $_->{'type'} ne 'view' &&
		&can_edit_zone($_) &&
		(!$access{'ro'} || $_->{'name'} ne '.') } @allzones;
my @views = grep { $_->{'type'} eq 'view' } @allzones;
my @hashint = grep { $_->{'type'} ne 'view' &&
		  $_->{'name'} eq '.' } @allzones;

if (@zones == 1 && $access{'zones'} ne '*' && !$access{'defaults'} &&
    !$access{'views'} && $access{'apply'} != 1 && !$access{'master'} &&
    !$access{'slave'} && !$access{'forward'} && $access{'noconfig'}) {
	# Only one zone, so go direct to it
	my $z = $zones[0];
	&redirect("edit_master.cgi?zone=$z->{'name'}".
		  ($z->{'viewindex'} eq '' ? '' : '&view='.$z->{'viewindex'}));
	exit;
	}

my $chroot = &get_chroot();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&restart_links().'<br>'.
	&help_search_link("bind", "doc", "google"), undef, undef,
	&text($chroot eq "/" || !$chroot ? 'index_version' : 'index_chroot',
	      $bind_version, "<tt>$chroot</tt>"));

# If the named.conf file does not exist, offer to create it
if ($need_create) {
	print &text('index_eempty',
		    "<tt>".&make_chroot($config{'named_conf'})."</tt>"),"<p>\n";

	print &ui_form_start("dns_boot.cgi");
	print &ui_radio("real", 1,
		[ [ 0, $text{'index_local'}."<br>" ],
		  [ 1, $text{'index_download'}."<br>" ],
		  [ 2, $text{'index_webmin'}."<br>" ] ]);
	print &ui_form_end([ [ undef, $text{'index_create'} ] ]);

	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check for possibly invalid chroot, which shows up as missing zone files
if (@zones && $access{'zones'} eq '*' && !$access{'ro'}) {
	my @missing;
	foreach my $z (@zones) {
                my $zonefile = &make_chroot(&absolute_path($z->{'file'}));
                if ($z->{'type'} eq 'master' && $z->{'file'} && !-r $zonefile) {
			push(@missing, $z);
			}
		}
	if (scalar(@missing) >= scalar(@zones)/2) {
		if ($chroot && $chroot ne '/') {
			print "<p><b>",&text('index_ewrongchroot',
			    scalar(@missing), "<tt>$chroot</tt>"),"</b><p>\n";
			}
		else {
			print "<p><b>",&text('index_emissingchroot',
					  scalar(@missing)),"</b><p>\n";
			}
		print "<b>",&text('index_checkconfig',
				  "../config.cgi?$module_name"),"</b><p>\n";
		}
	}

# Check for obsolete DNSSEC config
if ($access{'defaults'}) {
	my $err = &check_dnssec_client();
	print "<center>".$err."</center>" if ($err);
	}

if ($access{'defaults'}) {
	# display global options
	print &ui_subheading($text{'index_opts'});
	my @olinks = ("conf_servers.cgi", "conf_logging.cgi", "conf_acls.cgi",
		   "conf_files.cgi", "conf_forwarding.cgi", "conf_net.cgi",
		   "conf_misc.cgi", "conf_controls.cgi", "conf_keys.cgi",
		   "conf_zonedef.cgi", "list_slaves.cgi",
		   $bind_version >= 9 ? ( "conf_rndc.cgi" ) : ( ),
		   &supports_dnssec_client() ? ( "conf_trusted.cgi" ) : ( ),
				   ((&supports_dnssec()) && (&have_dnssec_tools_support())) ? ( "conf_dnssectools.cgi" ) : ( ),
		   &supports_dnssec() ? ( "conf_dnssec.cgi" ) : ( ),
		   &supports_check_conf() ? ( "conf_ncheck.cgi" ) : ( ),
		   "conf_manual.cgi" );
	my @otitles = map { /(conf|list)_(\S+).cgi/; $text{$2."_title"} } @olinks;
	my @oicons = map { /^(conf|list)_(\S+).cgi/; "images/$2.gif"; } @olinks;
	&icons_table(\@olinks, \@otitles, \@oicons, 6);
	print &ui_hr();
	}

# Work out what creation links we have
my @crlinks = ( );
if ($access{'master'} && !$access{'ro'}) {
	push(@crlinks, &ui_link("master_form.cgi", $text{'index_addmaster'}) );
	}
if ($access{'slave'} && !$access{'ro'}) {
	push(@crlinks, &ui_link("slave_form.cgi", $text{'index_addslave'}) );
	push(@crlinks, &ui_link("stub_form.cgi", $text{'index_addstub'}) );
	}
if ($access{'forward'} && !$access{'ro'}) {
	push(@crlinks, &ui_link("forward_form.cgi", $text{'index_addfwd'}) );
	}
if ($access{'delegation'} && !$access{'ro'} && &version_atleast(9, 2, 1)) {
	push(@crlinks, &ui_link("delegation_form.cgi", $text{'index_adddele'}) );
	}
if ($access{'master'} && !$access{'ro'} &&
    scalar(@hashint) < (@views ? scalar(@views) : 1)) {
	push(@crlinks, &ui_link("hint_form.cgi", $text{'index_addhint'}) );
	}
if (@crlinks) {
	push(@crlinks, &ui_link("mass_form.cgi", $text{'index_addmass'}) );
	}

my %heiropen;
# These variables are very hairy.
my (@zorder, @zlinks, @ztitles, @zdels, @zicons, @ztypes, @zsort, @zstatus);
my $len;
if (@zones > $config{'max_zones'}) {
	# Too many zones, show search form
	print &ui_subheading($text{'index_zones'});
	print "$text{'index_toomany'}<p>\n";
	print &ui_form_start("find_zones.cgi");
	print "<b>$text{'index_find'}</b>\n";
	print &ui_textbox("search", undef, 20);
	print &ui_form_end([ [ undef, $text{'index_search'} ] ]);
	print &ui_links_row(\@crlinks);
	}
elsif (@zones && (!@views || !$config{'by_view'})) {
	# Show all zones
	print &ui_subheading($text{'index_zones'});

	if (&have_dnssec_tools_support()) {
		# Parse the rollrec file to determine zone status
		&lock_file($config{"dnssectools_rollrec"});
		rollrec_lock();
		rollrec_read($config{"dnssectools_rollrec"});
	}

	foreach my $z (@zones) {
		my $v = $z->{'name'};
		my $t = $z->{'type'};
		next if (!$t);
		$t = "delegation" if ($t eq "delegation-only");
		my $zn = $v eq "." ? "<i>$text{'index_root'}</i>"
				      : &ip6int_to_net(&arpa_to_ip($v));
		if ($z->{'view'}) {
			my $vw = $z->{'viewindex'};
			push(@zlinks, "edit_$t.cgi?zone=$z->{'name'}".
				      "&view=$vw");
			push(@ztitles, $zn." ".
			       &text('index_view', "<tt>$z->{'view'}</tt>"));
			push(@zdels, &can_edit_zone($z, $vw) ?
				$z->{'name'}." ".$z->{'viewindex'} : undef);
			}
		else {
			push(@zlinks, "edit_$t.cgi?zone=$z->{'name'}");
			push(@ztitles, $zn);
			push(@zdels, &can_edit_zone($z) ?
				$z->{'name'} : undef);
			}
		push(@zsort, $t eq 'hint' ? undef : $ztitles[$#ztitles]);
		push(@zicons, "images/$t.gif");
		push(@ztypes, $text{"index_$t"});

		if (&have_dnssec_tools_support()) {
			my $rrr = rollrec_fullrec($v);
			if ($rrr) {
				if($rrr->{'kskphase'} > 0) {
					if($rrr->{'kskphase'} == 6) {
						push(@zstatus, $text{"dt_status_waitfords"});
					} else {        
						push(@zstatus, $text{"dt_status_inKSKroll"});
					}
				} elsif($rrr->{'zskphase'} > 0) {
					push(@zstatus, $text{"dt_status_inZSKroll"});
				} else {    
					push(@zstatus, $text{"dt_status_signed"});
				}
			} else {
				push(@zstatus, $text{"dt_status_unsigned"});
			}
		}

		$zhash{$zn} = $z;
		$ztitlehash{$zn} = $ztitles[$#ztitles];
		$zlinkhash{$zn} = $zlinks[$#zlinks];
		$ztypeshash{$zn} = $ztypes[$#ztypes];
		$zdelhash{$zn} = $zdels[$#zdels];
		if (&have_dnssec_tools_support()) {
			$zstatushash{$zn} = $zstatus[$#zstatus];
		}
		$len++;
		}

	if (&have_dnssec_tools_support()) {
		rollrec_close();
		rollrec_unlock();
		&unlock_file($config{"dnssectools_rollrec"});
	}

	# sort list of zones
	@zorder = sort { &compare_zones($zsort[$a], $zsort[$b]) } (0 .. $len-1);
	@zlinks = map { $zlinks[$_] } @zorder;
	@ztitles = map { $ztitles[$_] } @zorder;
	@zicons = map { $zicons[$_] } @zorder;
	@ztypes = map { $ztypes[$_] } @zorder;
	@zdels = map { $zdels[$_] } @zorder;
	@zstatus = map { $zstatus[$_] } @zorder;

	print &ui_form_start("mass_delete.cgi", "post");
	my @links = ( &select_all_link("d", 0),
		   &select_invert_link("d", 0),
		   @crlinks );
	print &ui_links_row(\@links);

	if ($config{'show_list'} == 1) {
		# display as list
		my $mid = int((@zlinks+1)/2);
		my @grid = ( );
		if (&have_dnssec_tools_support()) {
			push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
						  [ @ztitles[0 .. $mid-1] ],
						  [ @ztypes[0 .. $mid-1] ],
						  [ @zdels[0 .. $mid-1] ],
						  [ @zstatus[0 .. $mid-1] ]));
			}
		else {
			push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
					         [ @ztitles[0 .. $mid-1] ],
					         [ @ztypes[0 .. $mid-1] ],
						 [ @zdels[0 .. $mid-1] ]));
			}
		if ($mid < @zlinks) {
			if (&have_dnssec_tools_support()) {
			push(@grid, &zones_table([ @zlinks[$mid .. $#zlinks] ],
					     [ @ztitles[$mid .. $#ztitles] ],
					     [ @ztypes[$mid .. $#ztypes] ],
						 [ @zdels[$mid .. $#ztypes] ],
						 [ @zstatus[$mid .. $#ztypes] ]));
			} else {
			push(@grid, &zones_table([ @zlinks[$mid .. $#zlinks] ],
						 [ @ztitles[$mid .. $#ztitles] ],
						 [ @ztypes[$mid .. $#ztypes] ],
						 [ @zdels[$mid .. $#ztypes] ]));
			}
			}
		print &ui_grid_table(\@grid, 2, 100,
				     [ "width=50%", "width=50%" ]);
		}
	elsif ($config{'show_list'} == 2) {
		# Show as collapsible tree, broken down by domain parts
		%heiropen = map { $_, 1 } &get_heiropen();
		$heiropen{""} = 1;
		foreach my $z (grep { $_->{'type'} } @zones) {
			my $v = $z->{'name'};
			my @p = split(/\./, &ip6int_to_net(&arpa_to_ip($v)));
			for(my $i=1; $i<=@p; $i++) {
				my $ch = join(".", @p[$i-1 .. $#p]);
				my $par = $i == @p ?
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
		my @befores = map { $_ ? &ui_checkbox("d", $_, "", 0) : "" }
			       @zdels;
		&icons_table(\@zlinks, \@ztitles, \@zicons, 5, undef, 
			     undef, undef, \@befores);
		}
	print &ui_links_row(\@links);
	print &ui_form_end([
		$access{'delete'} ?
		      ( [ "delete", $text{'index_massdelete'} ] ) : ( ),
		[ "update", $text{'index_massupdate'}, undef, 0,
		  "onClick='form.action=\"mass_update_form.cgi\"'" ],
		[ "create", $text{'index_masscreate'}, undef, 0,
		  "onClick='form.action=\"mass_rcreate_form.cgi\"'" ],
		[ "rdelete", $text{'index_massrdelete'}, undef, 0,
		  "onClick='form.action=\"mass_rdelete_form.cgi\"'" ] ]);
	}
elsif (@zones) {

	if (&have_dnssec_tools_support()) {
		# Parse the rollrec file to determine zone status
		&lock_file($config{"dnssectools_rollrec"});
		rollrec_lock();
		rollrec_read($config{"dnssectools_rollrec"});
	}

	# Show zones under views
	print &ui_subheading($text{'index_zones'});
	foreach my $vw (@views) {
		my @zv = grep { $_->{'view'} eq $vw->{'name'} } @zones;
		next if (!@zv);
		print "<b>",&text('index_inview',
				  "<tt>$vw->{'name'}</tt>"),"</b><br>\n";
		my (@zlinks, @ztitles, @zsort, @zicons, @ztypes, @zdels);
		my $len = 0;
		foreach my $z (@zv) {
			my $v = $z->{'name'};
			my $t = $z->{'type'};
			my $zn = $v eq "." ? "<i>$text{'index_root'}</i>"
					      : &ip6int_to_net(&arpa_to_ip($v));
			push(@zlinks, "edit_$t.cgi?zone=$z->{'name'}".
				      "&view=$z->{'viewindex'}");
			push(@ztitles, $zn);
			push(@zsort, $t eq 'hint' ? undef : $ztitles[$#ztitles]);
			push(@zicons, "images/$t.gif");
			push(@ztypes, $text{"index_$t"});
			push(@zdels, $z->{'index'}." ".$z->{'viewindex'});
			if (&have_dnssec_tools_support()) {
				my $rrr = rollrec_fullrec($v);
				if ($rrr) {
					if($rrr->{'kskphase'} > 0) {
						if($rrr->{'kskphase'} == 6) {
							push(@zstatus, $text{"dt_status_waitfords"});
						} else {
							push(@zstatus, $text{"dt_status_inKSKroll"});
						}
					} elsif($rrr->{'zskphase'} > 0) {
						push(@zstatus, $text{"dt_status_inZSKroll"});
					} else {
						push(@zstatus, $text{"dt_status_signed"});
					}
				} else {
					push(@zstatus, $text{"dt_status_unsigned"});
				}
			}
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
		@zstatus = map { $zstatus[$_] } @zorder;

		print &ui_form_start("mass_delete.cgi", "post");
		print &ui_links_row(\@crlinks);
		if ($config{'show_list'}) {
			# display as list
			my $mid = int((@zlinks+1)/2);
			my @grid = ( );
			if (&have_dnssec_tools_support()) {
			push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
						 [ @ztitles[0 .. $mid-1] ],
						 [ @ztypes[0 .. $mid-1] ],
						 [ @zdels[0 .. $mid-1] ],
						 [ @zstatus[0 .. $mid-1] ]));
			} else {
			push(@grid, &zones_table([ @zlinks[0 .. $mid-1] ],
					     [ @ztitles[0 .. $mid-1] ],
					     [ @ztypes[0 .. $mid-1] ],
					     [ @zdels[0 .. $mid-1] ]));
			}
			if ($mid < @zlinks) {
				push(@grid, &zones_table(
					     [ @zlinks[$mid .. $#zlinks] ],
					     [ @ztitles[$mid .. $#ztitles] ],
					     [ @ztypes[$mid .. $#ztypes] ],
						 [ @zdels[$mid .. $#zdels] ],
						 [ @zstatus[$mid .. $#zstatus] ]));
				}
			print &ui_grid_table(\@grid, 2, 100,
					     [ "width=50%", "width=50%" ]);
			}
		else {
			# display as icons
			my @befores = map { $_ ? &ui_checkbox("d", $_, "", 0) : "" }
				       @zdels;
			&icons_table(\@zlinks, \@ztitles, \@zicons, 5, undef,
				     undef, undef, \@befores);
			}
		print &ui_links_row(\@crlinks);
		print &ui_form_end([
			$access{'delete'} ?
			  ( [ "delete", $text{'index_massdelete'} ] ) : ( ),
			[ "update", $text{'index_massupdate'}, undef, 0,
			  "onClick='form.action=\"mass_update_form.cgi\"'" ],
			[ "create", $text{'index_masscreate'}, undef, 0,
			  "onClick='form.action=\"mass_rcreate_form.cgi\"'" ],
			[ "rdelete", $text{'index_massrdelete'}, undef, 0,
			  "onClick='form.action=\"mass_rdelete_form.cgi\"'" ]]);
		}
	if (&have_dnssec_tools_support()) {
		rollrec_close();
		rollrec_unlock();
		&unlock_file($config{"dnssectools_rollrec"});
	}
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row(\@crlinks);
	}

if ($access{'views'} && $bind_version >= 9) {
	# Display list of views
	print &ui_hr();
	print &ui_subheading($text{'index_views'});

	# Show a warning if any zones are not in a view
	my @notinview = grep { !defined($_->{'viewindex'}) ||
			       $_->{'viewindex'} eq '' } @zones;
	if (@notinview && @views) {
		print "<b>",&text('index_viewwarn',
		  join(" , ", map { "<tt>".&ip6int_to_net(
					  &arpa_to_ip($_->{'name'}))."</tt>" }
				@notinview)),"</b><p>\n";
		print "<b>$text{'index_viewwarn2'}</b><p>\n";
		}

	@views = grep { &can_edit_view($_) } @views;
	my (@vicons, @vtitles, @vlinks);
	foreach my $v (@views) {
		push(@vlinks, "edit_view.cgi?index=$v->{'index'}");
		push(@vtitles, $v->{'name'});
		push(@vicons, "images/view.gif");
		}
	my @links = ( );
	push(@links, &ui_link("view_form.cgi", $text{'index_addview'}) ) if (!$access{'ro'} && $access{'views'} != 2);
	if (@views) {
		print &ui_links_row(\@links);
		&icons_table(\@vlinks, \@vtitles, \@vicons, 5);
		}
	else {
		print "<b>$text{'index_vnone'}</b><p>\n";
		}
	print &ui_links_row(\@links);
	}

&ui_print_footer("/", $text{"index"});

sub dump_config
{
foreach my $c (@{$_[0]}) {
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
my @sp0 = split(/\./, lc($_[0] || ""));
my @sp1 = split(/\./, lc($_[1] || ""));
for(my $i=0; $i<@sp0 || $i<@sp1; $i++) {
	if ($sp0[$i] =~ /^\d+$/ && $sp1[$i] =~ /^\d+$/) {
		return -1 if ($sp0[$i] < $sp1[$i]);
		return 1 if ($sp0[$i] > $sp1[$i]);
		}
	else {
		my $c = $sp0[$i] cmp $sp1[$i];
		return $c if ($c);
		}
	}
return 0;
}

sub recursive_tree
{
my ($name, $depth) = @_;
print "<tr> <td>", "&nbsp;&nbsp;" x $depth;
if ($_[0] ne "") {
	print "<a name=\"$name\"></a>\n";
	$name =~ /^([^\.]+)/;
	if (!$ztree{$name}) {
		# Has no children
		print "<img border=0 src='images/smallicon.gif'>&nbsp; $1</td>\n",
		}
	else {
		# Has children
		my $act = $heiropen{$name} ? "close" : "open";
		print &ui_link("$act.cgi?what=".&urlize($name), "<img border=0 src='images/$act.gif'>");
		print "&nbsp; $1</td>\n",
		}
	}
else {
	# Is the root
	print "<img src=images/close.gif> <i>$text{'index_all'}</i></td>\n";
	}
if ($zhash{$name}) {
	my $cb = $zdelhash{$name} ?
		&ui_checkbox("d", $zdelhash{$name}, "", 0)." " : "";
	if (&have_dnssec_tools_support()) {
	print "<td>$cb".&ui_link($zlinkhash{$name}, "$ztitlehash{$name} ($ztypeshash{$name}) ($zstatushash{$name})")."</td></tr>\n";
	} else {
	print "<td>$cb".&ui_link($zlinkhash{$name}, "$ztitlehash{$name} ($ztypeshash{$name})")."</td></tr>\n";
	}
	}
else {
	print "<td><br></td> </tr>\n";
	}
if ($heiropen{$name}) {
	foreach my $sz (@{$ztree{$name}}) {
		&recursive_tree($sz, $depth+1);
		}
	}
}

