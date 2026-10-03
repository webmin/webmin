# Functions that build the left menu: in the left frame of the frameset, or
# at the side of every page in the single page layout. theme.pl loads this
# file into its own package when a menu is needed.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# $main::session_id, set by the core, is used only once in this file
no warnings 'once';
# Globals of the core, in the package this file is loaded into
our (%in, %gconfig, $remote_user, $base_remote_user, $current_theme);

# Pages that show a domain or a managed system. menu.cgi opens one when a
# domain or system is chosen in a menu field that names no page of its own.
our %theme_menu_pages = (
	'dom' => '/virtual-server/summary_domain.cgi?dom=',
	'sid' => '/server-manager/edit_serv.cgi?id=',
	);

# theme_menu_html([&options])
# Returns the HTML of the menu panel. The options are :
#   in     - Menu inputs, as the left frame gets them: the mode, the dom,
#            dname or sid of the chosen domain or system, and the IDs of
#            categories to open
#   single   - Build the menu for a page of the single page layout
#   fragment - Return the panel alone, without the scripts that follow
#              it, for menu.cgi to send to a page that loads its menu
# In the single page layout the current page picks the mode, domain and
# system when its module has a menu of its own, and the choices remembered
# in the cookie fill in the rest. The link to the current page, or to the
# page the browser came from, is marked and its category opened.
sub theme_menu_html
{
my ($opts) = @_;
$opts ||= { };
# The settings and language strings, and in the single page layout the
# remembered choices and what the current page implies
my $single = $opts->{'single'};
my %min = %{$opts->{'in'} || { }};
my %mtext = &load_language($current_theme);
my $sects = &theme_settings();
my $state = $single ? &theme_menu_state() : { };
my %page = $single ? &theme_menu_page() : ( );

if ($single) {
	# The page's domain or system wins over the remembered one
	foreach my $k ('dom', 'sid') {
		my $v = defined($page{$k}) ? $page{$k} : $state->{$k};
		$min{$k} = $v if ($v ne '');
		}
	}

# Find all left-side items from Webmin
my @allitems = &list_combined_webmin_menu($sects, \%min);
my $sel = &theme_menu_selection(\@allitems);
if ($single) {
	# If the menu cannot show the domain or system the page names, for
	# example because the ID is of some other object, use the remembered
	# one instead
	my $retry = 0;
	foreach my $k ('dom', 'sid') {
		next if (!defined($page{$k}) || !exists($sel->{$k}) ||
			 $sel->{$k} eq $page{$k} ||
			 $state->{$k} eq '' || $state->{$k} eq $page{$k});
		$min{$k} = $state->{$k};
		$retry++;
		}
	if ($retry) {
		# Build the menu again with the remembered choices
		@allitems = &list_combined_webmin_menu($sects, \%min);
		$sel = &theme_menu_selection(\@allitems);
		}
	}
# The titles of module menus, such as Virtualmin's, name the modes of the
# product switch
my @leftitems = @allitems;
my @lefttitles = grep { $_->{'type'} eq 'title' } @leftitems;

# Work out what the mode selector contains
my @has = ( );
my %modmenu;
foreach my $title (@lefttitles) {
	push(@has, { 'id' => $title->{'module'},
		     'desc' => $title->{'desc'} });
	$modmenu{$title->{'module'}}++;
	}
my $nw = $sects->{'nowebmin'} || 0;
if ($nw == 0 || $nw == 2 && &theme_menu_master()) {
	# Offer the Webmin modules mode, unless the settings hide it from
	# everyone, or from everyone but the master admin
	push(@has, { 'id' => 'modules',
		     'desc' => $mtext{'has_'.&get_product_name()} });
	}
my %hasmode = map { $_->{'id'}, 1 } @has;

# In the left frame, use the mode asked for. In the single page layout,
# use the mode of the current page's module if it has one, else the
# remembered mode. Failing that, the settings or the first menu decide.
my $mode = !$single ? $min{'mode'} :
	   $hasmode{$page{'mode'}} ? $page{'mode'} : $state->{'mode'};
$mode ||= $sects->{'tab'} && $sects->{'tab'} =~ /vm2/ ? "server-manager" :
	  $sects->{'tab'} && $sects->{'tab'} =~ /virtualmin/ ? "virtual-server" :
	  $sects->{'tab'} && $sects->{'tab'} =~ /mail/ ? "mailboxes" :
	  $sects->{'tab'} && $sects->{'tab'} =~ /webmin/ ? "modules" :
	  @leftitems ? $has[0]->{'id'} : "modules";
if (!$hasmode{$mode}) {
	# A mode that is not offered falls back to the first one
	$mode = $has[0]->{'id'};
	}

if ($mode eq "modules") {
	# The Webmin modules by category, without the modules that have a
	# mode of their own
	@leftitems = &list_modules_webmin_menu();
	foreach my $l (@leftitems) {
		$l->{'members'} = [ grep { !$modmenu{$_->{'id'}} }
					 @{$l->{'members'}} ];
		}
	push(@leftitems, { 'type' => 'hr' });
	}
else {
	# The menu of the mode's module, plus items of menus that have no
	# title and so no mode
	my %titlemods = map { $_->{'module'}, $_ } @lefttitles;
	@leftitems = grep { $_->{'module'} eq $mode ||
			    !$titlemods{$_->{'module'}} } @leftitems;
	}
# The titles only name the modes, and are not shown in the menu
@leftitems = grep { $_->{'type'} ne 'title' } @leftitems;

# Lines of text at the start of the menu, such as the login and its level,
# go into the brand block instead of the menu
my @userlines;
while(@leftitems && $leftitems[0]->{'type'} eq 'text') {
	my $t = shift(@leftitems);
	if ($t->{'json'} && $t->{'json'}->{'label'}) {
		# Login line, shown as the username and its level
		push(@userlines, "<b>".&html_escape($remote_user)."</b>".
			($t->{'json'}->{'level'} ?
			    " &middot; ".$t->{'json'}->{'level'} : ""));
		}
	else {
		# Any other line of text, as it is
		push(@userlines, &html_escape($t->{'desc'}));
		}
	}
if (@userlines && $leftitems[0]->{'type'} eq 'hr') {
	# The separator after the text lines goes with them
	shift(@leftitems);
	}
if (!@userlines) {
	# Without a login line, show the username alone
	push(@userlines, "<b>".&html_escape($remote_user || $base_remote_user).
			 "</b>");
	}

# Add the search box and the links every menu ends with
push(@leftitems, &theme_menu_extra_items($mode, $sects, \%mtext));

# The page the mode switch and the menu fields come back to: the index of
# the current module, or the system information page on a theme page. The
# current page itself could repeat an action it ran, such as a module
# refresh, and would lose what was typed into it.
my $mod = &theme_menu_module();
my $return = $mod ? "/$mod/" : "/right.cgi";

# What the items need to build their HTML
my %ctx = ( 'single' => $single,
	    'mode' => $mode,
	    'in' => \%min,
	    'return' => $return,
	    'text' => \%mtext );
if ($single) {
	# In the single page layout, the link to the current page is marked
	# and its categories opened
	my ($active, $cats) = &theme_menu_active(\@leftitems, $mode);
	$ctx{'active'} = $active;
	$ctx{'open'} = { map { $_, 1 } @$cats };
	}

# In the single page layout, remember what the menu shows, so pages of
# other modules keep it. The script that does it follows the panel, and
# the panel carries the cookie for the menu script.
my ($remember, $cookie);
if ($single) {
	my %new = ( %$state, 'mode' => $mode );
	foreach my $k ('dom', 'sid') {
		$new{$k} = $sel->{$k} if ($sel->{$k} ne '');
		}
	$remember = &theme_menu_remember(\%new);
	$cookie = &theme_menu_cookie_string(\%new);
	}

# The product for the logo, and the URL prefix for links
my ($prod, $prodname) = &theme_menu_product(\%mtext);
my $pfx = &get_webprefix();
my $h = "";

# The whole menu sits in one panel that floats on the page ground
if ($single) {
	# An aside element, labelled with the product name for screen readers.
	# The script keeps a scroll position for each mode.
	$h .= "<aside class='menu-panel page-menu' id='page-menu' ".
	      "data-mode='".&html_escape($mode)."' ".
	      "data-cookie='".&html_escape($cookie)."' ".
	      "aria-label='".&html_escape($prodname)."'>\n";
	}
else {
	# The only content of the left frame
	$h .= "<div class='menu-panel'>\n";
	}

# The brand block and the product switch stay at the top of the panel
# while the menu scrolls under them. The loader is the bar that bounces
# along the top edge while a page loads.
$h .= "<div class='menu-top'>\n";
$h .= "<div class='menu-loader'></div>\n";

# The brand block, with the product logo in light and dark versions for
# the stylesheet to choose from
my $imgdir = "$pfx/images";
my $alt = &html_escape($prodname);
$h .= "<div class='menu-brand'>\n";
$h .= "<a class='menu-brand-name' href='$pfx/right.cgi'".
      ($single ? "" : " target='right'")." title='$alt'>";
$h .= "<img class='menu-brand-logo' src='$imgdir/logos/$prod.svg' ".
      "alt='$alt'>";
$h .= "<img class='menu-brand-logo menu-brand-logo-dark' ".
      "src='$imgdir/logos/$prod-dark.svg' alt='$alt'>";
$h .= "</a>\n";
if ($single) {
	# On a narrow screen the menu folds into a bar, and this button
	# opens it
	$h .= "<button type='button' class='menu-toggle' ".
	      "aria-controls='page-menu' aria-expanded='false' ".
	      "aria-label='".&html_escape($mtext{'left_menu'})."'>".
	      "<svg class='menu-toggle-open' width='18' height='18' ".
	      "viewBox='0 0 16 16' fill='none' stroke='currentColor' ".
	      "stroke-width='1.5' stroke-linecap='round' aria-hidden='true'>".
	      "<path d='M2.5 4h11M2.5 8h11M2.5 12h11'/></svg>".
	      &ui_svg_icon('x', { 'size' => 18,
				  'class' => 'menu-toggle-close' }).
	      "</button>\n";
	}
# The host and the login, as small lines with icons
$h .= "<div class='menu-meta'>\n";
$h .= "<div class='menu-host'>".&ui_svg_icon('server', { 'size' => 13 }).
      "<span>".&html_escape(&get_display_hostname())."</span></div>\n";
foreach my $l (@userlines) {
	$h .= "<div class='menu-user'>".&ui_svg_icon('user', { 'size' => 13 }).
	      "<span>$l</span></div>\n";
	}
$h .= "</div>\n";
$h .= "</div>\n";

# The product switch, when there is more than one mode
if (@has > 1) {
	$h .= "<div class='mode'>";
	foreach my $m (@has) {
		$h .= "<b data-mode='$m->{'id'}'>";
		if ($m->{'id'} ne $mode) {
			# The click marks the switch as loading until the
			# new menu is shown. In the single page layout the
			# menu script does it, and skips clicks that open a
			# new tab.
			my $link = &theme_menu_mode_link($m->{'id'}, \%ctx,
							 \%page, \%hasmode);
			$h .= "<a href='$link'".($single ? "" :
			      " onclick=\"this.parentNode.parentNode.".
			      "classList.add('loading');".
			      "this.parentNode.classList.add('active')\"").">";
			}
		$h .= $m->{'desc'};
		if ($m->{'id'} ne $mode) {
			# Close the link of an unselected mode
			$h .= "</a>";
			}
		$h .= "</b>\n";
		}
	$h .= "</div>\n";
	}
# End of the block that stays at the top
$h .= "</div>\n";

# The menu items
$h .= "<div class='leftmenu'>\n";
$h .= &theme_menu_items_html(\@leftitems, 0, \%ctx);
$h .= "</div>\n";
$h .= $single ? "</aside>\n" : "</div>\n";

if ($single && !$opts->{'fragment'}) {
	# The script that stores the choices, and the one that runs the menu
	$h .= $remember;
	$h .= &theme_menu_script();
	}
return $h;
}

