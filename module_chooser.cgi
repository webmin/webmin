#!/usr/local/bin/perl
# This CGI generates the HTML for choosing a module or list of modules

BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
&ReadParse(undef, undef, 2);
%access = &get_module_acl();

if ($in{'multi'}) {
	# selecting multiple modules
	if ($in{'frame'} == 0) {
		# base frame
		&PrintHeader();
		print "<script>\n";
		@ul = split(/\s+/, $in{'module'});
		$len = @ul;
		print "sel = new Array($len);\n";
		print "selr = new Array($len);\n";
		for($i=0; $i<$len; $i++) {
			%minfo = &get_module_info($ul[$i]);
			if (%minfo) {
				print "sel[$i] = \"$ul[$i]\";\n";
				print "selr[$i] = \"$minfo{'desc'}\";\n";
				}
			}
		print "</script>\n";
		print "<title>$text{'modules_title1'}</title>\n";
		print "<frameset cols='50%,50%'>\n";
		print "<frame src=\"@{[&get_webprefix()]}/module_chooser.cgi?frame=1&multi=1\">\n";
		print "<frameset rows='*,50' frameborder=no>\n";
		print " <frame src=\"@{[&get_webprefix()]}/module_chooser.cgi?frame=2&multi=1\">\n";
		print " <frame src=\"@{[&get_webprefix()]}/module_chooser.cgi?frame=3&multi=1\" scrolling=no>\n";
		print "</frameset>\n";
		print "</frameset>\n";
		}
	elsif ($in{'frame'} == 1) {
		# list of all modules to choose from
		&popup_header();
		print "<script>\n";
		print "function addmodule(u, r)\n";
		print "{\n";
		print "top.sel[top.sel.length] = u\n";
		print "top.selr[top.selr.length] = r\n";
		print "top.frames[1].location = top.frames[1].location\n";
		print "return false;\n";
		print "}\n";
		print "</script>\n";
		print "<font size=+1>$text{'modules_all'}</font>\n";
		print "<table width=100%>\n";
		foreach $m (&get_all_module_infos()) {
			if ($in{'module'} eq $m->{'dir'}) { print "<tr $cb>\n"; }
			else { print "<tr>\n"; }
			print "<td width=20%><a href=\"\" onClick='return addmodule(\"$m->{'dir'}\", \"$m->{'desc'}\")'>$m->{'dir'}</a></td>\n";
			print "<td>$m->{'desc'}</td> </tr>\n";
			}
		print "</table>\n";
		&popup_footer();
		}
	elsif ($in{'frame'} == 2) {
		# show chosen modules
		&popup_header();
		print "<font size=+1>$text{'modules_sel'}</font>\n";
		print <<'EOF';
<table width=100%>
<script>
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
for(i=0; i<top.sel.length; i++) {
	document.write("<tr>\n");
	document.write("<td><a href=\"\" onClick='return sub("+i+")'>"+top.sel[i]+"</a></td>\n");
	document.write("<td>"+top.selr[i]+"</td>\n");
	}
</script>
</table>
EOF
		&popup_footer();
		}
	elsif ($in{'frame'} == 3) {
		# output OK and Cancel buttons
		&popup_header();
		print "<script>\n";
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
		print "<input type=button value=\"$text{'modules_ok'}\" ",
		      "onClick='top.opener.ifield.value = qjoin(top.sel); ",
		      "top.close()'>\n";
		print "<input type=button value=\"$text{'modules_cancel'}\" ",
		      "onClick='top.close()'>\n";
		print "&nbsp;&nbsp;<input type=button value=\"$text{'modules_clear'}\" onClick='top.sel = new Array(); top.selr = new Array(); top.frames[1].location = top.frames[1].location'>\n";
		print "</form>\n";
		&popup_footer();
		}
	}
else {
	# selecting just one module .. display a list of all modules to
	# choose from
	&popup_header($text{'modules_title2'});
	print "<script>\n";
	print "function select(f)\n";
	print "{\n";
	print "top.opener.ifield.value = f;\n";
	print "top.close();\n";
	print "return false;\n";
	print "}\n";
	print "</script>\n";
	print "<table width=100%>\n";
	foreach $m (&get_all_module_infos()) {
		if ($in{'user'} eq $m->{'dir'}) { print "<tr $cb>\n"; }
		else { print "<tr>\n"; }
		print "<td width=20%><a href=\"\" onClick='return select(\"$m->{'dir'}\")'>$m->{'dir'}</a></td>\n";
		print "<td>$m->{'dir'}</td> </tr>\n";
		}
	print "</table>\n";
	&popup_footer();
	}
