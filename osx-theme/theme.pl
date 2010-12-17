# theme.pl
# Override functions for the OSX theme
# XXX always starts with 'other' category?

# header(title, image, [help], [config], [nomodule], [nowebmin], [rightside],
#	 [header], [body], [below])
sub theme_header
{
print "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='en' lang='en'>\n";
print "<head>\n";
print $_[7];
print "<title>$_[0]</title>\n";
print "<link rel='stylesheet' href='/unauthenticated/style.css' type='text/css'>\n";
if ($charset) {
	print "<meta http-equiv=\"Content-Type\" ",
	      "content=\"text/html; Charset=$charset\">\n";
	}
print "</head>\n";
print "<body $_[8]>\n";

# Get all modules visible to this user
@osx_modules = &get_available_module_infos()
	if (!length(@osx_modules));

# Show table of categories
local $one = @osx_modules == 1 && $gconfig{'gotoone'};
local $notabs = $gconfig{"notabs_${base_remote_user}"} == 2 ||
	$gconfig{"notabs_${base_remote_user}"} == 0 && $gconfig{'notabs'};
if (@_ > 1 && !$one && $remote_user && !$notabs) {
	local $logout;
	if (!$ENV{'ANONYMOUS_USER'} && !$ENV{'SSL_USER'} &&
	    !$ENV{'LOCAL_USER'} && !$ENV{'HTTP_WEBMIN_SERVERS'}) {
		if ($main::session_id) {
			$logout = "<a href='/session_login.cgi?logout=1'>$text{'main_logout'}</a>";
			}
		else {
			$logout = "<a href='/switch_user.cgi'>$text{'main_switch'}</a>";
			}
		}
	&start_osx_table("Module Categories", $logout);
	local %catnames;
	&read_file("$config_directory/webmin.catnames", \%catnames);
	foreach $m (@osx_modules) {
		local $c = $m->{'category'};
		next if ($cats{$c});
		if (defined($catnames{$c})) {
		    $cats{$c} = $catnames{$c};
		    }
		elsif ($text{"category_$c"}) {
		    $cats{$c} = $text{"category_$c"};
		    }
		else {
		    # try to get category name from module ..
		    local %mtext = &load_language($m->{'dir'});
		    if ($mtext{"category_$c"}) {
			$cats{$c} = $mtext{"category_$c"};
			}
		    else {
			$c = $m->{'category'} = "";
			$cats{$c} = $text{"category_$c"};
			}
		    }
		}
	@cats = sort { $b cmp $a } keys %cats;
	$cats = @cats;
	$per = $cats ? 100.0 / $cats : 100;

	# Actually show category icons
	# XXX spacing?
	local (@icons, @titles, @links);
	foreach $c (@cats) {
		local $t = $cats{$c};
		push(@titles, $t);
		push(@icons, -r "$root_directory/$current_theme/cats/$c.gif" ?
			"/$current_theme/cats/$c.gif" :
			"/$current_theme/cats/unknown.gif");
		push(@links, "/?cat=$c");
		}
	&icons_table(\@links, \@titles, \@icons,
		     @links > 7 ? scalar(@links) : 7);

	&end_osx_table();
	}

if (@_ > 1) {
	# Open table for main page
	local @right;
	if ($ENV{'HTTP_WEBMIN_SERVERS'}) {
		push(@right, "<a href='$ENV{'HTTP_WEBMIN_SERVERS'}'>".
			     "$text{'header_servers'}</a>");
		}
	if (!$_[4]) {
		# Module index link
		local $idx = $module_info{'index_link'};
		local $mi = $module_index_link || "/$module_name/$idx";
		push(@right, "<a href=\"$gconfig{'webprefix'}$mi\">".
			     "$text{'header_module'}</a>");
		}
	if (ref($_[2]) eq "ARRAY" && !$ENV{'ANONYMOUS_USER'}) {
		# Help link
		push(@right, &hlink($text{'header_help'},
				    $_[2]->[0], $_[2]->[1]));
		}
	elsif (defined($_[2]) && !$ENV{'ANONYMOUS_USER'}) {
		# Help link
		push(@right, &hlink($text{'header_help'}, $_[2]));
		}
	if ($_[3]) {
		local %access = &get_module_acl();
		if (!$access{'noconfig'} && !$config{'noprefs'}) {
			local $cprog = $user_module_config_directory ?
					"uconfig.cgi" : "config.cgi";
			push(@right, "<a href=\"$gconfig{'webprefix'}/$cprog?$module_name\">$text{'header_config'}</a>");
			}
		}
	push(@right, split(/<br>/, $_[6]));
	&start_osx_table($_[0], join("&nbsp;|&nbsp;", @right));
	if ($_[9]) {
		print "<table width=100%><tr><td align=center>",
		      "$_[9]</td></tr></table>\n";
		}
	$started_osx_table++;
	}
}

