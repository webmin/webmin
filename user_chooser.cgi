#!/usr/local/bin/perl
# user_chooser.cgi
# This CGI generated the HTML for choosing a user or list of users.

$trust_unknown_referers = 1;
BEGIN { push(@INC, ".."); };
use WebminCore;

&init_config();
if (&get_product_name() eq 'usermin') {
	&switch_to_remote_user();
	}
&ReadParse(undef, undef, 2);
%access = &get_module_acl();

if ($in{'multi'}) {
	# selecting multiple users.
	if ($in{'frame'} == 0) {
		# base frame
		&PrintHeader();
		print "<script type='text/javascript'>\n";
		@ul = &split_quoted_string(/\s+/, &filter_javascript($in{'user'}));
		$len = @ul;
		print "sel = new Array($len);\n";
		print "selr = new Array($len);\n";
		for($i=0; $i<$len; $i++) {
			print "sel[$i] = \"".
			      &quote_javascript($ul[$i])."\";\n";

			# samba valid system user can start with @ + &
			$gn = $ul[$i];
			$gn =~ s/^(@|\+|&)+//g;
			@uinfo = getpwnam($gn);
			if (@uinfo) {
				print "selr[$i] = \"".
				      &quote_javascript($uinfo[6])."\";\n";
				}
			else {
				print "selr[$i] = \"???\";\n";
				}
			}
		print "</script>\n";
		print "<title>$text{'users_title1'}</title>\n";
		print "<frameset cols='50%,50%'>\n";
		print "<frame src=\"$gconfig{'webprefix'}/user_chooser.cgi?frame=1&multi=1\">\n";
		print "<frameset rows='*,50' frameborder=no>\n";
		print " <frame src=\"$gconfig{'webprefix'}/user_chooser.cgi?frame=2&multi=1\">\n";
		print " <frame src=\"$gconfig{'webprefix'}/user_chooser.cgi?frame=3&multi=1\" scrolling=no>\n";
		print "</frameset>\n";
		print "</frameset>\n";
		}
	elsif ($in{'frame'} == 1) {
		# list of all users to choose from
		&popup_header();
		print "<script type='text/javascript'>\n";
		print "function adduser(u, r)\n";
		print "{\n";
		print "top.sel[top.sel.length] = u\n";
		print "top.selr[top.selr.length] = r\n";
		print "top.frames[1].location = top.frames[1].location\n";
		print "return false;\n";
		print "}\n";
		print "</script>\n";
		print "<div id='filter_box' style='display:none;margin:0px;padding:0px;width:100%;clear:both;'>";
		print &ui_textbox("filter",$text{'ui_filterbox'}, 50, 0, undef,"style='width:100%;color:#aaa;' onkeyup=\"filter_match(this.value);\" onfocus=\"if (this.value == '".$text{'ui_filterbox'}."') {this.value = '';this.style.color='#000';}\" onblur=\"if (this.value == '') {this.value = '".$text{'ui_filterbox'}."';this.style.color='#aaa';}\"");
		print &ui_hr("style='width:100%;'")."</div>";
		print "<font size=+1>$text{'users_all'}</font>\n";
		print "<table width=100%>\n";
        	my $cnt = 0;
		foreach $u (&get_users_list()) {
			if ($in{'user'} eq $u->[0]) { print "<tr class='filter_match' $cb>\n"; }
			else { print "<tr class='filter_match'>\n"; }
			$u->[6] =~ s/'/&#39;/g;
			$u->[0] =~ s/\\/\\\\/g;
			print "<td width=20%><a href=\"\" onClick='return adduser(\"$u->[0]\", \"$u->[6]\")'>$u->[0]</a></td>\n";
			print "<td>",&html_escape($u->[6]),"</td> </tr>\n";
            		$cnt++;
			}
		print "</table>\n";
        	if ( $cnt >= 10 ) {
            		print "<script type='text/javascript' src='$gconfig{'webprefix'}/unauthenticated/filter_match.js?28112013'></script>";
            		print "<script type='text/javascript'>filter_match_box();</script>";
        	}
		&popup_footer();
		}
	elsif ($in{'frame'} == 2) {
		# show chosen users
		&popup_header();
		print "<font size=+1>$text{'users_sel'}</font>\n";
		print <<'EOF';
<table width=100%>
<script type='text/javascript'>
function sub(j)
{
sel2 = new Array(); selr2 = new Array();
for(k=0,l=0; k<top.sel.length; k++) {
	if (k != j) {
		sel2[l] = top.sel[k];
		selr2[l] = top.selr[k];
		l++;
		}
	}
top.sel = sel2; top.selr = selr2;
top.frames[1].location = top.frames[1].location;
return false;
}
function html_escape(s)
{
return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}
for(i=0; i<top.sel.length; i++) {
	document.write("<tr>\n");
	document.write("<td><a href=\"\" onClick='return sub("+i+")'>"+html_escape(top.sel[i])+"</a></td>\n");
	document.write("<td>"+html_escape(top.selr[i])+"</td>\n");
	}
</script>
</table>
EOF
		&popup_footer();
		}
	elsif ($in{'frame'} == 3) {
		# output OK and Cancel buttons
		&popup_header();
		print "<script type='text/javascript'>\n";
		print "function qjoin(l)\n";
		print "{\n";
		print "rv = \"\";\n";
		print "for(i=0; i<l.length; i++) {\n";
		print "    if (rv != '') rv += ' ';\n";
		print "    if (l[i].indexOf(' ') < 0) rv += l[i];\n";
		print "    else rv += '\"'+l[i]+'\"'\n";
		print "    }\n";
		print "return rv;\n";
		print "}\n";
		print "</script>\n";
		print "<form>\n";
		print "<input type=button value=\"$text{'users_ok'}\" ",
		      "onClick='top.opener.ifield.value = qjoin(top.sel); ",
		      "top.close()'>\n";
		print "<input type=button value=\"$text{'users_cancel'}\" ",
		      "onClick='top.close()'>\n";
		print "&nbsp;&nbsp;<input type=button value=\"$text{'users_clear'}\" onClick='top.sel = new Array(); top.selr = new Array(); top.frames[1].location = top.frames[1].location'>\n";
		print "</form>\n";
		&popup_footer();
		}
	}
