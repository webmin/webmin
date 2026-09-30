#!/usr/local/bin/perl
# Show the left-side menu of Virtualmin domains, plus modules
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

# Globals
our %in;
our %text;
our $base_remote_user;
our $remote_user;
our %miniserv;
our %gaccess;
our $session_id;

our $trust_unknown_referers = 1;
require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";
ReadParse();

# The body class selects the left frame styles
our $gray_theme_body_class = 'left-frame';

my $is_master;
# Is this user the master administrator? Virtualmin and Cloudmin each
# have their own test for it
if (foreign_available("virtual-server")) {
	# Virtualmin's master admin
	foreign_require("virtual-server");
	$is_master = virtual_server::master_admin();
	}
elsif (foreign_available("server-manager")) {
	# Cloudmin's user with global permissions
	foreign_require("server-manager");
	$is_master = server_manager::can_action(undef, "global");
	}

# Find all left-side items from Webmin
my $sects = get_right_frame_sections();
my @leftitems = list_combined_webmin_menu($sects, \%in);
my @lefttitles = grep { $_->{'type'} eq 'title' } @leftitems;

# Work out what mode selector contains
my @has = ( );
my %modmenu;
foreach my $title (@lefttitles) {
	push(@has, { 'id' => $title->{'module'},
		     'desc' => $title->{'desc'} });
	$modmenu{$title->{'module'}}++;
	}
my $nw = $sects->{'nowebmin'} || 0;
if ($nw == 0 || $nw == 2 && $is_master) {
	# The Webmin modules mode is offered unless the settings hide it,
	# from everyone or from all but the master
	my $p = get_product_name();
	push(@has, { 'id' => 'modules',
		     'desc' => $text{'has_'.$p} });
	}

# Default left-side mode
my $mode = $in{'mode'} ? $in{'mode'} :
	   $sects->{'tab'} && $sects->{'tab'} =~ /vm2/ ? "server-manager" :
	   $sects->{'tab'} && $sects->{'tab'} =~ /virtualmin/ ? "virtual-server" :
	   $sects->{'tab'} && $sects->{'tab'} =~ /mail/ ? "mailboxes" :
	   $sects->{'tab'} && $sects->{'tab'} =~ /webmin/ ? "modules" :
	   @leftitems ? $has[0]->{'id'} : "modules";
if (indexof($mode, (map { $_->{'id'} } @has)) < 0) {
	# A mode that is not offered falls back to the first one
	$mode = $has[0]->{'id'};
	}

# Product shown in the brand block, and its name
my $prod = foreign_available("server-manager") ? 'cloudmin' :
	   foreign_available("virtual-server") ? 'virtualmin' :
	   get_product_name() eq 'usermin' ? 'usermin' : 'webmin';
my %prodnames = ( 'cloudmin' => $text{'has_vm2'},
		  'virtualmin' => $text{'has_virtualmin'},
		  'usermin' => $text{'has_usermin'},
		  'webmin' => $text{'has_webmin'} );

popup_header($prodnames{$prod});

# The whole menu sits in one panel that floats on the page ground
print "<div class='menu-panel'>\n";

if ($mode eq "modules") {
	# Only showing Webmin modules
	@leftitems = &list_modules_webmin_menu();
	foreach my $l (@leftitems) {
		$l->{'members'} = [ grep { !$modmenu{$_->{'id'}} } @{$l->{'members'}} ];
		}
	push(@leftitems, { 'type' => 'hr' });
	}
else {
	# Only show items under some title OR items that have no title
	my ($lefttitle) = grep { $_->{'id'} eq $mode } @lefttitles;
	my %titlemods = map { $_->{'module'}, $_ } @lefttitles;
	@leftitems = grep { $_->{'module'} eq $mode ||
			    !$titlemods{$_->{'module'}} } @leftitems;
	}
@leftitems = grep { $_->{'type'} ne 'title' } @leftitems;

# Lines of text at the start of the menu, such as the login and its level,
# go into the brand block instead of the menu
my @userlines;
while(@leftitems && $leftitems[0]->{'type'} eq 'text') {
	my $t = shift(@leftitems);
	if ($t->{'json'} && $t->{'json'}->{'label'}) {
		# Login line, shown as the username and its level
		push(@userlines, "<b>".html_escape($remote_user)."</b>".
			($t->{'json'}->{'level'} ?
			    " &middot; ".$t->{'json'}->{'level'} : ""));
		}
	else {
		# Any other line of text, as it is
		push(@userlines, html_escape($t->{'desc'}));
		}
	}
if (@userlines && $leftitems[0]->{'type'} eq 'hr') {
	# The separator after the text lines goes with them
	shift(@leftitems);
	}
if (!@userlines) {
	# Without a login line, show the username alone
	push(@userlines, "<b>".html_escape($remote_user || $base_remote_user).
			 "</b>");
	}