# theme_menu_module()
# Returns the module of the page the menu is for: the current module, or
# the module menu.cgi was told about when it builds the menu of a page that
# loads it
sub theme_menu_module
{
return defined($main::gray_theme_menu_module) ?
	$main::gray_theme_menu_module : &get_module_name();
}

# theme_menu_placeholder()
# Returns an empty menu panel and the menu script, for a page that runs as
# a Unix user other than root, such as File Manager for a domain owner.
# That user cannot read the data the menu is built from, so the script
# loads the menu from menu.cgi, which runs as root, for this page: its
# address, module and the page the browser came from.
sub theme_menu_placeholder
{
my %mtext = &load_language($current_theme);
my $src = &get_webprefix()."/menu.cgi?fragment=1".
	  "&page=".&urlize($ENV{'REQUEST_URI'}).
	  "&module=".&urlize(&get_module_name());
return "<aside class='menu-panel page-menu' id='page-menu' ".
       "data-src='".&html_escape($src)."' ".
       "aria-label='".&html_escape($mtext{'left_menu'})."'></aside>\n".
       &theme_menu_script();
}

# theme_menu_page()
# Returns what the current page implies for the menu of the single page
# layout, as a hash: the mode of its module, and the domain or system it
# shows. Virtualmin plugins go with the Virtualmin menu.
sub theme_menu_page
{
my %page;
my $mod = &theme_menu_module();
if ($mod eq 'virtual-server' || $mod =~ /^virtualmin-/) {
	# A Virtualmin page, usually for the domain in its dom parameter
	$page{'mode'} = 'virtual-server';
	$page{'dom'} = $in{'dom'} if ($in{'dom'} =~ /^\d+$/);
	}
elsif ($mod eq 'server-manager') {
	# A Cloudmin page, usually for the system in its id parameter
	$page{'mode'} = $mod;
	$page{'sid'} = $in{'id'} if ($in{'id'} =~ /^\d+$/);
	}
elsif ($mod) {
	# Any other module, whose own menu is used if it has one
	$page{'mode'} = $mod;
	}
return %page;
}

