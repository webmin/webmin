#!/usr/local/bin/perl
# index.cgi
# Display a list of all virtual servers, and links for various types
# of global configuration

require './apache-lib.pl';
&ReadParse();

# check for the executable
if (!($httpd = &find_httpd())) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print &text('index_eserver', "<tt>$config{'httpd_path'}</tt>",
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link("apache", $text{'index_apache'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# check for the base directory
if (!(-d $config{'httpd_dir'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print &text('index_eroot', "<tt>$config{'httpd_dir'}</tt>",
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# check if this is a new apache install, by looking for -dist files
$conf = "$config{'httpd_dir'}/etc";
if (!-d $conf) { $conf = "$config{'httpd_dir'}/conf"; }
if (!$config{'httpd_conf'} && !(-e "$conf/httpd.conf") &&
    (-e "$conf/httpd.conf-dist") &&
    (-d $conf)) {
	# copy all the .dist files and fix up @@ServerRoot@@ references
	# Only needed for apache versions < 1.3, which don't do this as part
	# of the 'make install'
	$sroot = $config{'httpd_dir'};
	opendir(CONF, $conf);
	foreach $f (readdir(CONF)) {
		if ($f =~ /^(.*)-dist$/) {
			open(DIST, "<$conf/$f");
			@dist = <DIST>;
			close(DIST);
			&open_tempfile(REAL, ">$conf/$1");
			foreach (@dist) {
				s/\/usr\/local\/etc\/httpd/$sroot/g;
				s/\@\@ServerRoot\@\@/$sroot/g;
				&print_tempfile(REAL, $_);
				}
			&close_tempfile(REAL);
			}
		}
	close(CONF);
	}

# check for an -example file
if ($config{'httpd_conf'} && !-e $config{'httpd_conf'} &&
    -e $config{'httpd_conf'}."-example") {
	system("cp ".quotemeta($config{'httpd_conf'}."-example")." ".
		     quotemeta($config{'httpd_conf'}));
	}

# check for the httpd.conf file
($htconf, $htconfchecked) = &find_httpd_conf();
if (!$htconf) {
	# still doesn't exist!
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>\n";
	print &text('index_econf', "<tt>$htconfchecked</tt>",
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# check for multiple port directives
$conf = &get_config();
@prt = &find_directive("Port", $conf);
if (@prt > 1 && $httpd_modules{'core'} < 1.3) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	print "<p>\n";
	print &text('index_eports', 'Port'),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# add default server
$defport = &find_directive("Port", $conf, 1);
if (&can_edit_virt()) {
	local $sn = &find_directive("ServerName", $conf, 1);
	push(@vidx, undef);
	push(@vname, $text{'index_defserv'});
	push(@vlink, "virt_index.cgi");
	push(@vdesc, $text{'index_defdesc1'});
	push(@vaddr, $text{'index_any'});
	push(@vport, $text{'index_any'});
	push(@vserv, $sn);
	push(@vroot, &def(&find_directive("DocumentRoot", $conf, 1),
			  $text{'index_auto'}));
	push(@vproxy, undef);
	$sn ||= &get_system_hostname();
	push(@vurl, $defport ? "http://$sn:$defport/" : "http://$sn/");
	$showing_default++;
	}

# add other servers
@virt = &find_directive_struct("VirtualHost", $conf);
if ($httpd_modules{'core'} >= 2.4) {
	# Apache 2.4 makes all IPs name-based
	$nv{"*"}++;
	}
elsif ($httpd_modules{'core'} >= 1.3) {
	# build list of name-based virtual host IP addresses
	@nv = &find_directive("NameVirtualHost", $conf);
	foreach $nv (@nv) {
		if ($nv =~ /:(\d+)$/) {
			push(@nvports, $1);
			}
		$nv =~ s/:\d+$//;
		$nv{$nv =~ /^\*/ ? "*" : &to_ipaddress($nv)}++;
		}
	@nvports = &unique(@nvports);
	}
elsif ($httpd_modules{'core'} >= 1.2) {
	# only one name-based virtual host IP address - the default address
	$ba = &find_directive("ServerName", $conf);
	$nv{&to_ipaddress($ba ? $ba : &get_system_hostname())}++;
	}
@virt = grep { &can_edit_virt($_) } @virt;
if ($config{'show_order'} == 1) {
	# sort by server name
	@virt = sort { &server_name_sort($a) cmp &server_name_sort($b) } @virt;
	}
elsif ($config{'show_order'} == 2) {
	# sort by IP address
	@virt = sort { &server_ip_sort($a) cmp &server_ip_sort($b) } @virt;
	}
foreach $v (@virt) {
	$vm = $v->{'members'};
	if ($v->{'words'}->[0] =~ /^\[(\S+)\]:(\d+)$/) {
		# IPv6 address and port
		$addr = $1;
		$port = $2;
		}
	elsif ($v->{'words'}->[0] =~ /^(\S+):(\d+)$/) {
		# IPv4 address and port
		$addr = $1;
		$port = $2;
		}
	else {
		# Address, perhaps v6, with default port
		$addr = $v->{'words'}->[0];
		$addr = $1 if ($addr =~ /^\[(\S+)\]$/);
		if ($httpd_modules{'core'} < 2.0) {
			$port = &def(&find_directive("Port", $conf), 80);
			}
		else {
			$port = "*";
			}
		}
	$idx = &indexof($v, @$conf);
	push(@vidx, $idx);
	push(@vname, $text{'index_virt'});
	push(@vlink, "virt_index.cgi?virt=$idx");
	$sname = &find_directive("ServerName", $vm);
	local $daddr = $addr eq "_default_" ||
                       ($addr eq "*" && $httpd_modules{'core'} < 1.2);
	if ($nv{"*"}) {
		if ($daddr) {
			push(@vdesc, &text('index_vnamed', "<tt>$sname</tt>"));
			}
		else {
			push(@vdesc, &text('index_vname', "<tt>$sname</tt>",
					   "<tt>$addr</tt>"));
			}
		}
	elsif (!$daddr && $nv{&to_ipaddress($addr)}) {
		push(@vdesc, &text('index_vname', "<tt>$sname</tt>",
				   "<tt>$addr</tt>"));
		}
	elsif (!$daddr && $addr eq "*") {
		push(@vdesc, &text('index_vnamed', "<tt>$sname</tt>"));
		}
	elsif ($daddr && $port eq "*") {
		push(@vdesc, $text{'index_vdef'});
		$vdesc[0] = $text{'index_defdesc2'};
		}
	elsif ($daddr) {
		push(@vdesc, &text('index_vport', $port));
		}
	elsif ($port eq "*") {
		push(@vdesc, &text('index_vaddr', "<tt>$addr</tt>"));
		}
	else {
		push(@vdesc, &text('index_vaddrport', "<tt>$addr</tt>", $port));
		}
	push(@vaddr, $addr eq "_default_" || $addr eq "*" ? $text{'index_any'}
							  : $addr);
	push(@vport, $port eq "*" ? $text{'index_any'} : $port);
	local $sn = &find_vdirective("ServerName", $vm, $conf, 1);
	push(@vserv, $sn);
	$pp = &find_directive_struct("ProxyPass", $vm);
	if ($pp->{'words'}->[0] eq "/") {
		push(@vproxy, $pp->{'words'}->[1]);
		push(@vroot, undef);
		}
	else {
		push(@vproxy, undef);
		push(@vroot, &def(&find_vdirective("DocumentRoot",$vm,$conf,1),
				  $text{'index_default'}));
		}
	$cname{$v} = sprintf "%s:%s (%s)",
			$vserv[$#vserv] || $text{'index_auto'},
			$vport[$#vport],
			$vproxy[$#vproxy] || $vroot[$#vroot];
	local $sp = $port eq "*" ? $defport : $port;
	local $prot = "http";
	if (&find_vdirective("SSLEngine", $vm, $conf, 1) eq "on") {
		$prot = "https";
		}
	elsif ($port == 443) {
		$prot = "https";
		}
	$sp = undef if ($sp == 80 && $prot eq "http" ||
			$sp == 443 && $prot eq "https");
	push(@vurl, $sp ? "$prot://$sn:$sp/" : "$prot://$sn/");
	}

if (@vlink == 1 && !$access{'global'} && $access{'virts'} ne "*" &&
    !$access{'create'} && $access{'noconfig'}) {
	# Can only manage one vhost, so go direct to it
	&redirect($vlink[0]);
	exit;
	}

# Page header
$ver = $httpd_modules{'core'};
$ver =~ s/^(\d+)\.(\d)(\d+)$/$1.$2.$3/;
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, undef,
	&restart_button()."<br>".
	&help_search_link("apache", "man", "doc", "google"), undef, undef,
	&text('index_version', $ver));

# Show tabs
@tabs = map { [ $_, $text{'index_tab'.$_}, "index.cgi?mode=$_" ] }
	    ( $access{'global'} ? ( "global" ) : ( ),
	      "list",
	      $access{'create'} ? ( "create" ) : ( ) );
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "list", 1);

# global config options
if ($access{'global'}) {
	print &ui_tabs_start_tab("mode", "global");
	#print $text{'index_descglobal'},"<p>\n";
	if ($access{'global'} == 1) {
		$ht_icon = { "icon" => "images/dir.gif",
			     "name" => $text{'htaccess_title'},
			     "link" => "htaccess.cgi" };
		if (&can_configure_apache_modules()) {
			$rc_icon = { "icon" => "images/mods.gif",
				     "name" => $text{'mods_title'},
				     "link" => "edit_mods.cgi" };
			}
		elsif (!$config{'auto_mods'}) {
			$rc_icon = { "icon" => "images/recon.gif",
				     "name" => $text{'reconfig_title'},
				     "link" =>
				"reconfig_form.cgi?size=$httpd_size&vol=1" };
			}
		$df_icon = { "icon" => "images/defines.gif",
			     "name" => $text{'defines_title'},
			     "link" => "edit_defines.cgi" };
		$ed_icon = { "icon" => "images/edit.gif",
			     "name" => $text{'manual_configs'},
			     "link" => "allmanual_form.cgi" };
		$ds_icon = { "icon" => "images/virt.gif",
			     "name" => $text{'index_defserv'},
			     "link" => "virt_index.cgi" };
		&config_icons("global", "edit_global.cgi?",
			      $ht_icon, $rc_icon, $df_icon,
			      $access{'types'} eq '*' &&
			      $access{'virts'} eq '*' ? ( $ed_icon ) : ( ),
			      $showing_default &&
			      @vname > $config{'max_servers'} &&
			      $config{'max_servers'} ? ( $ds_icon ) : ( ) );
		}
	else {
		&icons_table([ "htaccess.cgi" ],
			     [ $text{'htaccess_title'} ],
			     [ "images/dir.gif" ]);
		}
	print &ui_tabs_end_tab();
	}

# work out select links
print &ui_tabs_start_tab("mode", "list");
#print $text{'index_desclist'},"<p>\n";
$showdel = $access{'vaddr'} && ($vidx[0] || $vidx[1]);
@links = ( );
if ($showdel) {
	push(@links, &select_all_link("d"),
		     &select_invert_link("d"));
	}

# display servers
$formno = 0;
if ($config{'max_servers'} && @vname > $config{'max_servers'}) {
	# as search form for people with lots and lots of servers
	print "<b>$text{'index_toomany'}</b><p>\n";
	print "<form action=search_virt.cgi>\n";
	print "<b>$text{'index_find'}</b> <select name=field>\n";
	print "<option value=name checked>$text{'index_name'}</option>\n";
	print "<option value=port>$text{'index_port'}</option>\n";
	print "<option value=addr>$text{'index_addr'}</option>\n";
	print "<option value=root>$text{'index_root'}</option>\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}</option>\n";
	print "<option value=1>$text{'index_matches'}</option>\n";
	print "<option value=2>$text{'index_nequals'}</option>\n";
	print "<option value=3>$text{'index_nmatches'}</option>\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form><p>\n";
	$formno++;
	}
elsif ($config{'show_list'} && scalar(@vname)) {
	# as list for people with lots of servers
	if ($showdel) {
		print &ui_form_start("delete_vservs.cgi", "post");
		}
	print &ui_links_row(\@links);
	print &ui_columns_start([
		$showdel ? ( "" ) : ( ),
		$text{'index_type'},
		$text{'index_addr'},
		$text{'index_port'},
		$text{'index_name'},
		$text{'index_root'},
		$text{'index_url'} ], 100);
	for($i=0; $i<@vname; $i++) {
		local @cols;
		push(@cols, &ui_link($vlink[$i], $vname[$i]) );
		push(@cols, &html_escape($vaddr[$i]));
		push(@cols, &html_escape($vport[$i]));
		push(@cols, $vserv[$i] || $text{'index_auto'});
		push(@cols, &html_escape($vproxy[$i]) ||
			    &html_escape($vroot[$i]));
		push(@cols, &ui_link($vurl[$i], $text{'index_view'}) );
		if ($showdel && $vidx[$i]) {
			print &ui_checked_columns_row(\@cols, undef,
						      "d", $vidx[$i]);
			}
		elsif ($showdel) {
			print &ui_columns_row([ "", @cols ]);
			}
		else {
			print &ui_columns_row(\@cols);
			}
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	if ($showdel) {
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		}
	}
else {
	# as icons for niceness
	if ($showdel) {
		print &ui_form_start("delete_vservs.cgi", "post");
		}
	print &ui_links_row(\@links);
	print "<table width=100% cellpadding=5>\n";
	for($i=0; $i<@vname; $i++) {
		print "<tr class='mainbody ".($i % 2 ? 'row0' : 'row1')."'> <td valign=top align=center nowrap>";
		print '<div class="row icons-row inline-row">';
		&generate_icon("images/virt.gif", $vname[$i], $vlink[$i],
			       undef, undef, undef,
			       $vidx[$i] && $access{'vaddr'} ?
					&ui_checkbox("d", $vidx[$i]) : "");
		print "</div>\n";
		print "</td> <td valign=top>\n";
		print "$vdesc[$i]<br>\n";
		print "<table width=100%><tr>\n";
		print "<td width=30%><b>$text{'index_addr'}</b> ",
		      &html_escape($vaddr[$i]),"<br>\n";
		print "<b>$text{'index_port'}</b> ",
		      &html_escape($vport[$i]),"</td>\n";
		print "<td width=70%><b>$text{'index_name'}</b> ",
		      (&html_escape($vserv[$i]) || $text{'index_auto'}),
		      "<br>\n";
		if ($vproxy[$i]) {
			print "<b>$text{'index_proxy'}</b> ",
			      &html_escape($vproxy[$i]),"</td> </tr>\n";
			}
		else {
			print "<b>$text{'index_root'}</b> ",
			      &html_escape($vroot[$i]),"</td> </tr>\n";
			}
		print "</table></td> </tr>\n";
		}
	print "</table>\n";
	print &ui_links_row(\@links);
	if ($showdel) {
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		}
	}
print &ui_tabs_end_tab();

if ($access{'create'}) {
	print &ui_tabs_start_tab("mode", "create");
	#print $text{'index_desccreate'},"<p>\n";
	print &ui_form_start("create_virt.cgi");
	print &ui_table_start($text{'index_create'}, undef, 2);

	# IP address
	print &ui_table_row($text{'index_newaddr'},
		&ui_radio("addr_def", 2,
		  [ [ 1, "$text{'index_any1'}<br>" ],
		    [ 2, "$text{'index_any2'}<br>" ],
		    [ 0, $text{'index_any0'}." ".
			 &ui_textbox("addr", undef, 40) ] ])."<br>\n".
		($httpd_modules{'core'} < 2.4 ?
		  &ui_checkbox("nv", 1, $text{'index_nv'}, 1)."<br>" : "").
		&ui_checkbox("listen", 1, $text{'index_listen'}, 1));

	# Port
	print &ui_table_row($text{'index_port'},
		&choice_input(@nvports ? 2 : 0,
			      "port_mode", "0",
			      "$text{'index_default'},0",
				"$text{'index_any'},1", ",2").
		&ui_textbox("port", @nvports ? $nvports[0] : undef, 5));

	# Document root
	print &ui_table_row($text{'index_root'},
		&ui_textbox("root", undef, 40)." ".
		&file_chooser_button("root", 1, $formno)."<br>".
		&ui_checkbox("adddir", 1, $text{'index_adddir'}, 1));

	# Server name
	if ($access{'virts'} eq '*') {
		print &ui_table_row($text{'index_name'},
			&opt_input("", "name", $text{'index_auto'}, 30));
		}
	else {
		# Require that non-root users enter a server name, or else it
		# will be impossible to grant access to the new virtualhost
		print &ui_table_row($text{'index_name'},
			&ui_textbox("name", "", 30));
		}

	# Add to file
	print &ui_table_row($text{'index_file'},
		&ui_radio("fmode", $config{'virt_file'} ? 1 : 0,
		  [ [ 0, &text('index_fmode0', "<tt>httpd.conf</tt>")."<br>" ],
		    $config{'virt_file'} ? (
		      [ 1, &text(-d $config{'virt_file'} ? 'index_fmode1d'
                                                      : 'index_fmode1',
                              "<tt>$config{'virt_file'}</tt>")."<br>" ] ) : ( ),
		    [ 2, $text{'index_fmode2'}." ".
			 &ui_textbox("file", undef, 40)." ".
			 &file_chooser_button("file", 0, $formno) ] ]));

	# Server to clone
	print &ui_table_row($text{'index_clone'},
		&ui_select("clone", undef,
		  [ [ undef, $text{'index_noclone'} ],
		    map { [ &indexof($_, @$conf), $cname{$_} ] } @virt ]));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'index_crnow'} ] ]);
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

sub server_name_sort
{
return &def(&find_vdirective("ServerName", $_[0]->{'members'}, $conf),
	    $_[0]->{'value'});
}

sub server_ip_sort
{
local $addr = $_[0]->{'words'}->[0] =~ /^(\S+):(\S+)/ ? $1 :
		$_[0]->{'words'}->[0];
return $addr eq '_default_' || $addr eq '*' ? undef :
       &check_ipaddress($addr) ? $addr :
       $addr =~ /^\[(\S+)\]$/ && &check_ip6address($1) ? $1 :
			         &to_ipaddress($addr);
}

