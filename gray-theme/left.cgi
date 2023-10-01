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
our %miniserv;
our %gaccess;
our $session_id;

our $trust_unknown_referers = 1;
require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";
ReadParse();

popup_header("Virtualmin");

my $is_master;
# Is this user root?
if (foreign_available("virtual-server")) {
	foreign_require("virtual-server");
	$is_master = virtual_server::master_admin();
	}
elsif (foreign_available("server-manager")) {
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
		     'desc' => $title->{'desc'},
		     'icon' => $title->{'icon'} });
	$modmenu{$title->{'module'}}++;
	}
my $nw = $sects->{'nowebmin'} || 0;
if ($nw == 0 || $nw == 2 && $is_master) {
	my $p = get_product_name();
	push(@has, { 'id' => 'modules',
		     'desc' => $text{'has_'.$p},
		     'icon' => '/images/'.$p.'-small.png' });
	}

# Default left-side mode
my $mode = $in{'mode'} ? $in{'mode'} :
	   $sects->{'tab'} && $sects->{'tab'} =~ /vm2/ ? "server-manager" :
	   $sects->{'tab'} && $sects->{'tab'} =~ /virtualmin/ ? "virtual-server" :
	   $sects->{'tab'} && $sects->{'tab'} =~ /mail/ ? "mailboxes" :
	   $sects->{'tab'} && $sects->{'tab'} =~ /webmin/ ? "modules" :
	   @leftitems ? $has[0]->{'id'} : "modules";

# Show mode selector
if (indexof($mode, (map { $_->{'id'} } @has)) < 0) {
	$mode = $has[0]->{'id'};
	}
if (@has > 1) {
	print "<div class='mode'>";
	foreach my $m (@has) {
		print "<b data-mode='$m->{'id'}'>";
		if ($m->{'id'} ne $mode) {
			print "<a href='left.cgi?mode=$m->{'id'}'>";
			}
		if ($m->{'icon'}) {
			my $icon = add_webprefix($m->{'icon'});
			print "<img src='$icon' alt='$m->{'id'}'> ";
			}
		print $m->{'desc'};
		if ($m->{'id'} ne $mode) {
			print "</a>\n";
			}
		print "</b>\n";
		}
	print "</div>";
	}
print &ui_switch_theme_javascript();
print "<div class='wrapper leftmenu'>\n";
print "<table id='main' width='100%'><tbody><tr><td>\n";

my $selwidth = (get_left_frame_width() - 70)."px";
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

# Show Webmin search form
my $cansearch = ($gaccess{'webminsearch'} || '') ne '0' &&
		!$sects->{'nosearch'};
if ($mode eq "modules" && $cansearch) {
	push(@leftitems, { 'type' => 'input',
			   'desc' => ' ',
			   'tags' => " placeholder='$text{'left_search'}' style='width: 92%;'",
			   'size' => 10,
			   'name' => 'search',
			   'cgi' => '/webmin_search.cgi', });
	push(@leftitems, { 'type' => 'hr' });
	}
# Show system information link
push(@leftitems, { 'type' => 'item',
		   'id' => 'home',
		   'desc' => $text{'left_home'},
		   'link' => '/right.cgi',
		   'icon' => '/images/gohome.png' });

# Show refresh modules link
if ($mode eq "modules" && foreign_available("webmin")) {
	push(@leftitems, { 'type' => 'item',
			   'id' => 'refresh',
			   'desc' => $text{'main_refreshmods'},
			   'link' => '/webmin/refresh_modules.cgi',
			   'icon' => '/images/reload.png' });
	}

# Show logout link
get_miniserv_config(\%miniserv);
if ($miniserv{'logout'} && !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	my $logout = { 'type' => 'item',
		       'id' => 'logout',
		       'target' => 'window',
		       'icon' => '/images/stock_quit.png' };
	if ($main::session_id) {
		$logout->{'desc'} = $text{'main_logout'};
		$logout->{'link'} = '/session_login.cgi?logout=1';
		}
	else {
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
			  'icon' => '/images/webmin-small.gif',
			  'target' => 'window' });
	}

show_menu_items_list(\@leftitems, 0);