else {
	# selecting just one user .. display a list of all users to choose from
	&popup_header($text{'users_title2'});
	print "<script type='text/javascript'>\n";
	print "function select(f)\n";
	print "{\n";
	print "top.opener.ifield.value = f;\n";
	print "top.close();\n";
	print "return false;\n";
	print "}\n";
	print "</script>\n";
    	print "<div id='filter_box' style='display:none;margin:0px;padding:0px;width:100%;clear:both;'>";
    	print &ui_textbox("filter",$text{'ui_filterbox'}, 50, 0, undef,"style='width:100%;color:#aaa;' onkeyup=\"filter_match(this.value);\" onfocus=\"if (this.value == '".$text{'ui_filterbox'}."') {this.value = '';this.style.color='#000'}\" onblur=\"if (this.value == '') {this.value = '".$text{'ui_filterbox'}."';this.style.color='#aaa';}\"");
    	print &ui_hr("style='width:100%;'")."</div>";
	print "<table width=100%>\n";
    	my $cnt  = 0;
	foreach $u (&get_users_list()) {
		if ($in{'user'} eq $u->[0]) { print "<tr class='filter_match' $cb>\n"; }
		else { print "<tr class='filter_match'>\n"; }
		print "<td width=20%><a href=\"\" onClick='return select(\"$u->[0]\")'>$u->[0]</a></td>\n";
		print "<td>$u->[6]</td> </tr>\n";
        	$cnt++;
		}
	print "</table>\n";
    	if ( $cnt >= 10 ) {
        	print "<script type='text/javascript' src='$gconfig{'webprefix'}/unauthenticated/filter_match.js?28112013'></script>";
        	print "<script type='text/javascript'>filter_match_box();</script>";
    	}
	&popup_footer();
	}

sub get_users_list
{
local(@uinfo, @users, %ucan, %found);
if ($access{'uedit_mode'} == 2 || $access{'uedit_mode'} == 3) {
	map { $ucan{$_}++ } split(/\s+/, $access{'uedit'});
	}
setpwent();
local %doneu;
while(@uinfo = getpwent()) {
	next if ($doneu{$uinfo[0]}++);
	if ($access{'uedit_mode'} == 5 && $access{'uedit'} !~ /^\d+$/) {
		# Get group for matching by group name
		@ginfo = getgrgid($uinfo[3]);
		}
	if ($access{'uedit_mode'} == 0 ||
	    $access{'uedit_mode'} == 2 && $ucan{$uinfo[0]} ||
	    $access{'uedit_mode'} == 3 && !$ucan{$uinfo[0]} ||
	    $access{'uedit_mode'} == 4 &&
		(!$access{'uedit'} || $uinfo[2] >= $access{'uedit'}) &&
		(!$access{'uedit2'} || $uinfo[2] <= $access{'uedit2'}) ||
	    $access{'uedit_mode'} == 5 &&
	     ($access{'uedit'} =~ /^\d+$/ && $uinfo[3] == $access{'uedit'} ||
	      $ginfo[0] eq $access{'uedit'})) {
		push(@users, [ @uinfo ]) if (!$found{$uinfo[0]}++);
		}
	}
endpwent() if ($gconfig{'os_type'} ne 'hpux');
return sort { $a->[0] cmp $b->[0] } @users;
}
