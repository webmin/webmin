#!/usr/bin/perl
# Show the left-side menu of Virtualmin domains, plus modules

do './web-lib.pl';
do './ui-lib.pl';
&init_config();
&ReadParse();
%text = &load_language($current_theme);

# Work out what categories we have
@modules = &get_visible_module_infos();
%cats = &list_categories(\@modules);
if (defined($cats{''})) {
	$cats{'others'} = $cats{''};
	delete($cats{''});
	}
@cats = sort { ($b eq "others" ? "" : $b) cmp ($a eq "others" ? "" : $a) } keys %cats;

$charset = defined($force_charset) ? $force_charset : &get_charset();
&PrintHeader($charset);
print <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<link rel="stylesheet" type="text/css" href="unauthenticated/style.css" />
<link rel="stylesheet" type="text/css" href="left.css" />
<script>
function toggleview (id1,id2) {
		var obj1 = document.getElementById(id1);
		var obj2 = document.getElementById(id2);
		(obj1.className=="itemshown") ? obj1.className="itemhidden" : obj1.className="itemshown"; 
		(obj1.className=="itemshown") ? obj2.innerHTML="<img border='0' src='images/open.gif' alt='[&ndash;]'>" : obj2.innerHTML="<img border='0' src='images/closed.gif' alt='[+]'>"; 
	}
</script>
</head>
<body>
<div class='menubody'>
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
		&print_category_opener($c, $in{$c} ? 1 : 0, $cats{$c});
		$cls = $in{$c} ? "itemshown" : "itemhidden";
		print "<div class='$cls' id='$c'>";
		$creal = $c eq "others" ? "" : $c;
		@inmodules = grep { $_->{'category'} eq $creal } @modules;
		foreach $minfo (@inmodules) {
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
print "<div class='leftlink'><hr></div>\n";

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

print <<EOF;
</div>
</body>
EOF

# print_category_opener(name, &allcats, label)
# Prints out an open/close twistie for some category
sub print_category_opener
{
local ($c, $status, $label) = @_;
$label = $c eq "others" ? "Others" : $label;
local $img = $status ? "open.gif" : "closed.gif";

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

