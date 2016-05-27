#!/usr/bin/perl
# Show the left-side menu of Webmin modules

use strict;
use warnings;
require 'gray-theme/gray-theme-lib.pl';
&ReadParse();
our ($current_theme, $remote_user, %gconfig);
our %text = &load_language($current_theme);
my %gaccess = &get_module_acl(undef, "");

&popup_header();
print <<EOF;
<link rel="stylesheet" type="text/css" href="gray-left.css" />
<script>
function toggleview (id1,id2) {
		var obj1 = document.getElementById(id1);
		var obj2 = document.getElementById(id2);
		(obj1.className=="itemshown") ? obj1.className="itemhidden" : obj1.className="itemshown"; 
		(obj1.className=="itemshown") ? obj2.innerHTML="<img border='0' src='images/gray-open.gif' alt='[&ndash;]'>" : obj2.innerHTML="<img border='0' src='images/gray-closed.gif' alt='[+]'>"; 
	}

// Show the logs for the current module in the right
function show_logs() {
  var url = ''+window.parent.frames[1].location;
  var sl1 = url.indexOf('//');
  var mod = '';
  if (sl1 > 0) {
    var sl2 = url.indexOf('/', sl1+2);
    if (sl2 > 0) {
      var sl3 = url.indexOf('/', sl2+1);
      if (sl3 > 0) {
        mod = url.substring(sl2+1, sl3);
      } else {
        mod = url.substring(sl2+1);
      }
    }
  }
if (mod && mod.indexOf('.cgi') <= 0) {
  // Show one module's logs
  window.parent.frames[1].location = 'webminlog/search.cgi?tall=4&uall=1&fall=1&mall=0&module='+mod;
  }
else {
  // Show all logs
  window.parent.frames[1].location = 'webminlog/search.cgi?tall=4&uall=1&fall=1&mall=0&mall=1'
  }
}
</script>
</head>
<body>
EOF

# Show login
my @leftmenu;
push(@leftmenu, { 'type' => 'text',
		  'desc' => &text('left_login', $remote_user) });
push(@leftmenu, { 'type' => 'hr' });

# Webmin modules
push(@leftmenu, &list_modules_webmin_menu());

# Show module/help search form
if ($gaccess{'webminsearch'}) {
	push(@leftmenu, { 'type' => 'input',
			  'cgi' => $gconfig{'webprefix'}.'/webmin_search.cgi',
			  'name' => 'search',
			  'desc' => $text{'left_search'},
			  'size' => 15 });
	}

push(@leftmenu, { 'type' => 'hr' });

# Show current module's log search, if logging
if ($gconfig{'log'} && &foreign_available("webminlog")) {
	push(@leftmenu, { 'type' => 'item',
			  'desc' => $text{'left_logs'},
			  'link' => '/webminlog/',
			  'icon' => '/images/logs.gif',
			  'onclick' => 'show_logs(); return false;' });
	}

# Show info link
push(@leftmenu, { 'type' => 'item',
		  'desc' => $text{'left_home'},
		  'link' => '/right.cgi',
		  'icon' => '/images/gohome.gif' });

# Show feedback link, but only if a custom email is set
%gaccess = &get_module_acl(undef, "");
if (&get_product_name() eq 'webmin' &&		# For Webmin
      !$ENV{'ANONYMOUS_USER'} &&
      int($gconfig{'nofeedbackcc'} || 0) != 2 &&
      $gaccess{'feedback'} &&
      $gconfig{'feedback_to'} ||
    &get_product_name() eq 'usermin' &&		# For Usermin
      !$ENV{'ANONYMOUS_USER'} &&
      $gconfig{'feedback'}
    ) {
	push(@leftmenu, { 'type' => 'item',
			  'desc' => $text{'left_feedback'},
			  'link' => '/feedback_form.cgi',
			  'icon' => '/images/mail-small.gif' });
	}

