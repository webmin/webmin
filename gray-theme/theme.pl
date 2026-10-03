# Virtualmin Framed Theme
# Icons copyright David Vignoni, all other theme elements copyright 2005-2007
# Virtualmin, Inc.

$main::cloudmin_no_create_links = 1;
$main::cloudmin_no_edit_buttons = 1;
$main::cloudmin_no_global_links = 1;

$main::mailbox_no_addressbook_button = 1;
$main::mailbox_no_folder_button = 1;

$main::basic_virtualmin_menu = 1;
$main::basic_virtualmin_domain = 1;
$main::nocreate_virtualmin_menu = 1;
$main::nosingledomain_virtualmin_mode = 1;

our $ui_formcount;

# The functions that read the theme settings, unless the core has already
# loaded them into this package
do "$theme_root_directory/theme-init.pl" if (!defined(&theme_settings));

# Global state for wrapper
# if 0, wrapper isn't on, add one and open it, if 1 close it, if 2+, subtract
# but don't close
$main::WRAPPER_OPEN = 0;
$main::COLUMNS_WRAPPER_OPEN = 0;

# theme_ui_print_header(subtext, header-args...)
# Prints the page header like the core, but wraps the text under the
# title in a span of its own, then prints the subtext block
sub theme_ui_print_header
{
my ($text, @args) = @_;
if ($args[9] ne '') {
	# Text under the title, such as a version, gets an element of its own
	# so the stylesheet can make it smaller
	$args[9] = "<span class='ui_header_below'>$args[9]</span>";
	}
&header(@args);
print &ui_post_header($text);
}

# theme_ui_post_header([subtext])
# Returns HTML to appear directly after a standard header() call
sub theme_ui_post_header
{
my ($text) = @_;
my $rv;
$rv .= "<div class='ui_post_header'>$text</div>\n" if (defined($text));
$rv .= "<p></p>" if (!defined($text));
return $rv;
}

# theme_ui_pre_footer()
# Returns HTML to appear directly before a standard footer() call
sub theme_ui_pre_footer
{
my $rv;
$rv .= "<p></p>\n";
return $rv;
}

# ui_print_footer(args...)
# Print HTML for a footer with the pre-footer line. Args are the same as those
# passed to footer()
sub theme_ui_print_footer
{
local @args = @_;
print &ui_pre_footer();
if ($ui_formcount) {
  print <<EOL;
  <script>
    (function(){
        var forms = document.forms || [];
        for(var i = 0; i < forms.length; i++){
            for(var j = 0; j < forms[i].length; j++){
                if(!forms[i][j].readonly != undefined && forms[i][j].type != "hidden" && forms[i][j].disabled != true && forms[i][j].style.display != 'none'){
                    forms[i][j].focus();
                    return;
                }
            }
        }
    })();
</script>
EOL
}
&footer(@args);
}

sub theme_icons_table
{
my ($i, $need_tr);
my $cols = $_[3] ? $_[3] : 4;
my $per = int(100.0 / $cols);
print "<div class='wrapper'>\n";
print "<table id='main' width=100% cellpadding=5 class='icons_table'>\n";
for($i=0; $i<@{$_[0]}; $i++) {
	if ($i%$cols == 0) { print "<tr>\n"; }
	print "<td width=$per% align=center valign=top>\n";
	&generate_icon($_[2]->[$i], $_[1]->[$i], $_[0]->[$i],
		       $_[4], $_[5], $_[6], $_[7]->[$i], $_[8]->[$i]);
	print "</td>\n";
        if ($i%$cols == $cols-1) { print "</tr>\n"; }
        }
while($i++%$cols) { print "<td width=$per%></td>\n"; $need_tr++; }
print "</tr>\n" if ($need_tr);
print "</table>\n";
print "</div>\n";
}

sub theme_generate_icon
{
my $w = !defined($_[4]) ? "width=48" : $_[4] ? "width=$_[4]" : "";
my $h = !defined($_[5]) ? "height=48" : $_[5] ? "height=$_[5]" : "";
if ($tconfig{'noicons'}) {
	if ($_[2]) {
		print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
		}
	else {
		print "$_[6]$_[1]$_[7]\n";
		}
	}
elsif ($_[2]) {
	print "<table><tr><td width=48 height=48>\n",
	      "<a href=\"$_[2]\" $_[3]><img src=\"$_[0]\" alt=\"\" border=0 ",
	      "$w $h></a></td></tr></table>\n";
	print "$_[6]<a href=\"$_[2]\" $_[3]>$_[1]</a>$_[7]\n";
	}
else {
	print "<table><tr><td width=48 height=48>\n",
	      "<img src=\"$_[0]\" alt=\"\" border=0 $w $h>",
	      "</td></tr></table>\n$_[6]$_[1]$_[7]\n";
	}
}

# theme_post_save_domain(&domain, action)
# Called by Virtualmin after a domain is updated, to refresh the left menu.
# In the single page layout, a new domain becomes the one the menu shows.
sub theme_post_save_domain
{
local ($d, $action) = @_;
if (&theme_single_page()) {
	# The next page builds the menu again, showing a new domain
	print &theme_menu_remember({ 'dom' => $d->{'id'} })
		if ($action eq 'create');
	return;
	}
# Refresh left side, in case options have changed
print "<script>\n";
if ($action eq 'create') {
	# Select the new domain
	print "top.left.location = '@{[&get_webprefix()]}/left.cgi?mode=virtual-server&dom=$d->{'id'}';\n";
	}
else {
	# Just refresh left
	print "top.left.location = top.left.location;\n";
	}
print "</script>\n";
}

# theme_post_save_domains([domain, action]+)
# Called after multiple domains are updated, to refresh the left menu
sub theme_post_save_domains
{
# The single page layout builds the menu again on the next page
return if (&theme_single_page());
print "<script>\n";
print "top.left.location = top.left.location;\n";
print "</script>\n";
}

# theme_post_save_server(&server, action)
# Called by Cloudmin after a server is updated, to refresh the left menu
sub theme_post_save_server
{
local ($s, $action) = @_;
# The single page layout builds the menu again on the next page
return if (&theme_single_page());
if ($action eq 'create' || $action eq 'delete' ||
    !$done_theme_post_save_server++) {
	# Refresh the left frame after a system is added or removed, and once
	# per page otherwise
	print "<script>\n";
	print "top.left.location = top.left.location;\n";
	print "</script>\n";
	}
}

# theme_select_server(&server)
# Called by Cloudmin when a page for a server is displayed, to select it on
# the left menu. In the single page layout, the menu shows it from the next
# page on.
sub theme_select_server
{
local ($server) = @_;
if (&theme_single_page()) {
	# This page's menu is already built, so only remember the system for
	# the next pages
	print &theme_menu_remember({ 'sid' => $server->{'id'} });
	return;
	}
print <<EOF;
<script>
if (window.parent && window.parent.frames[0]) {
	var leftdoc = window.parent.frames[0].document;
	var leftform = leftdoc.forms[0];
	if (leftform) {
		var serversel = leftform['sid'];
		if (serversel && serversel.value != '$server->{'id'}' ||
		    !serversel) {
			//if (serversel) {
			//	// Need to change value of selector
			//	serversel.value = '$server->{'id'}';
			//	}
			window.parent.frames[0].location = '@{[&get_webprefix()]}/left.cgi?mode=server-manager&sid=$server->{'id'}';
			}
		}
	}
</script>
EOF
}

# theme_select_domain(&domain)
# Called by Virtualmin when a page for a domain is displayed, to select it
# on the left menu. In the single page layout, the menu shows it from the
# next page on.
sub theme_select_domain
{
local ($d) = @_;
if (&theme_single_page()) {
	# This page's menu is already built, so only remember the domain for
	# the next pages
	print &theme_menu_remember({ 'dom' => $d->{'id'} });
	return;
	}
print <<EOF;
<script>
if (window.parent && window.parent.frames[0]) {
	var leftdoc = window.parent.frames[0].document;
	var leftform = leftdoc.forms[0];
	if (leftform) {
		var domsel = leftform['dom'];
		if (domsel && domsel.value != '$d->{'id'}') {
			// Need to change value
			// domsel.value = '$d->{'id'}';
			window.parent.frames[0].location = '@{[&get_webprefix()]}/left.cgi?mode=virtual-server&dom=$d->{'id'}';
			}
		}
	}
</script>
EOF
}