# theme_menu_selection(&items)
# Returns the domain and the managed system that the menu fields show, as a
# hash ref with dom and sid keys. A key is missing when no field shows one.
sub theme_menu_selection
{
my ($items) = @_;
my %sel;
foreach my $i (@$items) {
	if ($i->{'type'} eq 'menu' && $i->{'name'} =~ /^(dom|sid)$/) {
		# A menu of domains or of systems
		$sel{$1} = $i->{'value'};
		}
	elsif ($i->{'type'} eq 'input' && $i->{'name'} eq 'dname') {
		# The domain name field used when there are too many domains
		# for a menu
		$sel{'dom'} = $i->{'domid'};
		}
	}
return \%sel;
}

# theme_menu_master()
# Returns 1 if the user is the master administrator. Virtualmin and Cloudmin
# each have their own test for it.
sub theme_menu_master
{
if (&foreign_available("virtual-server")) {
	# Virtualmin's master admin
	&foreign_require("virtual-server");
	return &virtual_server::master_admin();
	}
elsif (&foreign_available("server-manager")) {
	# Cloudmin's user with global permissions
	&foreign_require("server-manager");
	return &server_manager::can_action(undef, "global");
	}
return 0;
}

# theme_menu_product([&text])
# Returns the product whose logo the menu shows, and its name: Cloudmin or
# Virtualmin when the user has it, else Usermin or Webmin. The optional
# text is the theme's language strings, which are loaded when not given.
sub theme_menu_product
{
my ($mtext) = @_;
$mtext ||= { &load_language($current_theme) };
my $prod = &foreign_available("server-manager") ? 'cloudmin' :
	   &foreign_available("virtual-server") ? 'virtualmin' :
	   &get_product_name() eq 'usermin' ? 'usermin' : 'webmin';
my %names = ( 'cloudmin' => $mtext->{'has_vm2'},
	      'virtualmin' => $mtext->{'has_virtualmin'},
	      'usermin' => $mtext->{'has_usermin'},
	      'webmin' => $mtext->{'has_webmin'} );
return ($prod, $names{$prod});
}