sub theme_footer
{
if ($started_osx_table) {
	# Close table for main page
	&end_osx_table();
	}

# Show footer links

print "</body>\n";
print "</html>\n";
}

# start_osx_table(title, rightstuff, width)
sub start_osx_table
{
local ($title, $right, $width) = @_;
$width ||= 100;
print <<EOF;
<table align="center" width="$width%" cellspacing="0" cellpadding="0" class="maintablea">
 <tr>
  <td>
   <table width="100%" cellspacing="0" cellpadding="0" class="tableh1a">
    <tr>
     <td class="tableh1a"><img src="/unauthenticated/left.gif"></td>
     <td class="tableh1a" background="/unauthenticated/middle.gif" width="100%"><font class="optionx" color="#ffffff">&#160;&#160;$title</font></td>
     <td class="tableh1a" background="/unauthenticated/middle.gif" align=right nowrap><font class="optionx" color="#ffffff">$right</font></td>
     <td class="tableh1a"><img src="/unauthenticated/right.gif"></td>
    </tr>
   </table>
  </td>
 </tr>
</table>

<table align="center" width="$width%" cellspacing="0" cellpadding="0">
 <tr>
  <td background="/unauthenticated/c1b.gif" valign="top"><img name="main_table_r1_c1" src="/unauthenticated/c1.gif" border="0" id="main_table_r1_c1" alt="" /></td>
   <td width="100%"><table width="100%" cellspacing="0" cellpadding="5" class="maintableb" border="1" bordercolor="7F7F7F">
    <tr valign="top">
     <td>
EOF
}

sub end_osx_table
{
print <<EOF;
     </td>
    </tr>
   </table>
  </td>
  <td background="/unauthenticated/c3b.gif" valign="top"><img name="main_table_r1_c3" src="/unauthenticated/c3.gif" border="0" id="main_table_r1_c3" alt="" /></td>
 </tr>
 <tr>
  <td><img name="main_table_r2_c1" src="/unauthenticated/2c1.gif" width="10" height="4" border="0" id="main_table_r2_c1" alt="" /></td>
  <td background="/unauthenticated/c2b.gif"><img name="main_table_r2_c2" src="/unauthenticated/c2.gif" border="0" id="main_table_r2_c2" alt="" /></td>
  <td><img name="main_table_r2_c3" src="/unauthenticated/c3.gif" width="10" height="4" border="0" id="main_table_r2_c3" alt="" /></td>
 </tr>
</table>
EOF
}

sub theme_ui_post_header
{
local ($text) = @_;
local $rv;
if (defined($text)) {
        $rv .= "<center><font size=+1>$text</font></center><br>\n";
        }
return $rv;
}

sub theme_ui_pre_footer
{
return "";
}

# Hack to prevent the display of <hr> lines
#package miniserv;
#sub PRINT
#{
#if ($_[1] !~ /^<hr>(<p>|<br>)?\s*$/) {
#	$r = shift;
#	$$r++;
#	&write_to_sock(@_);
#	}
#}