# theme_post_save_folder(&folder, action)
# Called after some folder is changed, to refresh the left frame. The action
# may be 'create', 'delete', 'modify' or 'read'
sub theme_post_save_folder
{
local ($folder, $action) = @_;
# The single page layout builds the menu again on the next page
return if (&theme_single_page());
my $ref;
if ($action eq 'create' || $action eq 'delete' || $action eq 'modify') {
	# Always refresh
	$ref = 1;
	}
else {
	# Only refresh if showing unread count
	if (defined(&mailbox::should_show_unread) &&
	    &mailbox::should_show_unread($folder)) {
		$ref = 1;
		}
	}
if ($ref) {
	# Reload the left frame
	print "<script>\n";
	print "top.frames[0].document.location = top.frames[0].document.location;\n";
	print "</script>\n";
	}
}

# theme_post_change_modules()
# Called after modules are installed, removed or refreshed, to reload the
# left frame when it lists the Webmin modules
sub theme_post_change_modules
{
# The single page layout builds the menu again on the next page
return if (&theme_single_page());
print <<EOF;
<script>
var url = '' + top.left.location;
// Only the menu of the Webmin modules lists them
if (url.indexOf('mode=modules') > 0) {
    top.left.location = url;
    }
</script>
EOF
}

# theme_prebody(header-args...)
# Hides the module index link on Virtualmin pages, whose menu is already
# shown beside the page, and prints the menu of the single page layout
sub theme_prebody
{
if (get_module_name() eq "virtual-server") {
	# No need for Module Index link, as the menu already shows Virtualmin
	$tconfig{'nomoduleindex'} = 1;
	}
# Print the menu if theme_prehead chose to show it on this page
print &theme_page_menu() if ($main::gray_theme_page_menu);
}

# theme_popup_prebody(popup-header-args...)
# Prints the menu of the single page layout on a theme page that asks for
# it, such as the system information page. Real popups never get it.
sub theme_popup_prebody
{
print &theme_page_menu() if ($main::gray_theme_page_menu);
}

# theme_prehead()
# Prints the head parts of every page: the color scheme meta, the scheme
# and frame scripts, and the links to the stylesheet and the table sorting
# script. Also sets the body attributes the stylesheet keys on: the module
# name as a class and the forced color scheme, if any. In the single page
# layout it also decides whether the page gets the menu.
sub theme_prehead
{
my $pfx = &get_webprefix();
my $scheme = &theme_color_scheme();
print "<meta name='color-scheme' content='".($scheme || "light dark")."'>\n";
print &theme_scheme_script() if (!$scheme);
print &theme_frame_script();
print "<link rel='stylesheet' type='text/css' href='$pfx/unauthenticated/".
      "gray-theme.css?".&theme_asset_key("gray-theme.css")."'>\n";
print "<script type='text/javascript' src='$pfx/unauthenticated/".
      "sorttable.js?".&theme_asset_key("sorttable.js")."'></script>\n";
my @cls = grep { $_ } ( $main::gray_theme_body_class, &get_module_name() );

# Decide whether this page shows the menu of the single page layout. The
# body hooks read the result.
my $menu = &theme_page_menu_wanted();
if ($menu && &theme_one_module()) {
	# Webmin opens this user's only module directly, so a menu would
	# list just that module. Skip it, and let the core header show its
	# logout link, which the theme otherwise hides with the index link.
	$menu = 0;
	$tconfig{'noindex'} = 0;
	}
$main::gray_theme_page_menu = $menu;
if ($menu) {
	# Leave room for the menu, as wide as the left frame. A page that
	# still loads in a frame, such as in the old frameset right after the
	# layout changes, hides the menu.
	push(@cls, 'single-page');
	print "<style>:root { --menu-width: ".&theme_menu_width()."px; }".
	      "</style>\n";
	# A window that a script opened as a popup, with no menu bar of its
	# own, such as a chooser, hides the menu too
	print "<script type='text/javascript'>if (self != top || ".
	      "window.opener && window.menubar && !window.menubar.visible) ".
	      "document.documentElement.classList.add('menu-framed');".
	      "</script>\n";
	# Phones lay the page out at their own width, so the menu folds into
	# its bar there
	print "<meta name='viewport' ".
	      "content='width=device-width, initial-scale=1'>\n";
	# The product's icons, as the frameset page has them
	print &theme_favicons();
	}
$tconfig{'inbody'} = (@cls ? "class='".join(" ", @cls)."'" : "").
		     ($scheme ? " data-scheme='$scheme'" : "");
}

# theme_page_menu_wanted()
# Returns 1 if this page should show the menu of the single page layout:
# the layout is on, a user is logged in, and the page is not a popup. Pages
# loaded into a frame, an iframe or by a script get no menu either; browsers
# report this in the Sec-Fetch-Dest header. If the menu code cannot be
# loaded, the page shows no menu instead of an empty space.
sub theme_page_menu_wanted
{
return 0 if (!&theme_single_page());
return 0 if ($main::gray_theme_popup);
return 0 if (!$remote_user || $ENV{'ANONYMOUS_USER'});
my $dest = lc($ENV{'HTTP_SEC_FETCH_DEST'});
return 0 if ($dest && $dest ne 'document');
return &theme_menu_lib();
}

# theme_one_module()
# Returns 1 if Webmin is set to open a user's only module directly, the
# user has exactly one module, and it has no menu of its own. The modules
# are counted the way the core header counts them when it decides to show
# its logout link, hidden ones included, so the page never loses both the
# menu and that link. A user with a hidden module as well keeps the menu,
# which has its own logout link.
sub theme_one_module
{
return 0 if (!$gconfig{'gotoone'});
my @avail = &get_available_module_infos(1);
return 0 if (@avail != 1);
my $dir = &module_root_directory($avail[0]->{'dir'});
return -r "$dir/webmin_menu.pl" ? 0 : 1;
}

# theme_page_menu()
# Returns the menu of the single page layout. theme_prehead has already
# decided to show it and loaded the menu code. A page that switched to a
# Unix user other than root gets a panel that loads its menu instead.
sub theme_page_menu
{
return $> ? &theme_menu_placeholder() : &theme_menu_html({ 'single' => 1 });
}

# theme_menu_lib()
# Loads the functions that build the menu, once. Returns 1 when they are
# available.
sub theme_menu_lib
{
if (!defined(&theme_menu_html)) {
	# do loads it into the package of this copy of theme.pl: WebminCore
	# when the core calls the theme's hooks, as on module pages and the
	# system information page, and main when a theme CGI such as left.cgi
	# or menu.cgi calls it directly
	do "$theme_root_directory/menu-lib.pl";
	}
return defined(&theme_menu_html) ? 1 : 0;
}

# theme_single_page()
# Returns 1 if the theme settings choose the single page layout, with the
# menu on every page instead of in a frame of its own. A server opened
# through Webmin Servers Index keeps the frameset, as that index rewrites
# only the links and redirects of framed pages.
sub theme_single_page
{
return 0 if ($ENV{'HTTP_WEBMIN_SERVERS'} || $ENV{'HTTP_WEBMIN_PATH'});
return &theme_settings()->{'layout'} eq 'single' ? 1 : 0;
}

