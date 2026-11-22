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

# theme_config_return_link(module, url, [footer-label])
# Return to the framed dashboard after editing Virtualmin settings.
sub theme_config_return_link
{
my ($module, $url, $label) = @_;
if ($module eq "virtual-server") {
	my %lang = defined($label) ? &load_language($current_theme) : ( );
	return ( "/right.cgi", $lang{'config_return'} );
	}
return ( $url, $label );
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
# Called by Virtualmin after a domain is updated, to refresh the left menu
sub theme_post_save_domain
{
local ($d, $action) = @_;
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
print "<script>\n";
print "top.left.location = top.left.location;\n";
print "</script>\n";
}

# theme_post_save_server(&server, action)
# Called by Cloudmin after a server is updated, to refresh the left menu
sub theme_post_save_server
{
local ($s, $action) = @_;
if ($action eq 'create' || $action eq 'delete' ||
    !$done_theme_post_save_server++) {
	print "<script>\n";
	print "top.left.location = top.left.location;\n";
	print "</script>\n";
	}
}

# theme_select_server(&server)
# Called by Cloudmin when a page for a server is displayed, to select it on the
# left menu.
sub theme_select_server
{
local ($server) = @_;
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
# Called by Virtualmin when a page for a server is displayed, to select it on
# the left menu.
sub theme_select_domain
{
local ($d) = @_;
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
	print "<script>\n";
	print "top.frames[0].document.location = top.frames[0].document.location;\n";
	print "</script>\n";
	}
}

sub theme_post_change_modules
{
print <<EOF;
<script>
var url = '' + top.left.location;
if (url.indexOf('mode=modules') > 0) {
    top.left.location = url;
    }
</script>
EOF
}

# theme_prebody(header-args...)
# Hides the module index link on Virtualmin pages, whose menu is already
# in the left frame
sub theme_prebody
{
if (get_module_name() eq "virtual-server") {
	# No need for Module Index link, as we have the left-side frame
	$tconfig{'nomoduleindex'} = 1;
	}
}

# theme_prehead()
# Prints the head parts of every page: the color scheme meta, the scheme
# and frame scripts, and the links to the stylesheet and the table sorting
# script. The menu frame also gets the chosen menu colors stylesheet.
# Also sets the body attributes the stylesheet keys on: the module name as
# a class and the forced color scheme, if any.
sub theme_prehead
{
my $pfx = &get_webprefix();
my $scheme = &theme_color_scheme();
print "<meta name='color-scheme' content='".($scheme || "light dark")."'>\n";
print &theme_scheme_script($scheme);
print &theme_frame_script();
print "<link rel='stylesheet' type='text/css' href='$pfx/unauthenticated/".
      "gray-theme.css?".&theme_asset_key("gray-theme.css")."'>\n";
my $css = &theme_menu_stylesheet();
if ($css && $main::gray_theme_body_class &&
    $main::gray_theme_body_class eq 'left-frame') {
	# The chosen menu colors, in the menu frame only
	print "<link rel='stylesheet' type='text/css' href='$pfx/".
	      "unauthenticated/$css?".&theme_asset_key($css)."'>\n";
	}
print "<script type='text/javascript' src='$pfx/unauthenticated/".
      "sorttable.js?".&theme_asset_key("sorttable.js")."'></script>\n";
my @cls = grep { $_ } ( $main::gray_theme_body_class, &get_module_name() );
$tconfig{'inbody'} = (@cls ? "class='".join(" ", @cls)."'" : "").
		     ($scheme ? " data-scheme='$scheme'" : "");
}

# theme_scheme_script([forced-scheme])
# Returns color scheme scripts and Alt+T/Alt+R shortcuts for all frames.
# forced-scheme sets light or dark; omitting it follows the system.
# Alt+T overrides the scheme for this tab; Alt+R reloads the content frame.
sub theme_scheme_script
{
my ($forced) = @_;
$forced = $forced && $forced =~ /^(light|dark)$/ ? $1 : "";
my $rv = <<'EOF';
<script type='text/javascript'>
/* initializeGrayTheme(): Apply the scheme and bind frame shortcuts. */
(function() {
var key = 'gray-theme-scheme', overrideKey = key + '-override',
    forced = '__GRAY_THEME_FORCED_SCHEME__',
    root = document.documentElement,
    mq = window.matchMedia('(prefers-color-scheme: dark)'),
    stored = null, changed = false;
try { stored = localStorage.getItem(key); } catch(e) { }
/* valid(value): Return whether value is a supported scheme. */
function valid(v) { return v == 'dark' || v == 'light'; }
/* browserScheme(): Return the scheme selected by the browser. */
function browserScheme() { return mq.matches ? 'dark' : 'light'; }
/* baseScheme(): Return the configured scheme or system preference. */
function baseScheme() { return valid(forced) ? forced : browserScheme(); }
/* getOverride(): Read this tab's override when storage is available. */
function getOverride() {
	try { return sessionStorage.getItem(overrideKey); }
	catch(e) { return null; }
	}
/* rememberOverride(value): Store only a scheme that differs from the base. */
function rememberOverride(v) {
	try {
		/* Remove an override that now matches the base. */
		if (v == baseScheme()) sessionStorage.removeItem(overrideKey);
		/* Keep a different choice for later pages in this tab. */
		else sessionStorage.setItem(overrideKey, v);
		}
	catch(e) { }
	}
/* apply(value, [remember]): Apply a scheme and optionally cache it. */
function apply(v, remember) {
	/* Ignore malformed values from storage or another frame. */
	if (!valid(v)) return;
	root.setAttribute('data-scheme', v);
	/* Update body selectors once the body exists. */
	if (document.body) document.body.setAttribute('data-scheme', v);
	/* Let newly loaded frames inherit the frameset scheme. */
	if (self == top) root.style.colorScheme = v;
	/* Do not cache a scheme relayed from another frame. */
	if (remember !== false) {
		try { localStorage.setItem(key, v); } catch(e) { }
		}
	}
/* grayThemeApplyScheme(value, [remember]): Apply a relayed scheme. */
window.grayThemeApplyScheme = function(v, remember) {
	changed = true;
	/* Save a relayed user choice as this tab's override. */
	if (remember) rememberOverride(v);
	apply(v, false);
	};
/* applyEverywhere(value): Apply a scheme across the frameset. */
function applyEverywhere(v) {
	changed = true;
	rememberOverride(v);
	apply(v);
	try {
		/* Relay a child-frame change to the frameset. */
		if (top != window && top.grayThemeApplyScheme)
			top.grayThemeApplyScheme(v, true);
		}
	catch(e) { }
	/* syncFrame(name): Apply the scheme to one named frame. */
	['left', 'right'].forEach(function(name) {
		try {
			var frame = top.frames[name];
			/* Skip this document and frames that are not ready. */
			if (frame && frame != window && frame.grayThemeApplyScheme)
				frame.grayThemeApplyScheme(v, true);
			}
		catch(e) { }
		});
	}
/* Prefer the tab override, configured scheme, saved scheme, then system. */
var override = getOverride();
apply(valid(override) ? override :
      valid(forced) ? forced :
      valid(stored) ? stored : browserScheme());
/* syncBodyScheme(): Copy the root scheme to the new body. */
document.addEventListener('DOMContentLoaded', function() {
	apply(root.getAttribute('data-scheme'), false);
	});
/* onchange(): Follow system changes unless a tab override is active. */
function onchange() {
	var override = getOverride(), current = browserScheme();
	/* Preserve an override that differs from the system scheme. */
	if (valid(override) && override != current) return;
	/* Remove an override once the system reaches the same scheme. */
	if (valid(override)) rememberOverride(current);
	changed = true;
	apply(current);
	}
/* A configured scheme does not follow system preference changes. */
if (!valid(forced)) {
	/* Prefer the current media-query listener API. */
	if (mq.addEventListener) mq.addEventListener('change', onchange);
	/* Fall back to the older listener API. */
	else mq.addListener(onchange);
	}
/* handleThemeShortcut(event): Handle Alt+T and Alt+R in any frame. */
document.addEventListener('keydown', function(event) {
	/* Ignore other modifiers, repeats, composition and handled events. */
	if (event.defaultPrevented || event.repeat || event.isComposing ||
	    !event.altKey || event.ctrlKey || event.metaKey || event.shiftKey)
		return;
	/* Leave typing alone, as Alt enters characters on some keyboards. */
	var target = event.target || { };
	if (target.isContentEditable || target.tagName == 'TEXTAREA' ||
	    (target.tagName == 'INPUT' &&
	     !/^(button|checkbox|radio|submit|reset|image|file|range|color)$/
	      .test(target.type)))
		return;
	/* Alt+T toggles the palette throughout the frameset. */
	if (event.code == 'KeyT' || event.keyCode == 84) {
		event.preventDefault();
		event.stopPropagation();
		applyEverywhere(root.getAttribute('data-scheme') == 'dark' ?
			'light' : 'dark');
		}
	/* Alt+R reloads content without refreshing navigation. */
	else if (event.code == 'KeyR' || event.keyCode == 82) {
		var frame = null;
		try { frame = top.frames['right']; } catch(e) { }
		/* Do not claim the browser shortcut outside the main frameset. */
		if (!frame) return;
		event.preventDefault();
		event.stopPropagation();
		try { frame.location.reload(); } catch(e) { }
		}
	}, true);
/* Recheck an automatic scheme after the top-level page loads. */
if (self == top && !valid(forced))
	/* refreshBrowserScheme(): Recheck after all frames load. */
	window.addEventListener('load', function() {
		/* refreshUnchangedScheme(): Correct untouched automatic state. */
		setTimeout(function() {
			/* Preserve user changes and tab overrides. */
			if (!changed && !valid(getOverride()))
				applyEverywhere(browserScheme());
			}, 1000);
		});
})();
</script>
EOF
$rv =~ s/__GRAY_THEME_FORCED_SCHEME__/$forced/g;
return $rv;
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

# theme_settings()
# Returns the theme settings as a hash reference, per user unless they are
# global. The file is read once per request.
sub theme_settings
{
return $main::gray_theme_settings if ($main::gray_theme_settings);
my $file = "$config_directory/$current_theme/sections";
my %sects;
&read_file($file, \%sects);
if (!$sects{'global'}) {
	# Unless the global settings are forced on everyone, the user's own
	# file replaces them
	my %usects;
	%sects = %usects if (&read_file("$file.$remote_user", \%usects));
	}
$main::gray_theme_settings = \%sects;
return $main::gray_theme_settings;
}

# theme_color_scheme()
# Returns light or dark when the theme settings force a color scheme, or an
# empty string to follow the browser
sub theme_color_scheme
{
my $scheme = &theme_settings()->{'scheme'};
return $scheme && $scheme =~ /^(light|dark)$/ ? $1 : "";
}

# theme_menu_stylesheet()
# Returns the stylesheet of the chosen menu colors, or an empty string for
# a menu in the page colors
sub theme_menu_stylesheet
{
my $menu = &theme_settings()->{'menu'} || "";
my %css = ( 'blue' => 'gray-theme-menu-navi-blue.css',
	    'lightblue' => 'gray-theme-menu-light-blue.css',
	    'darkgray' => 'gray-theme-menu-dark-gray.css' );
return $css{$menu} || "";
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

# theme_popup_prehead(title, ...)
# Popup windows and the frames get the same head as ordinary pages
sub theme_popup_prehead
{
return &theme_prehead();
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

# theme_ui_grid_table(&elements, columns, [width-percent], [&tds], [tabletags], [title])
# Render a grid inside the Framed theme's wrapper table.
sub theme_ui_grid_table
{
my ($elements, $cols, $width, $tds, $tabletags, $title) = @_;
return "" if (!@$elements);

my $rv = "<table class='wrapper' "
       . ($width ? " width=$width%" : " width=100%")
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
$rv .= "</tbody></table>\n";
$rv .= "</td></tr></table>\n"; # wrapper
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
       &ui_alert_icon($type, $fa).
       "<div class='ui_alert_body'>$body</div>".
       &ui_tag_end('div')."\n";
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

