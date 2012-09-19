#!/usr/bin/perl
# Show the left-side menu of Webmin modules

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&ReadParse();
%text = &load_language($current_theme);
%gaccess = &get_module_acl(undef, "");

# Work out what modules and categories we have
@cats = &get_visible_modules_categories();
@modules = map { @{$_->{'modules'}} } @cats;

&popup_header();
print <<EOF;
<link rel="stylesheet" type="text/css" href="left.css" />
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
print &text('left_login', $remote_user),"<br>\n";

if ($gconfig{"notabs_${base_remote_user}"} == 2 ||
    $gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'} ||
    @modules <= 1) {
	# Show all modules in one list
	foreach $minfo (@modules) {
		$target = $minfo->{'noframe'} ? "_top" : "right";
		print "<a target=$target href=$minfo->{'dir'}/>$minfo->{'desc'}</a><br>\n";
		}
	}
else {
	# Show all modules under categories
	foreach $c (@cats) {
		# Show category opener, plus modules under it
		&print_category_opener(
			$c->{'code'},
			$in{$c->{'code'}} ? 1 : 0,
			$c->{'unused'} ?
				"<font color=#888888>$c->{'desc'}</font>" :
				$c->{'desc'});
		$cls = $in{$c->{'code'}} ? "itemshown" : "itemhidden";
		print "<div class='$cls' id='$c->{'code'}'>";
		foreach my $minfo (@{$c->{'modules'}}) {
			&print_category_link("$minfo->{'dir'}/",
					     $minfo->{'desc'},
					     undef,
					     undef,
					     $minfo->{'noframe'} ? "_top" : "",
					);
			}
		print "</div>\n";
		}
	}

# Show module/help search form
if (-r "$root_directory/webmin_search.cgi" &&
    $gaccess{'webminsearch'}) {
	print "<form action=webmin_search.cgi target=right>\n";
	print $text{'left_search'},"&nbsp;";
	print &ui_textbox("search", undef, 15);
	}

print "<div class='leftlink'><hr></div>\n";

# Show current module's log search, if logging
if ($gconfig{'log'} && &foreign_available("webminlog")) {
	print "<div class='linkwithicon'><img src=images/logs.gif>\n";
	print "<div class='aftericon'><a target=right href='webminlog/' onClick='show_logs(); return false;'>$text{'left_logs'}</a></div></div>\n";
	}

# Show info link
print "<div class='linkwithicon'><img src=images/gohome.gif>\n";
print "<div class='aftericon'><a target=right href='right.cgi?open=system&open=status'>$text{'left_home'}</a></div></div>\n";

# Show feedback link, but only if a custom email is set
%gaccess = &get_module_acl(undef, "");
if (&get_product_name() eq 'webmin' &&		# For Webmin
      !$ENV{'ANONYMOUS_USER'} &&
      $gconfig{'nofeedbackcc'} != 2 &&
      $gaccess{'feedback'} &&
      $gconfig{'feedback_to'} ||
    &get_product_name() eq 'usermin' &&		# For Usermin
      !$ENV{'ANONYMOUS_USER'} &&
      $gconfig{'feedback'}
    ) {
	print "<div class='linkwithicon'><img src=images/mail-small.gif>\n";
	print "<div class='aftericon'><a target=right href='feedback_form.cgi'>$text{'left_feedback'}</a></div></div>\n";
	}

# Show refesh modules link, for master admin
if (&foreign_available("webmin")) {
	print "<div class='linkwithicon'><img src=images/refresh-small.gif>\n";
	print "<div class='aftericon'><a target=right href='webmin/refresh_modules.cgi'>$text{'main_refreshmods'}</a></div></div>\n";
	}

# Show logout link
&get_miniserv_config(\%miniserv);
if ($miniserv{'logout'} && !$ENV{'SSL_USER'} && !$ENV{'LOCAL_USER'} &&
    $ENV{'HTTP_USER_AGENT'} !~ /webmin/i) {
	print "<div class='linkwithicon'><img src=images/stock_quit.gif>\n";
	if ($main::session_id) {
		print "<div class='aftericon'><a target=_top href='session_login.cgi?logout=1'>$text{'main_logout'}</a></div>";
		}
	else {
		print "<div class='aftericon'><a target=_top href='switch_user.cgi'>$text{'main_switch'}</a></div>";
		}
	print "</div>\n";
	}

# Show link back to original Webmin server
if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
	print "<div class='linkwithicon'><img src=images/webmin-small.gif>\n";
	print "<div class='aftericon'><a target=_top href='$ENV{'HTTP_WEBMIN_SERVERS'}'>$text{'header_servers'}</a></div>";
	}

&popup_footer();

# print_category_opener(name, &allcats, label)
# Prints out an open/close twistie for some category
sub print_category_opener
{
local ($c, $status, $label) = @_;
$label = $c eq "others" ? $text{'left_others'} : $label;
local $img = $status ? "gray-open.gif" : "gray-closed.gif";

# Show link to close or open catgory
print "<div class='linkwithicon'>";
print "<a href=\"javascript:toggleview('$c','toggle$c')\" id='toggle$c'><img border='0' src='images/$img' alt='[+]'></a>\n";
print "<div class='aftericon'><a href=\"javascript:toggleview('$c','toggle$c')\" id='toggle$c'><font color=#000000>$label</font></a></div></div>\n";
}


sub print_category_link
{
local ($link, $label, $image, $noimage, $target) = @_;
$target ||= "right";
print "<div class='linkindented'><a target=$target href=$link>$label</a></div>\n";
}

