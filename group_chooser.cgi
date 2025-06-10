#!/usr/local/bin/perl
# group_chooser.cgi
# This CGI generated the HTML for choosing a group or list of groups.

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
if (&get_product_name() eq 'usermin') {
	&switch_to_remote_user();
	}
&ReadParse(undef, undef, 2);
%access = &get_module_acl();

# Build list of primary groups
setpwent();
while(@uinfo = getpwent()) {
	push(@{$members{$uinfo[3]}}, $uinfo[0]);
	}
endpwent() if ($gconfig{'os_type'} ne 'hpux');

if ($in{'multi'}) {
	# selecting multiple groups.
	if ($in{'frame'} == 0) {
		# base frame
		&PrintHeader();
		print "<script type='text/javascript'>\n";
		@ul = &split_quoted_string(&filter_javascript($in{'group'}));
		$len = @ul;
		print "sel = new Array($len);\n";
		print "selr = new Array($len);\n";
		for($i=0; $i<$len; $i++) {
			print "sel[$i] = \"".
			      &quote_javascript($ul[$i])."\";\n";

			# samba valid system group can start with @ + &
			$gn = $ul[$i];
			$gn =~ s/^(@|\+|&)+//g;
			@ginfo = getgrnam($gn);

			#@ginfo = getgrnam($ul[$i]);
			if (@ginfo) {
				@mems = &unique( split(/ /, $ginfo[3]),
						 @{$members{$ginfo[2]}} );
				if (@mems > 3) { @mems = (@mems[0..1], "..."); }
				print "selr[$i] = \"",
				  &quote_javascript(join(' ', @mems)),"\";\n";
				}
			else { print "selr[$i] = \"???\";\n"; }
			}
		print "</script>\n";
		print "<title>$text{'groups_title1'}</title>\n";
		print "<frameset cols='50%,50%'>\n";
		print "<frame src=\"@{[&get_webprefix()]}/group_chooser.cgi?frame=1&multi=1\">\n";
		print "<frameset rows='*,50' frameborder=no>\n";
		print " <frame src=\"@{[&get_webprefix()]}/group_chooser.cgi?frame=2&multi=1\">\n";
		print " <frame src=\"@{[&get_webprefix()]}/group_chooser.cgi?frame=3&multi=1\" scrolling=no>\n";
		print "</frameset>\n";
		print "</frameset>\n";
		}
	elsif ($in{'frame'} == 1) {
		# list of all groups to choose from
		&popup_header();
		print "<script type='text/javascript'>\n";
		print "function addgroup(u, r)\n";
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
		print "<font size=+1>$text{'groups_all'}</font>\n";
		print "<table width=100%>\n";
		my $cnt = 0;
		foreach $u (&get_groups_list()) {
			if ($in{'group'} eq $u->[0]) { print "<tr class='filter_match' $cb>\n"; }
			else { print "<tr class='filter_match'>\n"; }
			$u->[0] =~ s/\\/\\\\/g;
			print "<td width=20%><a href=\"\" onClick='return addgroup(\"@{[&quote_escape($u->[0], \"'\")]}\", \"@{[&quote_escape($u->[3], \"'\")]}\")'>@{[&html_escape($u->[0])]}</a></td>\n";
			print "<td>@{[&html_escape($u->[3])]}</td> </tr>\n";
			$cnt++;
			}
		print "</table>\n";
        	if ( $cnt >= 10 ) {
            		print "<script type='text/javascript' src='@{[&get_webprefix()]}/unauthenticated/filter_match.js?28112013'></script>";
            		print "<script type='text/javascript'>filter_match_box();</script>";
        	}
		&popup_footer();
		}
	elsif ($in{'frame'} == 2) {
		# show chosen groups
		&popup_header();
		print "<font size=+1>$text{'groups_sel'}</font>\n";
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
location = location;
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
		print "<input type=button value=\"$text{'groups_ok'}\" ",
		      " onClick='top.opener.ifield.value = qjoin(top.sel); ",
		      "top.close()'>\n";
		print "<input type=button value=\"$text{'groups_cancel'}\" ",
		      "onClick='top.close()'>\n";
		print "&nbsp;&nbsp;<input type=button value=\"$text{'groups_clear'}\" onClick='top.sel = new Array(); top.selr = new Array(); top.frames[1].location = top.frames[1].location'>\n";
		print "</form>\n";
		&popup_footer();
		}
	}
else {
	# selecting just one group .. display a list of all groups to
	# choose from
	&popup_header($text{'groups_title2'});
	print "<script type='text/javascript'>\n";
	print "function select(f)\n";
	print "{\n";
	print "top.opener.ifield.value = f;\n";
	print "top.close();\n";
	print "return false;\n";
	print "}\n";
	print "</script>\n";
	print "<div id='filter_box' style='display:none;margin:0px;padding:0px;width:100%;clear:both;'>";
	print &ui_textbox("filter",$text{'ui_filterbox'}, 50, 0, undef,"style='width:100%;color:#aaa;' onkeyup=\"filter_match(this.value);\" onfocus=\"if (this.value == '".$text{'ui_filterbox'}."') {this.value = '';this.style.color='#000';}\" onblur=\"if (this.value == '') {this.value = '".$text{'ui_filterbox'}."';this.style.color='#aaa';}\"");
	print &ui_hr("style='width:100%;'")."</div>";;
	print "<table width=100%>\n";
	my $cnt = 0;
	foreach $u (&get_groups_list()) {
		if ($in{'group'} eq $u->[0]) { print "<tr class='filter_match' $cb>\n"; }
		else { print "<tr class='filter_match'>\n"; }
		print "<td width=20%><a href=\"\" onClick='return select(\"@{[&quote_escape($u->[0], \"'\")]}\")'>@{[&html_escape($u->[0])]}</a></td>\n";
		print "<td>@{[&html_escape($u->[3])]}</td> </tr>\n";
		$cnt++;
		}
	print "</table>\n";
    	if ( $cnt >= 10 ) {
        	print "<script type='text/javascript' src='@{[&get_webprefix()]}/unauthenticated/filter_match.js?28112013'></script>";
        	print "<script type='text/javascript'>filter_match_box();</script>";
    	}
	&popup_footer();
	}

sub get_groups_list
{
local(@ginfo, @groups, %gcan, %found);
if ($access{'gedit_mode'} == 2 || $access{'gedit_mode'} == 3) {
	map { $gcan{$_}++ } split(/\s+/, $access{'gedit'});
	}
setgrent();
local %doneg;
while(@ginfo = getgrent()) {
	next if ($doneg{$ginfo[0]}++);
	@mems = &unique( split(/ /, $ginfo[3]), @{$members{$ginfo[2]}} );
	if (@mems > 3) { @mems = (@mems[0..1], "..."); }
	$ginfo[3] = join(' ', @mems);
	if ($access{'gedit_mode'} == 0 ||
	    $access{'gedit_mode'} == 2 && $gcan{$ginfo[0]} ||
	    $access{'gedit_mode'} == 3 && !$gcan{$ginfo[0]} ||
	    $access{'gedit_mode'} == 4 &&
		(!$access{'gedit'} || $ginfo[2] >= $access{'gedit'}) &&
		(!$access{'gedit2'} || $ginfo[2] <= $access{'gedit2'})) {
		push(@groups, [ @ginfo ]) if (!$found{$ginfo[0]}++);
		}
	}
endgrent() if ($gconfig{'os_type'} ne 'hpux');
return sort { $a->[0] cmp $b->[0] } @groups;
}
