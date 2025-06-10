#!/usr/local/bin/perl
# interface_chooser.cgi
#
# Based on user_chooser.cgi by Jamie Cameron
# (c) Tomas Pospisek <tpo_deb@sourcepole.ch>
# Licensed under the webmin license
#
# made possible by: 
# 	Sourcepole          http://sourcepole.ch
# under contract from:
# 	AO Media Services   http://www.ao-asif.ch/aoi/media/
# Thanks!
# 
# TODO:
# replace active_interfaces by a merged list from active_* and boot_interfaces
# 
# This CGI generated the HTML for choosing an interface or a list of interfaces.

require './net-lib.pl';
&init_config();
&ReadParse();
%access = &get_module_acl();

if ($in{'multi'}) {
	# selecting multiple interfaces.
	if ($in{'frame'} == 0) {
		# base frame
		&PrintHeader();
		print "<script>\n";
		@il = split(/\s+/, $in{'interface'});
		$len = @il;
		print "sel = new Array($len);\n";
		for($i=0; $i<$len; $i++) {
			print "sel[$i] = \"$il[$i]\";\n";
			}
		print "</script>\n";
		print "<title>$text{'interfaces_title1'}</title>\n";
		print "<frameset cols='50%,50%'>\n";
		print "<frame src=\"/net/interface_chooser.cgi?frame=1&multi=1\">\n";
		print "<frameset rows='*,50' frameborder=no>\n";
		print " <frame src=\"/net/interface_chooser.cgi?frame=2&multi=1\">\n";
		print " <frame src=\"/net/interface_chooser.cgi?frame=3&multi=1\" scrolling=no>\n";
		print "</frameset>\n";
		print "</frameset>\n";
		}
	elsif ($in{'frame'} == 1) {
		# list of all interfaces to choose from
		&ui_print_header(undef, );
		print "<script>\n";
		print "function addinterface(i)\n";
		print "{\n";
		print "top.sel[top.sel.length] = i\n";
		print "top.frames[1].location = top.frames[1].location\n";
		print "return false;\n";
		print "}\n";
		print "</script>\n";
		print "<font size=+1>$text{'interfaces_all'}</font>\n";
		print "<table width=100%>\n";
		foreach $if (&active_interfaces()) {
			if ($in{'interface'} eq $if->{'fullname'}) { print "<tr $cb>\n"; }
			else { print "<tr>\n"; }
			print "<td width=20%><a href=\"\" onClick='return addinterface(\"$if->{'fullname'}\")'>$if->{'fullname'}</a></td>\n";
			}
		print "</table>\n";
		}
	elsif ($in{'frame'} == 2) {
		# show chosen interfaces
		&ui_print_header(undef, );
		print "<font size=+1>$text{'interfaces_sel'}</font>\n";
		print <<'EOF';
<table width=100%>
<script>
function sub(j)
{
  sel2 = new Array();
  for(k=0,l=0; k<top.sel.length; k++) {
	if (k != j) {
		sel2[l] = top.sel[k];
		l++;
		}
	}
  top.sel = sel2;
  top.frames[1].location = top.frames[1].location;
  return false;
}
for(i=0; i<top.sel.length; i++) {
	document.write("<tr>\n");
	document.write("<td><a href=\"\" onClick='return sub("+i+")'>"+top.sel[i]+"</a></td>\n");
	}
</script>
</table>
EOF
		}
	elsif ($in{'frame'} == 3) {
		# output OK and Cancel buttons
		&ui_print_header(undef, );
		print "<form>\n";
		print "<input type=button value=\"$text{'interfaces_ok'}\" ",
		      "onClick='top.ifield.value = top.sel.join(\" \"); ",
		      "top.close()'>\n";
		print "<input type=button value=\"$text{'interfaces_cancel'}\" ",
		      "onClick='top.close()'>\n";
		print "&nbsp;&nbsp;<input type=button value=\"$text{'interfaces_clear'}\" onClick='top.sel = new Array(); top.selr = new Array(); top.frames[1].location = top.frames[1].location'>\n";
		print "</form>\n";
		}
	}
else {
	# selecting just one interface .. display a list of all interfaces to choose from
	&ui_print_header(undef, );
	print "<script>\n";
	print "function select(f)\n";
	print "{\n";
	print "ifield.value = f;\n";
	print "top.close();\n";
	print "return false;\n";
	print "}\n";
	print "</script>\n";
	print "<title>$text{'interfaces_title2'}</title>\n";
	print "<table width=100%>\n";
	foreach $if (&active_interfaces()) {
		if ($in{'interface'} eq $if->{'fullname'}) { print "<tr $cb>\n"; }
		else { print "<tr>\n"; }
		print "<td width=20%><a href=\"\" onClick='return select(\"$if->{'fullname'}\")'>$if->{'fullname'}</a></td></tr>\n";
		}
	print "</table>\n";
	}