# theme_favicons()
# Returns the links to the icons of the product, Cloudmin, Virtualmin,
# Usermin or Webmin, in three sizes
sub theme_favicons
{
my $prod = &foreign_available("server-manager") ? 'cloudmin' :
	   &foreign_available("virtual-server") ? 'virtualmin' :
	   &get_product_name() eq 'usermin' ? 'usermin' : 'webmin';
my $dir = &get_webprefix()."/images/favicons/$prod";
return join("", map { "<link rel='icon' type='image/png' sizes='${_}x$_' ".
		      "href='$dir/favicon-${_}x$_.png'>\n" } (16, 32, 192));
}

# theme_menu_width()
# Returns the menu width in pixels: the width of the left frame, or of the
# space the menu takes in the single page layout
sub theme_menu_width
{
my $fsize = &theme_settings()->{'fsize'};
return $fsize =~ /^(\d+)$/ ? $1 :
       &get_product_name() eq 'usermin' ? 200 :
       &foreign_available("server-manager") &&
       &foreign_available("virtual-server") ? 280 : 260;
}

# theme_menu_cookie()
# Returns the name of the cookie that remembers the menu choices of the
# single page layout, and the path it is set for. The name holds the port,
# so that Webmin and Usermin on one host keep their own choices.
sub theme_menu_cookie
{
my $port = $ENV{'SERVER_PORT'} =~ /^(\d+)$/ ? $1 : "";
# Use the URL prefix as the path, or / when there is none or it has
# characters that are unsafe in a cookie
my $path = &get_webprefix();
$path = "/" if ($path !~ /^\/[\w\/.~\-]*$/);
return ("gray_theme_menu$port", $path);
}

# theme_menu_state()
# Returns the menu choices of the single page layout as a hash ref: the
# menu mode, the Virtualmin domain ID and the Cloudmin system ID. They
# come from the cookie, or from a later change on this page.
sub theme_menu_state
{
return $main::gray_theme_menu_state if ($main::gray_theme_menu_state);
my ($name) = &theme_menu_cookie();
my %state;
if ($ENV{'HTTP_COOKIE'} =~ /(?:^|;\s*)\Q$name\E=([^;\s]*)/) {
	# The value holds key=value pairs joined with &, all URL-encoded
	foreach my $kv (split(/&/, &un_urlize($1))) {
		my ($k, $v) = split(/=/, $kv, 2);
		$state{$k} = $v if ($k =~ /^(mode|dom|sid)$/ &&
				    $v =~ /^[\w.\-]+$/);
		}
	}
$main::gray_theme_menu_state = \%state;
return $main::gray_theme_menu_state;
}

# theme_menu_cookie_string(&state)
# Returns the cookie that stores the menu choices, with its attributes, in
# the form both a Set-Cookie header and document.cookie take. It lasts
# until the browser closes.
sub theme_menu_cookie_string
{
my ($state) = @_;
my ($name, $path) = &theme_menu_cookie();
# Only the known choices, with values that need no quoting
my $value = join("&", map { "$_=$state->{$_}" }
			grep { $state->{$_} =~ /^[\w.\-]+$/ }
			     ('mode', 'dom', 'sid'));
return "$name=".&urlize($value)."; path=$path; SameSite=Lax".
       (uc($ENV{'HTTPS'}) eq 'ON' ? "; Secure" : "");
}

# theme_menu_remember(&choices)
# Returns a script that makes menu choices, such as a domain ID, the ones
# of this page, and stores them in the cookie of the single page layout
# when it does not hold them yet. The menu script puts the page's choices
# back into the cookie whenever its tab comes back into use, so that tabs
# keep their own choices.
sub theme_menu_remember
{
my ($choices) = @_;
my $state = &theme_menu_state();
my %new = ( %$state, %$choices );
my $cookie = &theme_menu_cookie_string(\%new);
my $changed = $cookie ne &theme_menu_cookie_string($state);
$main::gray_theme_menu_state = \%new;
return "<script type='text/javascript'>".
       "window.grayThemeMenuCookie = '$cookie';".
       ($changed ? " document.cookie = '$cookie';" : "").
       "</script>\n";
}

# theme_scheme_script()
# Returns a script that keeps the color scheme steady when none is forced.
# A browser can report the system scheme for a moment before settling on
# its own, and gives a frame the scheme of the page holding it only once
# that page is styled, so a frame could paint dark and then turn light on
# every reload. The script applies the last scheme seen to the root
# element before the first paint and follows later changes. In a top
# window it also writes the scheme into the root style, so the frames
# inherit it, and checks again a second after load if no change came, in
# case the stored scheme was stale.
sub theme_scheme_script
{
return <<'EOF';
<script type='text/javascript'>
(function() {
var key = 'gray-theme-scheme', root = document.documentElement,
    mq = window.matchMedia('(prefers-color-scheme: dark)'),
    stored = null, changed = false;
try { stored = localStorage.getItem(key); } catch(e) { }
function current() { return mq.matches ? 'dark' : 'light'; }
function apply(v) {
	root.setAttribute('data-scheme', v);
	if (self == top) root.style.colorScheme = v;
	try { localStorage.setItem(key, v); } catch(e) { }
	}
apply(stored == 'dark' || stored == 'light' ? stored : current());
function onchange() { changed = true; apply(current()); }
if (mq.addEventListener) mq.addEventListener('change', onchange);
else mq.addListener(onchange);
if (self == top)
	window.addEventListener('load', function() {
		setTimeout(function() { if (!changed) apply(current()); }, 1000);
		});
})();
</script>
EOF
}

# theme_frame_script()
# Returns a script for a page shown in the right frame, which tells the
# menu frame when the page starts to leave and when the next one has
# loaded, so the menu can show a loader in between. It does nothing in
# the menu frame itself, in popups and outside the frameset.
sub theme_frame_script
{
return <<'EOF';
<script type='text/javascript'>
(function() {
var menu = null;
try { if (parent != window) menu = parent.frames['left']; } catch(e) { }
if (!menu || menu == window) return;
function tell(name) { try { if (menu[name]) menu[name](); } catch(e) { } }
window.addEventListener('pagehide', function() { tell('rightLoading'); });
window.addEventListener('DOMContentLoaded', function() { tell('rightLoaded'); });
})();
</script>
EOF
}

# theme_color_scheme()
# Returns light or dark when the theme settings force a color scheme, or an
# empty string to follow the browser. The setting is stored with the other
# system information page settings, per user unless they are global.
sub theme_color_scheme
{
my $scheme = &theme_settings()->{'scheme'};
return $scheme =~ /^(light|dark)$/ ? $1 : "";
}

# theme_asset_key(file)
# Returns the modification time of a file under unauthenticated, used as a
# cache key in its URL so browsers pick up a changed file at once
sub theme_asset_key
{
my ($file) = @_;
my @st = stat("$theme_root_directory/unauthenticated/$file");
return @st ? $st[9] : &get_webmin_version();
}