print "</td></tr></tbody></table>\n";
print <<EOF;
<script type='text/javascript'>
(function() {
	var imgs = document.querySelectorAll('img[src]'),
		mailfolders = 0;
	imgs.forEach(function(img) {
		var i = document.createElement("i");
		if (img.src) {
			if (img.src.includes('webmin-small.png')) {
				i.classList.add('ff', 'ff-webmin');
			} else if (img.src.includes('usermin-small.png')) {
				i.classList.add('ff', 'ff-webmin', 'ff-usermin');
			} else if (img.src.includes('virtualmin.png')) {
				i.classList.add('ff', 'ff-virtualmin');
			} else if (img.src.includes('vm2.png')) {
				i.classList.add('ff', 'ff-cloudmin');
			} else if (img.src.includes('index.png')) {
				i.classList.add('ff', 'ff-fw', 'ff-virtualmin-tick');
			} else if (img.src.includes('graph.png')) {
				i.classList.add('ff', 'ff-fw', 'ff-chart');
			} else if (img.src.includes('gohome.png')) {
				i.classList.add('ff', 'ff-fw', 'ff-home');
			} else if (img.src.includes('stock_quit.png')) {
				i.classList.add('ff', 'ff-fw', 'ff-sign-out');
			} else if (img.src.includes('reload.png')) {
				i.classList.add('ff', 'ff-fw', 'ff-refresh');
			} else if (img.src.includes('mail.') && !mailfolders) {
				i.classList.add('ff', 'ff-mail');
				mailfolders = 1;
			} else if (img.src.includes('mail.') && mailfolders) {
				i.classList.add('ff', 'ff-folder-open');
			} else if (img.src.includes('address.')) {
				i.classList.add('ff', 'ff-address-book');
			} else if (img.src.includes('address.')) {
				i.classList.add('ff', 'ff-address-book');
			} else if (img.src.includes('sig.')) {
				i.classList.add('ff', 'ff-signature');
			} else if (img.src.includes('changepass.')) {
				i.classList.add('ff', 'ff-lock');
			}
			if (i.classList.length) {
				img.replaceWith(i);
			}
		}
	});
	var inputs = document.querySelectorAll('input[src]');
	inputs.forEach(function(input) {
		var b = document.createElement("button"),
			i = document.createElement("i");
		if (input.src) {
			if (input.src.includes('ok.png')) {
				i.classList.add('ff', 'ff-play-circle');
				b.type = 'submit';
				b.classList.add('servers-submit');
				b.appendChild(i);
				input.replaceWith(b);
			}
		}
	});
})();
</script>
EOF
print "</div>\n";
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
			$t = '_blank';
			$link = $item->{'link'};
			}
		if ($item->{'icon'}) {
			my $icon = add_webprefix($item->{'icon'});
			print "<div class='linkwithicon".
			      ($item->{'inactive'} ? ' inactive' : '')."'>".
			      "<img src='$icon' alt=''>\n";
			}
		my $cls = $item->{'icon'} ? 'aftericon' :
		          $indent ? 'linkindented'.
		                    ($item->{'inactive'} ? ' inactive' : '').
		                    '' : 'leftlink';
		print "<div class='$cls'>";
		print "<a href='$link' target=$t>".
		      "$item->{'desc'}</a>";
		print "</div>";
		if ($item->{'icon'}) {
			print "</div>";
			}
		print "\n";
		}
	elsif ($item->{'type'} eq 'cat') {
		# Start of a new category
		my $c = $item->{'id'};
		print "<details>";
		print "<summary><span>$item->{'desc'}</span></summary>";
		show_menu_items_list($item->{'members'}, $indent+1);
		print "</details>\n";
		}
	elsif ($item->{'type'} eq 'html') {
		# Some HTML block
		print "<div class='leftlink'>",$item->{'html'},"</div>\n";
		}
	elsif ($item->{'type'} eq 'text') {
		# A line of text
		print "<div class='leftlink'>",
		      html_escape($item->{'desc'}),"</div>\n";
		}
	elsif ($item->{'type'} eq 'hr') {
		# Separator line
		print "<hr>\n";
		}
	elsif ($item->{'type'} eq 'menu' || $item->{'type'} eq 'input') {
		# For with an input of some kind
		if ($item->{'cgi'}) {
			my $cgi = add_webprefix($item->{'cgi'});
			print "<form action='$cgi' target=right>\n";
			}
		else {
			print "<form>\n";
			}
		foreach my $h (@{$item->{'hidden'}}) {
			print ui_hidden(@$h);
			}
		print ui_hidden("mode", $mode);
		print "<div class='leftlink'>";
		print $item->{'desc'},"\n";
		if ($item->{'type'} eq 'menu') {
			my $sel = "";
			if ($item->{'onchange'}) {
				$sel = "window.parent.frames[1].location = ".
				       "\"$item->{'onchange'}\" + this.value";
				}
			print ui_select($item->{'name'}, $item->{'value'},
					 $item->{'menu'}, 1, 0, 0, 0,
					 "onChange='form.submit(); $sel' ".
					 "style='width:$selwidth'");
			}
		elsif ($item->{'type'} eq 'input') {
			print ui_textbox($item->{'name'}, $item->{'value'},
					  $item->{'size'}, undef, undef, $item->{'tags'});
			}
		if ($item->{'icon'}) {
			my $icon = add_webprefix($item->{'icon'});
			print "<input type=image src='$icon' ".
			      "border=0 class=goArrow>\n";
			}
		print "</div>";
		print "</form>\n";
		}
	elsif ($item->{'type'} eq 'title') {
		# Nothing to print here, as it is used for the tab title
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