# Show refesh modules link, for master admin
if (&foreign_available("webmin")) {
	push(@leftmenu, { 'type' => 'item',
			  'desc' => $text{'main_refreshmods'},
			  'link' => '/webmin/refresh_modules.cgi',
			  'icon' => '/images/refresh-small.gif' });
	}

# Show logout link
my %miniserv;
&get_miniserv_config(\%miniserv);
if ($miniserv{'logout'} && !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	my $logout = { 'type' => 'item',
		       'icon' => '/images/stock_quit.gif',
		       'target' => 'window' };
	if ($main::session_id) {
		$logout->{'desc'} = $text{'main_logout'};
		$logout->{'link'} = '/session_login.cgi?logout=1';
		}
	else {
		$logout->{'desc'} = $text{'main_switch'};
		$logout->{'link'} = '/switch_user.cgi';
		}
	push(@leftmenu, $logout);
	}

# Show link back to original Webmin server
if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
	push(@leftmenu, { 'type' => 'item',
			  'desc' => $text{'header_servers'},
			  'link' => $ENV{'HTTP_WEBMIN_SERVERS'},
			  'icon' => '/images/webmin-small.gif',
			  'target' => 'window' });
	}

# Actually output the menu
print "<div class='wrapper'>\n";
print "<table id='main' width='100%'><tbody><tr><td>\n";
&show_menu_items_list(\@leftmenu, 0);
print "</td></tr></tbody></table>\n";
print "</div>\n";
&popup_footer();

# show_menu_items_list(&list, indent)
# Actually prints the HTML for menu items
sub show_menu_items_list
{
my ($items, $indent) = @_;
foreach my $item (@$items) {
	if ($item->{'type'} eq 'item') {
		# Link to some page
		my $t = !$item->{'target'} ? 'right' :
			$item->{'target'} eq 'new' ? '_blank' :
			$item->{'target'} eq 'window' ? '_top' : 'right';
		if ($item->{'icon'}) {
			my $icon = add_webprefix($item->{'icon'});
			print "<div class='linkwithicon'>".
			      "<img src='$icon' alt=''>\n";
			}
		my $cls = $item->{'icon'} ? 'aftericon' :
		          $indent ? 'linkindented' : 'leftlink';
		print "<div class='$cls'>";
		my $link = add_webprefix($item->{'link'});
		my $tags = $item->{'onclick'} ?
				"onClick='".$item->{'onclick'}."'" : "";
		print "<a href='$link' target=$t $tags>".
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
		print "<div class='linkwithicon'>";
		print "<a href=\"javascript:toggleview('cat$c','toggle$c')\" ".
		      "id='toggle$c'><img border='0' src='images/closed.gif' ".
		      "alt='[+]'></a>\n";
		print "<div class='aftericon'>".
		      "<a href=\"javascript:toggleview('cat$c','toggle$c')\" ".
		      "id='toggletext$c'>".
		      "<font color='#000000'>$item->{'desc'}</font></a></div>";
		print "</div>\n";
		print "<div class='itemhidden' id='cat$c'>\n";
		&show_menu_items_list($item->{'members'}, $indent+1);
		print "</div>\n";
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
	elsif ($item->{'type'} eq 'input') {
		# For with an input of some kind
		my $cgi = add_webprefix($item->{'cgi'});
		print "<form action='$cgi' target=right>\n";
		foreach my $h (@{$item->{'hidden'}}) {
			print ui_hidden(@$h);
			}
		print "<div class='leftlink'>";
		print $item->{'desc'},"\n";
		print ui_textbox($item->{'name'}, $item->{'value'},
				 $item->{'size'});
		if ($item->{'icon'}) {
			my $icon = add_webprefix($item->{'icon'});
			print "<input type=image src='$icon' ".
			      "border=0 class=goArrow>\n";
			}
		print "</div>";
		print "</form>\n";
		}
	}
}

# add_webprefix(link)
# If a URL starts with a / , add webprefix
sub add_webprefix
{
my ($link) = @_;
return $link =~ /^\// ? $gconfig{'webprefix'}.$link : $link;
}