# theme_tag_class(tags, class)
# Adds a class to a string of tag attributes, merging it into an existing
# class attribute so that a tag never gets two of them
sub theme_tag_class
{
my ($tags, $class) = @_;
return "class='$class'" if (!$tags);
return $tags if ($tags =~ s/class=(['"])([^'"]*)\1/class=$1$2 $class$1/);
return "$tags class='$class'";
}

# theme_popup_prehead(title, ...)
# Popup windows and frames get the same head as ordinary pages. A theme
# page that uses the popup header but asks for the menu, such as the system
# information page, is not treated as a popup.
sub theme_popup_prehead
{
local $main::gray_theme_popup = !$main::gray_theme_menu_page;
&theme_prehead();
if ($main::gray_theme_page_menu &&
    $current_lang_info->{'dir'} =~ /^(rtl|ltr)$/) {
	# The popup header sets no text direction on the body, but the menu
	# needs one to stay on the same side as on other pages
	$tconfig{'inbody'} .= " dir='$1'";
	}
}

# theme_ui_table_start(heading, [tabletags], [cols], [&default-tds],
#		       [right-heading])
# Returns HTML for the start of a form table: a card with the heading in
# its head row and the label and value rows in a nested table
sub theme_ui_table_start
{
my ($heading, $tabletags, $cols, $tds, $rightheading) = @_;
if (! $tabletags =~ /width/) { $tabletages .= " width=100%"; }
if (defined($main::ui_table_cols)) {
  # Push on stack, for nested call
  push(@main::ui_table_cols_stack, $main::ui_table_cols);
  push(@main::ui_table_pos_stack, $main::ui_table_pos);
  push(@main::ui_table_default_tds_stack, $main::ui_table_default_tds);
  }
my $rv;
my $colspan = 1;

if (!$main::WRAPPER_OPEN) {
	# A class in the table tags, such as the login form's, joins the
	# wrapper class instead of being lost as a second class attribute
	$rv .= "<table ".&theme_tag_class($tabletags, 'shrinkwrapper').">\n";
	$rv .= "<tr><td>\n";
	}
$main::WRAPPER_OPEN++;
$rv .= "<table class='ui_table' $tabletags>\n";
if (defined($heading) || defined($rightheading)) {
	# Heading row, with an optional part at the right
        $rv .= "<thead><tr>";
        if (defined($heading)) {
                $rv .= "<td><b>$heading</b></td>"
                }
        if (defined($rightheading)) {
                $rv .= "<td align=right>$rightheading</td>";
                $colspan++;
                }
        $rv .= "</tr></thead>\n";
        }
$rv .= "<tbody> <tr class='ui_table_body'> <td colspan=$colspan>".
       "<table width=100%>\n";
$main::ui_table_cols = $cols || 4;
$main::ui_table_pos = 0;
$main::ui_table_default_tds = $tds;
return $rv;
}

# ui_table_row(label, value, [cols], [&td-tags])
# Returns HTML for a row in a table started by ui_table_start, with a 1-column
# label and 1+ column value.
sub theme_ui_table_row
{
my ($label, $value, $cols, $tds, $trs) = @_;
$cols ||= 1;
$tds ||= $main::ui_table_default_tds;
my $rv;
if ($main::ui_table_pos+$cols+1 > $main::ui_table_cols &&
    $main::ui_table_pos != 0) {
    # If the requested number of cols won't fit in the number
    # remaining, start a new row
    my $leftover = $main::ui_table_cols - $main::ui_table_pos;
    $rv .= "<td colspan=$leftover></td>\n";
    $rv .= "</tr>\n";
    $main::ui_table_pos = 0;
    }
if (defined($label) &&
    ($value =~ /id="([^"]+)"/ || $value =~ /id='([^']+)'/ ||
     $value =~ /id=([^>\s]+)/)) {
	# Value contains an input with an ID
	my $id = $1;
	$label = "<label for=\"".&quote_escape($id)."\">$label</label>";
	}
my $trtags_attrs = ref($trs) eq 'ARRAY' && $trs->[0] ? " $trs->[0]" : "";
my $trtags_class = ref($trs) eq 'ARRAY' && $trs->[1] ? " $trs->[1]" : "";
$rv .= "<tr class='ui_form_pair$trtags_class'$trtags_attrs>\n" if ($main::ui_table_pos%$main::ui_table_cols == 0);
$rv .= "<td class='ui_form_label' $tds->[0]><b>$label</b></td>\n" if (defined($label));
$rv .= "<td class='ui_form_value' colspan=$cols $tds->[1]>$value</td>\n";
$main::ui_table_pos += $cols+(defined($label) ? 1 : 0);
if ($main::ui_table_pos%$main::ui_table_cols == 0) {
    $rv .= "</tr>\n";
    $main::ui_table_pos = 0;
    }
return $rv;
}

sub theme_ui_table_hr
{
my $rv;
if ($main::ui_table_pos) {
	$rv .= "</tr>\n";
	$main::ui_table_pos = 0;
	}
$rv .= "<tr class='ui_form_pair'>\n";
$rv .= "<td class='ui_form_label' colspan=$main::ui_table_cols><hr></td>\n";
$rv .= "</tr>\n";
return $rv;
}

# theme_ui_table_end()
# Returns HTML for the end of a table started by theme_ui_table_start
sub theme_ui_table_end
{
my $rv;
if ($main::ui_table_cols == 4 && $main::ui_table_pos) {
  # Add an empty block to balance the table
  $rv .= &ui_table_row(" ", " ");
  }
if (@main::ui_table_cols_stack) {
  # Back to the column state of the enclosing table
  $main::ui_table_cols = pop(@main::ui_table_cols_stack);
  $main::ui_table_pos = pop(@main::ui_table_pos_stack);
  $main::ui_table_default_tds = pop(@main::ui_table_default_tds_stack);
  }
else {
  # No enclosing table
  $main::ui_table_cols = undef;
  $main::ui_table_pos = undef;
  $main::ui_table_default_tds = undef;
  }
$rv .= "</tbody></table></td></tr></table>\n";
if ($main::WRAPPER_OPEN==1) {
	# Close the card around the outermost table
	$rv .= "</td></tr>\n";
	$rv .= "</table>\n";
	}
$main::WRAPPER_OPEN--;
return $rv;
}

# theme_ui_tabs_start(&tabs, name, selected, show-border)
# Render a row of tabs from which one can be selected. Each tab is an array
# ref containing a name, title and link. The tabs are links in a div, and
# select_tab switches their classes and the visible tab body.
sub theme_ui_tabs_start
{
my ($tabs, $name, $sel, $border) = @_;
my $rv;
if (!$main::ui_hidden_start_donejs++) {
  # The tab switching script is printed once per page
  $rv .= &ui_hidden_javascript();
  }

# List of tab names, used by select_tab to find the tabs and bodies
my $tabnames = &convert_to_json([map { $_->[0] } @$tabs]);
$rv .= "<script>\n";
$rv .= "document.${name}_tabnames = $tabnames;\n";
$rv .= "</script>\n";

# Output the tabs
$rv .= &ui_hidden($name, $sel)."\n";
$rv .= "<div class='ui_tabs' id='tabs_$name'>\n";
foreach my $t (@$tabs) {
	my $cls = $t->[0] eq $sel ? "ui_tab ui_tab_selected" : "ui_tab";
	my $href = $t->[2] ne '' ? $t->[2] : '#';
	$rv .= "<a id='tab_$t->[0]' class='$cls' href='$href' ".
	       "onClick='return select_tab(\"$name\", \"$t->[0]\")'>".
	       "$t->[1]</a>\n";
	}
$rv .= "</div>\n";

if ($border) {
	# All tab bodies are within a box
	$rv .= "<div class='ui_tabs_box'>\n";
	}
$main::ui_tabs_selected = $sel;
return $rv;
}

# theme_ui_tabs_end(show-border)
# Closes the box opened by theme_ui_tabs_start
sub theme_ui_tabs_end
{
my ($border) = @_;
return $border ? "</div>\n" : "";
}

# theme_ui_columns_start(&headings, [width-percent], [noborder], [&tdtags], [title])
# Returns HTML for a multi-column table, with the given headings
sub theme_ui_columns_start
{
my ($heads, $width, $noborder, $tdtags, $title, $sortable, $class) = @_;
my ($href) = grep { $_ =~ /<a\s+href/i } @$heads;
my $rv;
$theme_ui_columns_row_toggle = 0;
if (!$noborder && !$main::COLUMNS_WRAPPER_OPEN) {
	# The outermost bordered table opens the card
	$rv .= "<table class='wrapper' width="
	     . ($width ? $width : "100")
	     . "%>\n";
	$rv .= "<tr><td>\n";
	}
if (!$noborder) {
	# Nested bordered tables share that card
	$main::COLUMNS_WRAPPER_OPEN++;
	}
# Tables are sorted by sorttable.js unless their headings are links, or
# always when the caller asked for a sortable table
my @classes;
push(@classes, "ui_table") if (!$noborder);
push(@classes, "sortable") if (!$href || $sortable);
push(@classes, "ui_columns");
push(@classes, $class) if ($class);
$rv .= "<table".(@classes ? " class='".join(" ", @classes)."'" : "").
    (defined($width) ? " width=$width%" : "").
    ($sortable ? " data-sortable='1'" : "").">\n";
if ($title) {
  # Title row spanning the table, above the column headings
  $rv .= "<thead> <tr ".&theme_tag_class($tb, 'ui_columns_heading').">".
	 "<td colspan=".scalar(@$heads)."><b>$title</b></td>".
	 "</tr> </thead> <tbody>\n";
  }
$rv .= "<thead> <tr ".&theme_tag_class($tb, 'ui_columns_heads').">\n";
my $i;
for($i=0; $i<@$heads; $i++) {
  $rv .= "<td ".$tdtags->[$i]."><b>".
         ($heads->[$i] eq "" ? "<br>" : $heads->[$i])."</b></td>\n";
  }
$rv .= "</tr></thead> <tbody>\n";
$theme_ui_columns_count++;
return $rv;
}

# theme_ui_columns_header(&columns, &tdtags)
# Returns HTML for a heading row inside a multi-column table
sub theme_ui_columns_header
{
my ($cols, $tdtags) = @_;
my $rv;
$rv .= "<tr ".&theme_tag_class($tb, 'ui_columns_header').">\n";
for(my $i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i]."><b>".
	       ($cols->[$i] eq "" ? "<br>" : $cols->[$i])."</b></td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# theme_ui_columns_row(&columns, &tdtags)
# Returns HTML for a row in a multi-column table. Rows are highlighted on
# hover and when checked by the stylesheet, so no handlers are needed.
sub theme_ui_columns_row
{
$theme_ui_columns_row_toggle = $theme_ui_columns_row_toggle ? '0' : '1';
local ($cols, $tdtags) = @_;
my $rv;
$rv .= "<tr class='ui_columns_row row$theme_ui_columns_row_toggle'>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i].">".
	       ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i])."</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# theme_ui_columns_end()
# Returns HTML to end a table started by ui_columns_start
sub theme_ui_columns_end
{
my $rv;
$rv = "</tbody> </table>\n";
if ($main::COLUMNS_WRAPPER_OPEN == 1) { # Last wrapper
	$rv .= "</td> </tr> </table>\n";
	}
$main::COLUMNS_WRAPPER_OPEN--;
return $rv;
}

# theme_ui_grid_table(&elements, columns, [width-percent], [tds], [tabletags],
#   [title])
# Given a list of HTML elements, formats them into a table with the given
# number of columns. However, themes are free to override this to use fewer
# columns where space is limited.
sub theme_ui_grid_table
{
my ($elements, $cols, $width, $tds, $tabletags, $title) = @_;
return "" if (!@$elements);
	
my $rv = "<table class='wrapper' " 
       . ($width ? " width=$width%" : " width=100%")
       . ($tabletags ? " ".$tabletags : "")
       . "><tr><td>\n";
$rv .= "<table class='ui_table ui_grid_table'"
     . ($width ? " width=$width%" : "")
     . ($tabletags ? " ".$tabletags : "")
     . ">\n";
if ($title) {
	$rv .= "<thead><tr class='ui_grid_heading'> ".
	       "<td colspan=$cols><b>$title</b></td> </tr></thead>\n";
	}
$rv .= "<tbody>\n";
my $i;
for($i=0; $i<@$elements; $i++) {
  $rv .= "<tr class='ui_grid_row'>" if ($i%$cols == 0);
  $rv .= "<td ".$tds->[$i%$cols]." valign=top class='ui_grid_cell'>".
	 $elements->[$i]."</td>\n";
  $rv .= "</tr>" if ($i%$cols == $cols-1);
  }
if ($i%$cols) {
  while($i%$cols) {
    $rv .= "<td ".$tds->[$i%$cols]." class='ui_grid_cell'><br></td>\n";
    $i++;
    }
  $rv .= "</tr>\n";
  }
$rv .= "</table>\n";
$rv .= "</tbody>\n";
$rv .= "</td></tr></table>\n"; # wrapper
return $rv;
}

sub theme_ui_hidden_start
{
my ($title, $name, $status) = @_;
my $rv;
my $opened = $status ? " open" : "";
$rv .= "<details class='ui_hidden_start'$opened>";
$rv .= "<summary>$title</summary>\n";
return $rv;
}

=head2 ui_hidden_end(name)

Returns HTML for the end of a hidden section, started by ui_hidden_start.

=cut
sub theme_ui_hidden_end
{
return "</details>\n";
}

# theme_ui_hidden_table_start(heading, [tabletags], [cols], name, status,
#                             [&default-tds], [rightheading])
# A table with a heading and table inside, and which is collapsible
sub theme_ui_hidden_table_start
{
my ($heading, $tabletags, $cols, $name, $status, $tds, $rightheading) = @_;
my $rv;
if (!$main::ui_hidden_start_donejs++) {
  $rv .= &ui_hidden_javascript();
  }
my $opened = $status ? " open" : "";
my $header = defined($heading) ? "<span>$heading</span>" : "";
my $rheader = defined($rightheading) ? "<span class='rightheading'>$rightheading</span>" : "";
if (!$main::WRAPPER_OPEN) { # If we're not already inside of a wrapper, wrap it
	$rv .= "<div>\n";
	}
$main::WRAPPER_OPEN++;
my $colspan = 1;
$rv .= "<details data-name='$name' class='ui_hidden_table_start'$opened $tabletags>";
$rv .= "<summary>$header $rheader</summary>\n";
$rv .= "<table width=100%>\n";
$main::ui_table_cols = $cols || 4;
$main::ui_table_pos = 0;
$main::ui_table_default_tds = $tds;
return $rv;
}

# ui_hidden_table_end(name)
# Returns HTML for the end of table with hiding, as started by
# ui_hidden_table_start
sub theme_ui_hidden_table_end
{
local $rv = "</table></details>\n";
if ( $main::WRAPPER_OPEN == 1 ) {
	$main::WRAPPER_OPEN--;
	$rv .= "</div>\n";
	}
elsif ($main::WRAPPER_OPEN) { $main::WRAPPER_OPEN--; }
return $rv;
}

# theme_ui_checked_columns_row(&columns, &tdtags, checkname, checkvalue,
#			       [checked], [disabled], [tags])
# Returns HTML for a row with a checkbox in its first column. The row is
# highlighted by the stylesheet while its checkbox is checked.
sub theme_ui_checked_columns_row
{
$theme_ui_columns_row_toggle = $theme_ui_columns_row_toggle ? '0' : '1';
local ($cols, $tdtags, $checkname, $checkvalue, $checked, $disabled, $tags) = @_;
my $rv;
my $rid = &quote_escape("row_${checkname}_${checkvalue}");
my $mycb = &theme_tag_class($cb,
	"row$theme_ui_columns_row_toggle ui_checked_columns");
$rv .= "<tr id=\"$rid\" $mycb>\n";
$rv .= "<td class='ui_checked_checkbox' ".$tdtags->[0].">".
       &ui_checkbox($checkname, $checkvalue, undef, $checked, $tags,
		    $disabled).
       "</td>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i+1].">";
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		# Plain cells become labels for the control, so a click on
		# them selects it
		$rv .= "<label for=\"".
			&quote_escape("${checkname}_${checkvalue}")."\">";
		}
	$rv .= ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i]);
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		# Close that label
		$rv .= "</label>";
		}
	$rv .= "</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# theme_ui_radio_columns_row(&columns, &tdtags, checkname, checkvalue,