# The brand block and the product switch stay at the top of the panel
# while the menu scrolls under them. The loader is the bar that bounces
# along the top edge while the right frame loads a page.
print "<div class='menu-top'>\n";
print "<div class='menu-loader'></div>\n";

# Show the brand block, with the product logo in a light and a dark
# version for the stylesheet to pick from
my $imgdir = add_webprefix("/images");
my $alt = html_escape($prodnames{$prod});
print "<div class='menu-brand'>\n";
print "<a class='menu-brand-name' href='".add_webprefix("/right.cgi").
      "' target='right' title='$alt'>";
print "<img class='menu-brand-logo' src='$imgdir/logos/$prod.svg' ".
      "alt='$alt'>";
print "<img class='menu-brand-logo menu-brand-logo-dark' ".
      "src='$imgdir/logos/$prod-dark.svg' alt='$alt'>";
print "</a>\n";
# The host and the login, as small lines with icons
print "<div class='menu-meta'>\n";
print "<div class='menu-host'>".ui_svg_icon('server', { 'size' => 13 }).
      "<span>".html_escape(get_display_hostname())."</span></div>\n";
foreach my $l (@userlines) {
	print "<div class='menu-user'>".ui_svg_icon('user', { 'size' => 13 }).
	      "<span>$l</span></div>\n";
	}
print "</div>\n";
print "</div>\n";

# Show mode selector
if (@has > 1) {
	print "<div class='mode'>";
	foreach my $m (@has) {
		print "<b data-mode='$m->{'id'}'>";
		if ($m->{'id'} ne $mode) {
			# The click marks the switch as loading until the
			# menu has been replaced
			print "<a href='left.cgi?mode=$m->{'id'}' ".
			      "onclick=\"this.parentNode.parentNode.".
			      "classList.add('loading');".
			      "this.parentNode.classList.add('active')\">";
			}
		print $m->{'desc'};
		if ($m->{'id'} ne $mode) {
			# Close the link of an unselected mode
			print "</a>";
			}
		print "</b>\n";
		}
	print "</div>\n";
	}
print "</div>\n";
print &ui_switch_theme_javascript();
print "<div class='leftmenu'>\n";

# Show Webmin search form
my $cansearch = ($gaccess{'webminsearch'} || '') ne '0' &&
		!$sects->{'nosearch'};
if ($mode eq "modules" && $cansearch) {
	push(@leftitems, { 'type' => 'input',
			   'desc' => ' ',
			   'tags' => " placeholder='$text{'left_search'}'",
			   'size' => 10,
			   'name' => 'search',
			   'cgi' => '/webmin_search.cgi', });
	push(@leftitems, { 'type' => 'hr' });
	}
# Show system information link
push(@leftitems, { 'type' => 'item',
		   'id' => 'home',
		   'desc' => $text{'left_home'},
		   'link' => '/right.cgi' });

# Show refresh modules link
if ($mode eq "modules" && foreign_available("webmin")) {
	push(@leftitems, { 'type' => 'item',
			   'id' => 'refresh',
			   'desc' => $text{'main_refreshmods'},
			   'link' => '/webmin/refresh_modules.cgi' });
	}

# Show logout link
get_miniserv_config(\%miniserv);
if ($miniserv{'logout'} && !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	my $logout = { 'type' => 'item',
		       'id' => 'logout',
		       'target' => 'window' };
	if ($main::session_id) {
		# Session logins can log out
		$logout->{'desc'} = $text{'main_logout'};
		$logout->{'link'} = '/session_login.cgi?logout=1';
		}
	else {
		# Other logins can only switch to another user
		$logout->{'desc'} = $text{'main_switch'};
		$logout->{'link'} = '/switch_user.cgi';
		}
	push(@leftitems, $logout);
	}

# Show link back to original Webmin server
if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
	push(@leftitems, { 'type' => 'item',
			  'desc' => $text{'header_servers'},
			  'link' => $ENV{'HTTP_WEBMIN_SERVERS'},
			  'target' => 'window' });
	}

show_menu_items_list(\@leftitems, 0);

print "</div>\n";
print "</div>\n";

# The loader starts on a click or a form submission aimed at the right
# frame and stops when the new page there reports, through the functions
# below, that it has loaded; a stuck loader stops on its own after 20
# seconds
print <<'EOF';
<script type='text/javascript'>
(function() {
var root = document.documentElement, timer;
function start() {
	root.classList.add('loading-right');
	clearTimeout(timer);
	timer = setTimeout(stop, 20000);
	}
function stop() {
	root.classList.remove('loading-right');
	clearTimeout(timer);
	}
window.rightLoading = start;
window.rightLoaded = stop;
// Links and forms aimed at the right frame start the loader
document.addEventListener('click', function(e) {
	var a = e.target.closest ? e.target.closest('a') : null;
	if (a && a.target == 'right' && !/^javascript:/.test(a.href)) start();
	});
document.addEventListener('submit', function(e) {
	if (e.target.target == 'right') start();
	});
})();
</script>
EOF
popup_footer();