# theme_menu_extra_items(mode, &settings, &text)
# Returns the items every menu ends with: the module search box in the
# Webmin mode, then the links to the system information page, to refresh
# the modules, to log out and back to the original Webmin server
sub theme_menu_extra_items
{
my ($mode, $sects, $mtext) = @_;
my @rv;

# The module search box, unless the global ACL or the theme settings hide
# it. The global ACL is read here, as the core keeps no global copy of it.
my %gacl = &get_module_acl(undef, "");
if ($mode eq "modules" && $gacl{'webminsearch'} ne '0' &&
    !$sects->{'nosearch'}) {
	push(@rv, { 'type' => 'input',
		    'desc' => ' ',
		    'tags' => " placeholder='$mtext->{'left_search'}'",
		    'size' => 10,
		    'name' => 'search',
		    'cgi' => '/webmin_search.cgi', });
	push(@rv, { 'type' => 'hr' });
	}

# The system information link
push(@rv, { 'type' => 'item',
	    'id' => 'home',
	    'desc' => $mtext->{'left_home'},
	    'link' => '/right.cgi' });

# The link to refresh the modules, in the Webmin mode for users of the
# Webmin Configuration module
if ($mode eq "modules" && &foreign_available("webmin")) {
	push(@rv, { 'type' => 'item',
		    'id' => 'refresh',
		    'desc' => $mtext->{'main_refreshmods'},
		    'link' => '/webmin/refresh_modules.cgi' });
	}

# The logout link, when the web server allows logging out and the login
# did not come from a certificate, the local host or a Webmin tool
my %miniserv;
&get_miniserv_config(\%miniserv);
if ($miniserv{'logout'} && !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	my $logout = { 'type' => 'item',
		       'id' => 'logout',
		       'target' => 'window' };
	if ($main::session_id) {
		# Session logins can log out
		$logout->{'desc'} = $mtext->{'main_logout'};
		$logout->{'link'} = '/session_login.cgi?logout=1';
		}
	else {
		# Other logins can only switch to another user
		$logout->{'desc'} = $mtext->{'main_switch'};
		$logout->{'link'} = '/switch_user.cgi';
		}
	push(@rv, $logout);
	}

# A link back to the Webmin Servers Index, when this server was opened
# through it
if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
	push(@rv, { 'type' => 'item',
		    'desc' => $mtext->{'header_servers'},
		    'link' => $ENV{'HTTP_WEBMIN_SERVERS'},
		    'target' => 'window' });
	}
return @rv;
}