#			     [checked])
# Returns HTML for a row with a radio button in its first column. The row
# is highlighted by the stylesheet while its button is selected.
sub theme_ui_radio_columns_row
{
local ($cols, $tdtags, $checkname, $checkvalue, $checked) = @_;
my $rv;
my $rid = &quote_escape("row_${checkname}_${checkvalue}");
my $mycb = &theme_tag_class($cb, "ui_radio_columns");
$rv .= "<tr $mycb id=\"$rid\">\n";
$rv .= "<td ".$tdtags->[0]." class='ui_radio_radio'>".
       &ui_oneradio($checkname, $checkvalue, undef, $checked).
       "</td>\n";
my $i;
for($i=0; $i<@$cols; $i++) {
	$rv .= "<td ".$tdtags->[$i+1].">";
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		# Plain cells become labels for the control, so a click on
		# them selects it
		$rv .= "<label for=\"".
			&quote_escape("${checkname}_${checkvalue}")."\">";
		}
	$rv .= ($cols->[$i] !~ /\S/ ? "<br>" : $cols->[$i]);
	if ($cols->[$i] !~ /<a\s+href|<input|<select|<textarea/) {
		# Close that label
		$rv .= "</label>";
		}
	$rv .= "</td>\n";
	}
$rv .= "</tr>\n";
return $rv;
}