# show_menu_items_list(&list, indent)
# Actually prints the HTML for menu items
sub show_menu_items_list
{
my ($items, $indent) = @_;
foreach my $item (@$items) {
	if ($item->{'type'} eq 'item') {
		# Link to some page
		my $it = $item->{'target'} || '';
		my $t = $it eq 'new' ? '_blank' :
			$it eq 'window' ? '_top' : 'right';
		my $link = add_webprefix($item->{'link'});
		if ($item->{'link'} =~ /^(https?):\/\//) {
			# Links to other sites open in a new window
			$t = '_blank';
			$link = $item->{'link'};
			}
		my $cls;
		if ($item->{'format'} eq 'link-new') {
			# Creation link shown as a button with a plus
			$cls = 'menu-create';
			$item->{'desc'} = ui_svg_icon('plus', { 'size' => 15 }).
					  " ".$item->{'desc'};
			}
		else {
			# Ordinary link, indented inside a category and muted
			# when inactive
			$cls = 'menu-link';
			$cls .= ' menu-sub' if ($indent);
			$cls .= ' inactive' if ($item->{'inactive'});
			if ($item->{'id'} eq 'logout') {
				# Logout gets an icon and a muted look
				$cls .= ' menu-logout';
				$item->{'desc'} = ui_svg_icon('power', { 'size' => 14 }).
						  " ".$item->{'desc'};
				}
			}
		print "<a class='$cls' href='$link' target='$t'>".
		      "$item->{'desc'}</a>\n";
		}
	elsif ($item->{'type'} eq 'cat') {
		# Start of a new category, opened when requested by the
		# frameset page
		my $c = $item->{'id'};
		print "<details class='menu-cat'".($in{$c} ? " open" : "").">";
		print "<summary><span>$item->{'desc'}</span></summary>\n";
		show_menu_items_list($item->{'members'}, $indent+1);
		print "</details>\n";
		}
	elsif ($item->{'type'} eq 'html') {
		# Some HTML block
		print "<div class='menu-html'>",$item->{'html'},"</div>\n";
		}
	elsif ($item->{'type'} eq 'text') {
		# A line of text
		print "<div class='menu-text'>",
		      html_escape($item->{'desc'}),"</div>\n";
		}
	elsif ($item->{'type'} eq 'hr') {
		# Separator line
		print "<hr class='menu-divider'>\n";
		}
	elsif ($item->{'type'} eq 'menu' || $item->{'type'} eq 'input') {
		# Form with an input of some kind
		if ($item->{'cgi'}) {
			# The form submits to the item's CGI in the right frame
			my $cgi = add_webprefix($item->{'cgi'});
			print "<form class='menu-form' action='$cgi' ".
			      "target='right'>\n";
			}
		else {
			# Without a CGI, the form reloads this menu with the
			# new value
			print "<form class='menu-form'>\n";
			}
		foreach my $h (@{$item->{'hidden'}}) {
			print ui_hidden(@$h);
			}
		print ui_hidden("mode", $mode);
		my $label = $item->{'desc'} =~ /\S/ ? $item->{'desc'}
						     : $text{'left_'.$item->{'name'}};
		if ($label) {
			# Small caps label above the field
			print "<label class='menu-label' for='".
			      html_escape($item->{'name'})."'>$label</label>\n";
			}
		print "<div class='menu-field'>\n";
		if ($item->{'type'} eq 'menu') {
			# A drop-down that submits as soon as it changes
			my $sel = "";
			if ($item->{'onchange'}) {
				# Some menus also load a page for the chosen
				# value in the right frame
				$sel = "window.parent.frames[1].location = ".
				       "\"$item->{'onchange'}\" + this.value";
				}
			print ui_select($item->{'name'}, $item->{'value'},
					 $item->{'menu'}, 1, 0, 0, 0,
					 "onChange='form.submit(); $sel'");
			}
		elsif ($item->{'type'} eq 'input') {
			# A text field, such as the search box
			print ui_textbox($item->{'name'}, $item->{'value'},
					  $item->{'size'}, undef, undef, $item->{'tags'});
			}
		print "</div>\n";
		print "</form>\n";
		}
	}
}

# module_to_menu_item(&module)
# Converts a module to the hash ref format expected by show_menu_items_list
sub module_to_menu_item
{
my ($minfo) = @_;
return { 'type' => 'item',
	 'id' => $minfo->{'dir'},
	 'desc' => $minfo->{'desc'},
	 'link' => '/'.$minfo->{'dir'}.'/' };
}

# add_webprefix(link)
# If a URL starts with a / , add webprefix
sub add_webprefix
{
my ($link) = @_;
return $link =~ /^\// ? &get_webprefix().$link : $link;
}