# theme_menu_active(&items, mode)
# Returns the link item that best matches the current page and the IDs of
# the categories that hold it, or nothing when no link matches. Each link
# gets a score, and the highest wins; of equal scores, the first link in
# the menu wins:
#   5 - a link to this exact page
#   4 - a link to the same script with other parameters
#   3 - a link to the index of the page's module, such as Scheduled Cron
#       Jobs for any Cron page. Not for the module of the shown menu, as
#       Virtualmin's index is its list of domains, not the whole module.
#   2 - a link to the exact page the browser came from, so the result of a
#       saved form marks the link of the form's page
#   1 - a link to the same script as the page the browser came from
sub theme_menu_active
{
my ($items, $mode) = @_;
my $mod = &theme_menu_module();

# The current page and the page the browser came from, each as its full
# path and query, its script as theme_menu_script_key gives it, and its
# score for an exact match
my @pages;
foreach my $p ([ $ENV{'REQUEST_URI'}, 5 ], [ &theme_menu_referer(), 2 ]) {
	my ($uri, $score) = @$p;
	next if ($uri eq '');
	push(@pages, [ $uri, &theme_menu_script_key($uri), $score ]);
	}

# Walk the items in menu order, each with the IDs of the categories that
# hold it
my ($best, $bestcats, $bestscore) = (undef, [ ], 0);
my @queue = map { [ $_, [ ] ] } @$items;
while(my $q = shift(@queue)) {
	my ($i, $cats) = @$q;
	if ($i->{'type'} eq 'cat') {
		# Look inside the category, before the items after it
		unshift(@queue, map { [ $_, [ @$cats, $i->{'id'} ] ] }
				    @{$i->{'members'}});
		next;
		}
	# Only links to pages of this server can match
	next if ($i->{'type'} ne 'item' || $i->{'link'} eq '' ||
		 $i->{'link'} =~ /^(#|[a-z][a-z0-9+.\-]*:)/i);
	# A relative link is taken from the server root, as theme_menu_url does
	my $link = $i->{'link'} =~ /^\// ? $i->{'link'} : "/".$i->{'link'};
	my $lpath = &theme_menu_script_key($link);
	# The link's best score against both pages; a match of the script
	# alone scores one less than an exact match
	my $score = 0;
	foreach my $p (@pages) {
		my $s = $link eq $p->[0] ? $p->[2] :
			$lpath eq $p->[1] ? $p->[2] - 1 : 0;
		$score = $s if ($s > $score);
		}
	if ($score < 3 && $mod && $mod ne $mode && $lpath eq "/$mod/") {
		# The index of the page's module, which says more about where
		# the page belongs than the page the browser came from
		$score = 3;
		}
	if ($score > $bestscore) {
		# The best match so far
		($best, $bestcats, $bestscore) = ($i, $cats, $score);
		}
	}
return ($best, $bestcats);
}

# theme_menu_script_key(url)
# Returns what names the script of a path and query for the same-script
# match: the path, with index.cgi dropped. The module configuration pages
# config.cgi and uconfig.cgi serve every module, so for them the module,
# given as the whole query or as module=, is part of it. Otherwise the
# settings page of Cron would match Virtualmin's own Module Config link.
sub theme_menu_script_key
{
my ($url) = @_;
my ($path, $query) = split(/\?/, $url, 2);
$path =~ s/\/index\.cgi$/\//;
if ($path =~ /\/u?config\.cgi$/) {
	# The module, from module= or from a query of just its name
	my $m = $query =~ /(?:^|&)module=([\w\-]+)/ ? $1 :
		$query =~ /^([\w\-]+)(?:&|$)/ ? $1 : "";
	$path .= "?".$m;
	}
return $path;
}

# theme_menu_referer()
# Returns the path and query of the page the browser came from, without
# the URL prefix, if it is a page of this server; otherwise an empty
# string. The server is the host the browser asked for, or behind a proxy
# that does not pass that on, the host Webmin redirects to or a host in
# its list of trusted referers.
sub theme_menu_referer
{
return "" if ($ENV{'HTTP_REFERER'} !~ /^https?:\/\/([^\/]+)(\/[^#]*)?/i);
my ($host, $uri) = (lc($1), $2 || "/");
if ($host ne lc($ENV{'HTTP_HOST'})) {
	# Compare the host name alone with the names Webmin knows
	my %miniserv;
	&get_miniserv_config(\%miniserv);
	(my $name = $host) =~ s/:\d+$//;
	return "" if (&indexoflc($name, $miniserv{'redirect_host'},
				 split(/\s+/, $gconfig{'referers'})) < 0);
	}
my $wp = &get_webprefix();
$uri =~ s/^\Q$wp\E(?=\/)// if ($wp);
return $uri;
}

# theme_menu_mode_link(mode, &context, &page, &modes)
# Returns the address of a link in the product switch. In the left frame it
# reloads the menu in the new mode. In the single page layout it saves the
# mode and opens the current module's index. If that module belongs to
# another mode, which would switch the menu back, it opens the system
# information page instead.
sub theme_menu_mode_link
{
my ($mode, $ctx, $page, $hasmode) = @_;
my $pfx = &get_webprefix();
return "$pfx/left.cgi?mode=".&urlize($mode) if (!$ctx->{'single'});
my $return = $hasmode->{$page->{'mode'}} && $page->{'mode'} ne $mode ?
		"/right.cgi" : $ctx->{'return'};
return "$pfx/menu.cgi?mode=".&urlize($mode)."&amp;return=".&urlize($return);
}

# theme_menu_items_html(&items, indent, &context)
# Returns the HTML for a list of menu items. In the left frame, links and
# forms open their pages in the right frame. In the single page layout they
# open in the same window, and fields work without forms, as described at
# theme_menu_field_html.
sub theme_menu_items_html
{
my ($items, $indent, $ctx) = @_;
my $single = $ctx->{'single'};
my $h = "";
foreach my $item (@$items) {
	if ($item->{'type'} eq 'item') {
		# Link to some page
		my $it = $item->{'target'} || '';
		my $t = $it eq 'new' ? '_blank' :
			$it eq 'window' ? '_top' :
			$single ? '' : 'right';
		my $link = &theme_menu_url($item->{'link'});
		if ($item->{'link'} =~ /^(https?):\/\//) {
			# Links to other sites open in a new window
			$t = '_blank';
			$link = $item->{'link'};
			}
		my $cls;
		my $desc = $item->{'desc'};
		if ($item->{'format'} eq 'link-new') {
			# Creation link shown as a button with a plus
			$cls = 'menu-create';
			$desc = &ui_svg_icon('plus', { 'size' => 15 })." ".$desc;
			}
		else {
			# Ordinary link, indented inside a category and muted
			# when inactive
			$cls = 'menu-link';
			$cls .= ' menu-sub' if ($indent);
			$cls .= ' inactive' if ($item->{'inactive'});
			if ($item->{'id'} eq 'home') {
				# The system information link, which the menu
				# does not scroll to
				$cls .= ' menu-home';
				}
			elsif ($item->{'id'} eq 'logout') {
				# Logout gets an icon and a muted look
				$cls .= ' menu-logout';
				$desc = &ui_svg_icon('power', { 'size' => 14 }).
					" ".$desc;
				}
			}
		# The link to the current page is highlighted, and marked for
		# screen readers
		my $active = $ctx->{'active'} && $item == $ctx->{'active'};
		$cls .= ' active' if ($active);
		$h .= "<a class='$cls' href='$link'".
		      ($t ? " target='$t'" : "").
		      ($active ? " aria-current='page'" : "").
		      ">$desc</a>\n";
		}
	elsif ($item->{'type'} eq 'cat') {
		# Start of a new category, opened when the left frame's caller
		# asks for it or when it holds the marked link
		my $c = $item->{'id'};
		my $open = $ctx->{'in'}->{$c} || $ctx->{'open'}->{$c};
		$h .= "<details class='menu-cat' data-cat='".
		      &html_escape($c)."'".($open ? " open" : "").">";
		$h .= "<summary><span>$item->{'desc'}</span></summary>\n";
		$h .= &theme_menu_items_html($item->{'members'}, $indent+1, $ctx);
		$h .= "</details>\n";
		}
	elsif ($item->{'type'} eq 'html') {
		# Some HTML block
		$h .= "<div class='menu-html'>".$item->{'html'}."</div>\n";
		}
	elsif ($item->{'type'} eq 'text') {
		# A line of text
		$h .= "<div class='menu-text'>".
		      &html_escape($item->{'desc'})."</div>\n";
		}
	elsif ($item->{'type'} eq 'hr') {
		# Separator line
		$h .= "<hr class='menu-divider'>\n";
		}
	elsif (($item->{'type'} eq 'menu' || $item->{'type'} eq 'input') &&
	       $single) {
		# A field of the single page layout, without a form
		$h .= &theme_menu_field_html($item, $ctx);
		}
	elsif ($item->{'type'} eq 'menu' || $item->{'type'} eq 'input') {
		# Form with an input of some kind
		if ($item->{'cgi'}) {
			# The form submits to the item's CGI
			my $cgi = &theme_menu_url($item->{'cgi'});
			$h .= "<form class='menu-form' action='$cgi' ".
			      "target='right'>\n";
			}
		else {
			# Without a CGI, the form reloads this menu with the
			# new value
			$h .= "<form class='menu-form'>\n";
			}
		foreach my $hd (@{$item->{'hidden'}}) {
			$h .= &ui_hidden(@$hd);
			}
		$h .= &ui_hidden("mode", $ctx->{'mode'});
		my $label = $item->{'desc'} =~ /\S/ ?
			$item->{'desc'} : $ctx->{'text'}->{'left_'.$item->{'name'}};
		if ($label) {
			# Small caps label above the field
			$h .= "<label class='menu-label' for='".
			      &html_escape($item->{'name'})."'>$label</label>\n";
			}
		$h .= "<div class='menu-field'>\n";
		if ($item->{'type'} eq 'menu') {
			# A drop-down that submits as soon as it changes
			my $sel = "";
			if ($item->{'onchange'}) {
				# Some menus also load a page for the chosen
				# value in the right frame
				$sel = "window.parent.frames[1].location = ".
				       "\"$item->{'onchange'}\" + this.value";
				}
			$h .= &ui_select($item->{'name'}, $item->{'value'},
					 $item->{'menu'}, 1, 0, 0, 0,
					 "onChange='form.submit(); $sel'");
			}
		elsif ($item->{'type'} eq 'input') {
			# A text field, such as the search box
			$h .= &ui_textbox($item->{'name'}, $item->{'value'},
					  $item->{'size'}, undef, undef,
					  $item->{'tags'});
			}
		$h .= "</div>\n";
		$h .= "</form>\n";
		}
	}
return $h;
}

# theme_menu_field_html(&item, &context)
# Returns the HTML for a drop-down or a text field of the menu in the single
# page layout. The menu shares the page with the page's own forms, and
# scripts of the theme and of modules use document.forms[0] and element IDs
# such as dom, so the field has no form and its ID has a prefix. The menu
# script opens the field's address with the value added, as soon as a
# drop-down changes or on Enter in a text field. A field without a CGI goes
# to menu.cgi, which remembers the value and opens a page for it: the one
# the item names, or else a page showing the domain or system.
sub theme_menu_field_html
{
my ($item, $ctx) = @_;
# An ID with a prefix, which no page element uses
my $name = $item->{'name'};
my $id = "menu-field-$name";
$id =~ s/[^\w\-]/_/g;

# The address the value is added to, with the item's fixed values
my ($action, @params);
if ($item->{'cgi'}) {
	# The item's own CGI, such as the module search
	$action = &theme_menu_url($item->{'cgi'});
	}
else {
	# menu.cgi, which also needs the page to return to
	$action = &get_webprefix()."/menu.cgi";
	push(@params, [ 'return', $ctx->{'return'} ]);
	if ($item->{'onchange'}) {
		# The page the item opens for a chosen value
		push(@params, [ 'goto', $item->{'onchange'} ],
			      [ 'field', $name ]);
		}
	}
# The item's hidden values and the menu mode go with every value, like the
# hidden inputs of the left frame's form. The script reads the address and
# the name of the value from data attributes. The browser does not refill
# the field when it shows the page again from its history.
push(@params, @{$item->{'hidden'} || [ ]}, [ 'mode', $ctx->{'mode'} ]);
my $url = $action."?".join("&", map { &urlize($_->[0])."=".&urlize($_->[1]) }
				    @params);
my $data = "data-url='".&html_escape($url)."' ".
	   "data-name='".&html_escape($name)."' autocomplete='off'";

my $h = "";
my $label = $item->{'desc'} =~ /\S/ ?
	$item->{'desc'} : $ctx->{'text'}->{'left_'.$name};
if ($label) {
	# Small caps label above the field
	$h .= "<label class='menu-label' for='$id'>$label</label>\n";
	}
$h .= "<div class='menu-field'>\n";
if ($item->{'type'} eq 'menu') {
	# A drop-down, built like ui_select builds one
	$h .= "<select class='ui_select' id='$id' $data>\n";
	foreach my $o (@{$item->{'menu'}}) {
		$o = [ $o ] if (!ref($o));
		$h .= "<option value=\"".&quote_escape($o->[0])."\"".
		      ($o->[0] eq $item->{'value'} ? " selected" : "").
		      ($o->[2] ne '' ? " ".$o->[2] : "").">".
		      &html_escape($o->[1] || $o->[0], 1)."</option>\n";
		}
	$h .= "</select>\n";
	}
else {
	# A text field, such as the search box
	$h .= "<input type='text' class='ui_textbox' id='$id' $data ".
	      "value=\"".&quote_escape($item->{'value'})."\"".
	      ($item->{'size'} ? " size='".int($item->{'size'})."'" : "").
	      ($item->{'tags'} ? " ".$item->{'tags'} : "").">\n";
	}
$h .= "</div>\n";
return "<div class='menu-form'>\n$h</div>\n";
}

# theme_menu_url(link)
# Returns a menu link ready for a page: a path gets the URL prefix, and a
# relative link, such as server-manager/list_keys.cgi in the Cloudmin menu,
# is taken from the server root, as it is in the left frame. Links with a
# scheme or to an anchor stay as they are.
sub theme_menu_url
{
my ($link) = @_;
return $link if ($link eq '' || $link =~ /^#/ ||
		 $link =~ /^[a-z][a-z0-9+.\-]*:/i);
$link = "/".$link if ($link !~ /^\//);
return &get_webprefix().$link;
}

# theme_menu_local_url(url)
# Returns 1 if a URL is a path on this server, which the menu may send the
# browser to: it starts with a single slash and has no spaces or
# backslashes
sub theme_menu_local_url
{
my ($url) = @_;
return $url =~ /^\/(?![\/\\])[^\s\\]*$/ ? 1 : 0;
}

# theme_menu_script()
# Returns the script that runs the menu of the single page layout. On a
# page with the empty panel of theme_menu_placeholder, it loads the menu
# first. It opens the page of a menu field when its value is chosen, shows
# the loader bar while the browser goes to another page of this server,
# opens and closes the menu on a narrow screen, and keeps the menu as the
# user left it on the last page of this tab: the categories opened or
# closed, and the scroll position of each mode. A category holding the
# current page always stays open, and the current page's link is scrolled
# into view, unless it is the system information link at the end of the
# menu: scrolling to it would hide the top of the menu, such as the
# Virtualmin domain menu. It also
# puts this tab's menu choices back into the cookie whenever the tab comes
# back into use, so a choice made in another tab does not take over.
sub theme_menu_script
{
return <<'EOF';
<script type='text/javascript'>
(function() {
var menu = document.getElementById('page-menu'),
    root = document.documentElement, key = 'gray-theme-menu', saved = { },
    timer;
// Nothing to run on a page without the menu
if (!menu) return;

// A page that runs as another Unix user has an empty panel, and loads
// the menu from menu.cgi, telling it the page the browser came from. The
// loaded panel replaces the empty one, then the menu starts. If loading
// fails, the page stays without a menu.
var src = menu.getAttribute('data-src');
if (src) {
	fetch(src + '&ref=' + encodeURIComponent(document.referrer),
	      { credentials: 'same-origin' })
	.then(function(r) { return r.ok ? r.text() : ''; })
	.then(function(html) {
		var box = document.createElement('div');
		box.innerHTML = html;
		var panel = box.querySelector('#page-menu');
		if (!panel) return;
		menu.parentNode.replaceChild(panel, menu);
		menu = panel;
		run();
		})
	.catch(function() { });
	}
else {
	run();
	}

// Runs the menu
function run() {
	// The choices of this page, unless a script of the page has set them
	if (!window.grayThemeMenuCookie)
		window.grayThemeMenuCookie = menu.getAttribute('data-cookie');

	// The loader bar runs from a click that leaves the page until the next
	// page replaces it. It stops after 20 seconds anyway, such as after a
	// download.
	function start() {
		root.classList.add('loading-right');
		clearTimeout(timer);
		timer = setTimeout(stop, 20000);
		}
	function stop() {
		root.classList.remove('loading-right');
		clearTimeout(timer);
		}
	// Links to another page of this server in this window start it, unless
	// a script of the page cancels the click. Links to other sites, mail
	// addresses, anchors on this page and new windows do not.
	document.addEventListener('click', function(e) {
		var a = e.target.closest ? e.target.closest('a[href]') : null;
		if (!a || e.button || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey ||
		    a.target && a.target != '_self' || a.hasAttribute('download') ||
		    a.protocol != location.protocol || a.host != location.host ||
		    a.pathname == location.pathname && a.search == location.search &&
		    a.hash) return;
		// A pill of the product switch reads as chosen, with a spinner,
		// until the new menu is shown
		var pill = a.closest('.mode > b');
		if (pill) {
			pill.parentNode.classList.add('loading');
			pill.classList.add('active');
			}
		setTimeout(function() { if (!e.defaultPrevented) start(); }, 0);
		});
	// So do forms submitted in this window
	document.addEventListener('submit', function(e) {
		var f = e.target;
		if (f.target && f.target != '_self') return;
		setTimeout(function() { if (!e.defaultPrevented) start(); }, 0);
		});

	// A menu field opens its page with the value added to the address: a
	// drop-down when it changes, a text field on Enter
	function go(field) {
		var url = field.getAttribute('data-url');
		start();
		location.href = url + (url.indexOf('?') < 0 ? '?' : '&') +
			encodeURIComponent(field.getAttribute('data-name')) + '=' +
			encodeURIComponent(field.value);
		}
	menu.addEventListener('change', function(e) {
		if (e.target.matches('select[data-url]')) go(e.target);
		});
	// An Enter that confirms the text of an input method, such as for
	// Japanese, does not count
	menu.addEventListener('keydown', function(e) {
		if (e.key != 'Enter' || e.isComposing || e.keyCode == 229 ||
		    !e.target.matches('input[data-url]')) return;
		e.preventDefault();
		go(e.target);
		});

	// The button that opens the menu on a narrow screen, and the Escape key
	// that closes it
	var button = menu.querySelector('.menu-toggle');
	function toggle(open) {
		menu.classList.toggle('open', open);
		if (button) button.setAttribute('aria-expanded', open ? 'true' : 'false');
		}
	if (button) button.addEventListener('click', function() {
		toggle(!menu.classList.contains('open'));
		});
	document.addEventListener('keydown', function(e) {
		if (e.key == 'Escape' && menu.classList.contains('open')) toggle(false);
		});

	// The choices of this tab, which the page's scripts set, go back into
	// the cookie when the tab comes back into use
	function own() {
		if (window.grayThemeMenuCookie) document.cookie = window.grayThemeMenuCookie;
		}
	window.addEventListener('focus', own);
	document.addEventListener('visibilitychange', function() {
		if (!document.hidden) own();
		});

	// When the browser restores this page from its history, it is left as
	// it was when the user clicked away. Stop the loader, fold the menu,
	// free the product switch and put the fields back to what the page
	// showed.
	window.addEventListener('pageshow', function(e) {
		if (!e.persisted) return;
		stop();
		toggle(false);
		own();
		var sw = menu.querySelector('.mode'), f, i, j;
		if (sw) {
			// The switch, without the spinner of the click
			sw.classList.remove('loading');
			var pills = sw.querySelectorAll('b.active');
			for (i = 0; i < pills.length; i++) pills[i].classList.remove('active');
			}
		var fields = menu.querySelectorAll('[data-url]');
		for (i = 0; i < fields.length; i++) {
			f = fields[i];
			if (f.options) {
				// A drop-down shows its first selected option
				// again
				for (j = 0; j < f.options.length; j++)
					if (f.options[j].defaultSelected) f.selectedIndex = j;
				}
			else {
				// A text field shows its first value again
				f.value = f.defaultValue;
				}
			}
		});

	// Categories as the user left them, apart from the one holding the
	// current page
	try { saved = JSON.parse(sessionStorage.getItem(key)) || { }; } catch(e) { }
	saved.cats = saved.cats || { };
	var cats = menu.querySelectorAll('details.menu-cat[data-cat]');
	for (var i = 0; i < cats.length; i++) {
		var c = cats[i], id = c.getAttribute('data-cat');
		if (id in saved.cats && !c.querySelector('.active')) c.open = saved.cats[id];
		}
	menu.addEventListener('toggle', function(e) {
		var c = e.target;
		if (!c.matches || !c.matches('details.menu-cat[data-cat]')) return;
		saved.cats[c.getAttribute('data-cat')] = c.open;
		store();
		}, true);

	// The scroll position of the menu in this mode, with the current page's
	// link in view
	var mode = menu.getAttribute('data-mode');
	saved.tops = saved.tops || { };
	if (saved.tops[mode]) menu.scrollTop = saved.tops[mode];
	var active = menu.querySelector('.menu-link.active:not(.menu-home)'),
	    top = menu.querySelector('.menu-top');
	if (active) {
		// Scroll just enough to show the link below the block that
		// stays at the top, or above the bottom edge
		var a = active.getBoundingClientRect(), m = menu.getBoundingClientRect(),
		    above = m.top + (top ? top.offsetHeight : 0);
		if (a.top < above) menu.scrollTop -= above - a.top + 8;
		else if (a.bottom > m.bottom) menu.scrollTop += a.bottom - m.bottom + 8;
		}
	// The position is saved when the browser leaves the page
	window.addEventListener('pagehide', function() {
		saved.tops[mode] = menu.scrollTop;
		store();
		});
	// Saves the menu state for this tab. Storage can be unavailable, such
	// as when the browser blocks it.
	function store() {
		try { sessionStorage.setItem(key, JSON.stringify(saved)); } catch(e) { }
		}
	}
})();
</script>
EOF
}

1;