# theme_ui_nav_link(direction, url, disabled)
# Returns an arrow icon linking to provided url
sub theme_ui_nav_link
{
my ($direction, $url, $disabled) = @_;
my $icon = &ui_svg_icon($direction eq "left" ? "chevron-left"
					      : "chevron-right",
			{ 'size' => 14,
			  'title' => $direction eq "left" ? '<-' : '->' });
if ($disabled) {
  # A disabled arrow is plain, not a link
  return "<span class='ui_nav_link ui_nav_link_disabled'>$icon</span>\n";
  }
else {
  # Arrow linking to the page
  return "<a class='ui_nav_link' href=\"$url\">$icon</a>\n";
  }
}

# theme_ui_links_row(&links)
# Returns a row of links separated by bars, in a block of its own so that
# the stylesheet can draw it as a toolbar when it sits above a table
sub theme_ui_links_row
{
my ($links) = @_;
return "" if (!$links || !@$links);
return "<div class='ui_links_row'>".
       join(" <span class='ui_links_sep'>|</span> ", @$links).
       "</div>\n";
}

# theme_file_chooser_button(input, type, [form], [chroot], [addmode])
# Returns a button that opens the file chooser, in a window large enough
# for the theme's controls unless the Webmin configuration sets a size
sub theme_file_chooser_button
{
my ($input, $type, $form, $chroot, $add) = @_;
$chroot = "/" if (!defined($chroot));
$add = int($add);
my ($w, $h) = (560, 500);
($w, $h) = split(/x/, $gconfig{'db_sizefile'}) if ($gconfig{'db_sizefile'});
return "<input type='button' class='ui_button ui_chooser_button' ".
       "onClick='ifield = form.$input; chooser = window.open(\"".
       &get_webprefix()."/chooser.cgi?add=$add&type=$type&chroot=$chroot".
       "&file=\"+encodeURIComponent(ifield.value), \"chooser\", ".
       "\"toolbar=no,menubar=no,scrollbars=no,resizable=yes,".
       "width=$w,height=$h\"); chooser.ifield = ifield; ".
       "window.ifield = ifield' value=\"...\">\n";
}

# theme_user_chooser_button(input, multiple, [form])
# Returns a button that opens the user chooser, sized like the file chooser
sub theme_user_chooser_button
{
my ($input, $multi) = @_;
return &theme_chooser_button("user_chooser.cgi", "user", $input, $multi);
}

# theme_group_chooser_button(input, multiple, [form])
# Returns a button that opens the group chooser, sized like the file chooser
sub theme_group_chooser_button
{
my ($input, $multi) = @_;
return &theme_chooser_button("group_chooser.cgi", "group", $input, $multi);
}

# theme_chooser_button(script, param, input, multiple)
# Returns the button shared by the user and group choosers. The multiple
# selection window has two panes and so is wider.
sub theme_chooser_button
{
my ($script, $param, $input, $multi) = @_;
my ($w, $h) = $multi ? (640, 500) : (420, 500);
if ($multi && $gconfig{'db_sizeusers'}) {
	# Size of the multiple selection chooser from the Webmin config
	($w, $h) = split(/x/, $gconfig{'db_sizeusers'});
	}
elsif (!$multi && $gconfig{'db_sizeuser'}) {
	# Size of the single selection chooser from the Webmin config
	($w, $h) = split(/x/, $gconfig{'db_sizeuser'});
	}
$multi = int($multi);
return "<button type='button' class='ui_button ui_chooser_button' ".
       "onClick='ifield = form.$input; chooser = window.open(\"".
       &get_webprefix()."/$script?multi=$multi&$param=\"+".
       "escape(ifield.value), \"chooser\", ".
       "\"toolbar=no,menubar=no,scrollbars=yes,resizable=yes,".
       "width=$w,height=$h\"); chooser.ifield = ifield; ".
       "window.ifield = ifield'>...</button>\n";
}

# theme_footer([page, name]+, [noendbody])
# Output a footer for returning to some page
sub theme_footer
{
my $i;
my @links;
my %module_info = get_module_info(get_module_name());
for($i=0; $i+1<@_; $i+=2) {
	local $url = $_[$i];
	if ($url ne '/' || !$tconfig{'noindex'}) {
		# Turn the shortcut into a URL, unless the theme hides the
		# Webmin index link
		if ($url eq '/') {
			# Webmin index, opened at the module's category
			$url = "/?cat=$module_info{'category'}";
			}
		elsif ($url eq '' && get_module_name() eq 'virtual-server' ||
		       $url eq '/virtual-server/') {
			# Don't bother with virtualmin menu
			next;
			}
		elsif ($url eq '' && get_module_name() eq 'server-manager' ||
		       $url eq '/server-manager/') {
			# Don't bother with Cloudmin menu
			next;
			}
		#elsif ($url =~ /(view|edit)_domain.cgi/ &&
		#       get_module_name() eq 'virtual-server' ||
		#       $url =~ /^\/virtual-server\/(view|edit)_domain.cgi/) {
		#	# Don't bother with link to domain details
		#	next;
		#	}
		elsif ($url =~ /edit_serv.cgi/ &&
		       get_module_name() eq 'server-manager' ||
		       $url =~ /^\/virtual-server\/edit_serv.cgi/) {
			# Don't bother with link to system details
			next;
			}
		elsif ($url eq '' && get_module_name()) {
			# Index page of the current module
			$url = "/".get_module_name()."/".
			       $module_info{'index_link'};
			}
		elsif ($url =~ /^\?/ && get_module_name()) {
			# Index page of the module with parameters
			$url = "/".get_module_name()."/$url";
			}
		$url = "@{[&get_webprefix()]}$url" if ($url =~ /^\//);
		push(@links, "<a href=\"$url\">".
			     &text('main_return', $_[$i+1])."</a>");
		}
	}
if (@links) {
	# Return links, with a chevron before the first
	print "<div class='ui_footer_links'>\n";
	print &ui_svg_icon("chevron-left", { 'size' => 14 }),"\n";
	print join(" <span class='ui_footer_sep'>|</span>\n", @links),"\n";
	print "</div>\n";
	}
if (!$_[$i]) {
	# End the page, unless the caller keeps the body open
	my $postbody = $tconfig{'postbody'};
	if ($postbody) {
		# Text from the theme config at the end of every page, with
		# its placeholders filled in
		my $hostname = &get_display_hostname();
		my $version = &get_webmin_version();
		my $os_type = $gconfig{'real_os_type'} ||
			      $gconfig{'os_type'};
		my $os_version = $gconfig{'real_os_version'} ||
				 $gconfig{'os_version'};
		$postbody =~ s/%HOSTNAME%/$hostname/g;
		$postbody =~ s/%VERSION%/$version/g;
		$postbody =~ s/%USER%/$remote_user/g;
		$postbody =~ s/%OS%/$os_type $os_version/g;
		print "$postbody\n";
		}
	if ($tconfig{'postbodyinclude'}) {
		# File from the theme directory at the end of every page
		local $_;
		open(INC, "$theme_root_directory/$tconfig{'postbodyinclude'}");
		while(<INC>) {
			print;
			}
		close(INC);
		}
	if (defined(&theme_postbody)) {
		# Hook of an overlay theme
		&theme_postbody(@_);
		}
	print "</body></html>\n";
	}
}

# theme_redirect(original-url, url)
# Prints a redirect like the core, except that a Virtualmin page sending
# the browser to the server root goes to the framed system information
# page, since the Virtualmin menu is already in the left frame
sub theme_redirect
{
local ($orig, $url) = @_;
if (get_module_name() eq "virtual-server" && $orig eq "" &&
    # Virtualmin's return to the root
    $url =~ /^((http|https):\/\/([^\/]+))\//) {
	$url = "$1/right.cgi";
	}
print "Location: $url\n\n";
}

# theme_local_redirect(path)
# Prints a redirect to a path on this server, such as /right.cgi, with the
# path alone in the Location header. The browser then stays on the host and
# port it used. The core redirect builds a full URL from the redirect host
# in the Webmin settings, which a browser using another address may not
# reach, so the page hangs.
sub theme_local_redirect
{
my ($path) = @_;
if ($gconfig{'webprefixnoredir'}) {
	# Webmin is set not to add the URL prefix to redirects, because a
	# proxy rewrites the full URLs of its redirects; the core redirect
	# gives it those
	&redirect($path);
	return;
	}
print "Location: ".&get_webprefix()."$path\n\n";
}

# theme_ui_hidden_javascript()
# Returns the script that switches tabs and opens hidden sections. Both
# only change classes; the stylesheet does the rest.
sub theme_ui_hidden_javascript
{
return <<EOF;
<script>
// Open or close a hidden section
function hidden_opener(divid, openerid)
{
var divobj = document.getElementById(divid);
var openerobj = document.getElementById(openerid);
var shown = divobj.className == 'opener_shown';
divobj.className = shown ? 'opener_hidden' : 'opener_shown';
if (openerobj) {
  // Turn the arrow of the link that opens the section
  openerobj.className = shown ? 'opener_closed' : 'opener_open';
  }
}

// Show a tab and hide the others
function select_tab(name, tabname, form)
{
var tabnames = document[name+'_tabnames'];
for(var i=0; i<tabnames.length; i++) {
  var tabobj = document.getElementById('tab_'+tabnames[i]);
  var divobj = document.getElementById('div_'+tabnames[i]);
  var selected = tabnames[i] == tabname;
  if (tabobj) {
    // Mark the tab itself
    tabobj.className = selected ? 'ui_tab ui_tab_selected' : 'ui_tab';
    }
  if (!divobj) {
    // A tab that is only a link has no body
    continue;
    }
  divobj.className = (selected ? 'opener_shown' : 'opener_hidden')+
		     ' ui_tabs_start';
  if (selected) {
    // Point the submit buttons of a nested form at it
    try {
	var nestedForm = divobj.querySelector("form[data-form-nested]");
	if (nestedForm) {
		var nestedFormId = nestedForm.getAttribute("data-form-nested"),
		formSubmitters = document
			.querySelectorAll(
				"[data-submit-nested='" + nestedFormId + "']");
		if (formSubmitters) {
			formSubmitters.forEach(function(submitter) {
				submitter.setAttribute(
					"form", nestedForm.getAttribute('id'));
			});
		}
	}
    } catch(e) {
	console.warn('Cannot set the related submitter ID of the nested form : ' + e);
    }
    }
  }
if (document.forms[0] && document.forms[0][name]) {
  // Remember the tab in the hidden field, so a submit returns to it
  document.forms[0][name].value = tabname;
  }
return false;
}
</script>
EOF
}

# Icons drawn before notices, by notice type and by the Font Awesome class
# names that modules pass to ui_alert
my %theme_alert_icons = (
	'success' => 'check-circle',
	'info' => 'info-circle',
	'warning' => 'warning',
	'danger' => 'x-circle',
	'danger-fatal' => 'x-circle',
	);
my %theme_fa_icons = (
	'fa-check-circle' => 'check-circle',
	'fa-check' => 'check',
	'fa-info-circle' => 'info-circle',
	'fa-question-circle' => 'question-circle',
	'fa-exclamation-triangle' => 'warning',
	'fa-warning' => 'warning',
	'fa-bolt' => 'x-circle',
	'fa-times-circle' => 'x-circle',
	'fa-clock' => 'clock',
	'fa-clock-o' => 'clock',
	'fa-hdd-o' => 'hard-drive',
	'fa-lock' => 'shield',
	'fa-shield' => 'shield',
	'fa-plug' => 'power',
	'fa-power-off' => 'power',
	'fa-download' => 'download',
	'fa-upload' => 'upload',
	'fa-refresh' => 'refresh',
	'fa-search' => 'search',
	'fa-server' => 'server',
	'fa-user' => 'user',
	'fa-trash' => 'trash',
	'fa-cog' => 'gear',
	'fa-globe' => 'globe',
	'fa-star' => 'star',
	'fa-play' => 'play',
	'fa-stop' => 'stop',
	'fa-terminal' => 'terminal',
	'fa-book' => 'book',
	'fa-filter' => 'filter',
	'fa-pencil' => 'edit',
	'fa-edit' => 'edit',
	'fa-external-link' => 'external',
	);

# theme_alert_icon(type, [fa-classes])
# Returns the icon shown before a notice, from a Font Awesome class name
# when the theme has an equivalent, else from the notice type
sub theme_alert_icon
{
my ($type, $fa) = @_;
my $name;
if ($fa) {
	# Prefer the icon the module asked for, when the theme has it
	my ($known) = grep { $theme_fa_icons{$_} } split(/\s+/, $fa);
	$name = $theme_fa_icons{$known} if ($known);
	}
$name ||= $theme_alert_icons{$type} || 'info-circle';
return "<span class='ui_alert_icon'>".
       &ui_svg_icon($name, { 'size' => 18 })."</span>";
}

# theme_ui_alert_box(message, type, [style], [new-line], [title], [icon])
# Returns HTML for a notice box with an icon, taking the same arguments as
# the Authentic theme. The type can be success, info, warn, danger or
# danger-fatal, and picks the colors, the icon and the default title. The
# style is added to the box. With new-line set, the message starts under
# the title instead of after it. A title replaces the default one, and an
# empty title removes it. The icon is a Font Awesome class name, used when
# the theme has an equivalent. Buttons that the message puts on a line of
# their own, after a <p>, are wrapped together with the text before them,
# so both can share one line.
sub theme_ui_alert_box
{
my ($msg, $class, $style, $new_line, $desc_to_title, $desc_icon) = @_;
my %types = ( 'success' => [ 'success', $text{'ui_success'} ],
	      'info' => [ 'info', $text{'ui_info'} ],
	      'warn' => [ 'warning', $text{'ui_warning'} ],
	      'warning' => [ 'warning', $text{'ui_warning'} ],
	      'danger' => [ 'danger', $text{'ui_error'} ],
	      'danger-fatal' => [ 'danger-fatal', $text{'ui_error_fatal'} ] );
my ($type, $title) = @{$types{$class} || $types{'info'}};
# The default titles end in an exclamation mark, as in the Authentic theme
$title .= "!" if ($title ne '');
$title = $desc_to_title if (defined($desc_to_title));
my $lead = $title =~ /\S/ ?
	"<strong>$title</strong>".($new_line ? "<br>" : " ") : "";
if ($msg =~ s/^(.*?)<p>\s*(<form\b.*?<\/form>)/<span class='ui_alert_text'>$lead$1<\/span><span class='ui_alert_actions'>$2<\/span>/is) {
	# A form of buttons after the text
	}
elsif ($msg =~ s/(<form\b[^>]*>)(.*?)<p>\s*((?:<input\b[^>]*>\s*)+)(<\/form>)/$1<span class='ui_alert_text'>$lead$2<\/span><span class='ui_alert_actions'>$3<\/span>$4/is) {
	# Buttons after the text, inside its form
	}
elsif ($msg =~ s/(<form\b[^>]*>)(.*?)<p>\s*((?:<input\b[^>]*>\s*)*<table\b[^>]*class=['"]ui_form_end_buttons['"].*?<\/table>)\s*(<\/form>)/$1<span class='ui_alert_text'>$lead$2<\/span><span class='ui_alert_actions'>$3<\/span>$4/is) {
	# Buttons after the text, as a form end table inside its form
	}
else {
	# Plain message after the title
	$msg = $lead.$msg;
	}
return "<div class='ui_alert_box alert alert-$type'".
       ($style ? " style='".&quote_escape($style)."'" : "").">".
       &theme_alert_icon($type, $desc_icon).
       "<div class='ui_alert_body'>$msg</div></div>\n";
}

# theme_ui_alert(content, [type], [icon], [&attrs])
# Returns HTML for an alert with an icon and a title, like the core
# ui_alert but drawn with the theme's SVG icons. The icon can be a Font
# Awesome class name, or an array of [ class, title, no-line-break ].
sub theme_ui_alert
{
my ($content, $type, $icon, $attrs) = @_;
$type ||= 'info';
my %titles = ( 'success' => $text{'ui_success'},
	       'info' => $text{'ui_info'},
	       'warning' => $text{'ui_warning'},
	       'danger' => $text{'ui_error'},
	       'danger-fatal' => $text{'ui_error_fatal'} );
my ($fa, $title, $br) = (undef, $titles{$type}, 1);
if (ref($icon)) {
	# Icon given with its own title and line break flag
	$fa = $icon->[0];
	$title = $icon->[1] if (defined($icon->[1]));
	$br = 0 if ($icon->[2]);
	}
elsif (defined($icon)) {
	# Icon name alone
	$fa = $icon;
	}
my %a = %{$attrs || {}};
$a{'class'} = join(" ", grep { $_ } ("alert", "alert-$type", $a{'class'}));
my $body = "";
$body .= "<strong>$title</strong>".($br ? "<br>" : " ") if ($title ne '');
$body .= "<span>$content</span>";
return &ui_tag_start('div', \%a).
       &theme_alert_icon($type, $fa).
       "<div class='ui_alert_body'>$body</div>".
       &ui_tag_end('div')."\n";
}

# XXX Temporary until ui-lib.pl valign stuff gets cleaned up
#
# theme_ui_columns_table(&headings, width-percent, &data, &types, no-sort, title,
#		   empty-msg)
# Returns HTML for a complete table.
# headings - An array ref of heading HTML
# width-percent - Preferred total width
# data - A 2x2 array ref of table contents. Each can either be a simple string,
#        or a hash ref like :
#          { 'type' => 'group', 'desc' => 'Some section title' }
#          { 'type' => 'string', 'value' => 'Foo', 'colums' => 3,
#	     'nowrap' => 1 }
#          { 'type' => 'checkbox', 'name' => 'd', 'value' => 'foo',
#            'label' => 'Yes', 'checked' => 1, 'disabled' => 1 }
#          { 'type' => 'radio', 'name' => 'd', 'value' => 'foo', ... }
# types - An array ref of data types, such as 'string', 'number', 'bytes'
#         or 'date'
# no-sort - Set to 1 to disable sorting by theme
# title - Text to appear above the table
# empty-msg - Message to display if no data
# sortable - Set to 1 to mark the table for client-side sorting
sub theme_ui_columns_table
{
my ($heads, $width, $data, $types, $nosort, $title, $emptymsg,
    $sortable) = @_;
my $rv;

# Just show empty message if no data
if ($emptymsg && !@$data) {
	$rv .= &ui_subheading($title) if ($title);
	$rv .= "<b>$emptymsg</b><p>\n";
	return $rv;
	}

# Are there any checkboxes in each column? If so, make those columns narrow
my @tds;
my $maxwidth = 0;
foreach my $r (@$data) {
	my $cc = 0;
	foreach my $c (@$r) {
		if (ref($c) &&
		    ($c->{'type'} eq 'checkbox' || $c->{'type'} eq 'radio')) {
			$tds[$cc] .= " width=5" if ($tds[$cc] !~ /width=/);
			}
		$cc++;
		}
	$maxwidth = $cc if ($cc > $maxwidth);
	}
$rv .= &ui_columns_start($heads, $width, 0, \@tds, $title, $sortable);

# Add the data rows
foreach my $r (@$data) {
	my $c0;
	if (ref($r->[0]) && ($r->[0]->{'type'} eq 'checkbox' ||
			     $r->[0]->{'type'} eq 'radio')) {
		# First column is special
		$c0 = $r->[0];
		$r = [ @$r[1..(@$r-1)] ];
		}
	# Turn data into HTML
	my @rtds = @tds;
	my @cols;
	my $cn = 0;
	$cn++ if ($c0);
	foreach my $c (@$r) {
		if (!ref($c)) {
			# Plain old string
			push(@cols, $c);
			}
		elsif ($c->{'type'} eq 'checkbox') {
			# Checkbox in non-first column
			push(@cols, &ui_checkbox($c->{'name'}, $c->{'value'},
					         $c->{'label'}, $c->{'checked'},
						 $c->{'tags'},
						 $c->{'disabled'}));
			}
		elsif ($c->{'type'} eq 'radio') {
			# Radio button in non-first column
			push(@cols, &ui_oneradio($c->{'name'}, $c->{'value'},
					         $c->{'label'}, $c->{'checked'},
						 $c->{'tags'},
						 $c->{'disabled'}));
			}
		elsif ($c->{'type'} eq 'group') {
			# Header row that spans whole table
			$rv .= &ui_columns_header([ $c->{'desc'} ],
						  [ "colspan=$width" ]);
			next;
			}
		elsif ($c->{'type'} eq 'string') {
			# A string, which might be special
			push(@cols, $c->{'value'});
			if ($c->{'columns'} > 1) {
				splice(@rtds, $cn, $c->{'columns'},
				       "colspan=".$c->{'columns'});
				}
			if ($c->{'nowrap'}) {
				$rtds[$cn] .= " nowrap";
				}
			}
		$cn++;
		}
	# Add the row
	if (!$c0) {
		$rv .= &ui_columns_row(\@cols, \@rtds);
		}
	elsif ($c0->{'type'} eq 'checkbox') {
		$rv .= &ui_checked_columns_row(\@cols, \@rtds, $c0->{'name'},
					       $c0->{'value'}, $c0->{'checked'},
					       $c0->{'disabled'},
					       $c0->{'tags'});
		}
	elsif ($c0->{'type'} eq 'radio') {
		$rv .= &ui_radio_columns_row(\@cols, \@rtds, $c0->{'name'},
					     $c0->{'value'}, $c0->{'checked'},
					     $c0->{'disabled'},
					     $c0->{'tags'});
		}
	}

$rv .= &ui_columns_end();
return $rv;
}

=yui

Functions for generating YUI CSS grids markup.

=cut

# ui_yui_grid_start(id, type)
# Return a yui grid opening div.
# Available types are:
# g - 1/2,1/2
# gb - 1/3, 1/3, 1/3
# gc - 2/3, 1/3
# gd - 1/3, 2/3
# ge - 3/4, 1/4
# gf - 1/4, 3/4
sub theme_ui_yui_grid_start {
	my ($id, $type) = @_;
	return "<div id='grid_$id' class='yui-$type'>\n";
}

sub theme_ui_yui_grid_end {
	my ($id) = @_;
	return "</div> <!-- grid_$id -->\n";
}

# ui_yui_grid_section_start(id, first?)
# Return a yui grid markup section opening div.
sub theme_ui_yui_grid_section_start {
	my ($id, $first) = @_;
	if ($first) { return "<div id='grid_$id' class='yui-u first'>\n"; }
	else { return "<div id='grid_$id' class='yui-u'>\n"; }
}
sub theme_ui_yui_grid_section_end {
	my ($id) = @_;
	return "</div> <!-- grid_$id -->\n";
}

1;

