#!/usr/local/bin/perl
# anon_index.cgi
# Display a menu for anonymous section options

require './proftpd-lib.pl';
&ReadParse();
($conf, $v) = &get_virtual_config($in{'virt'});
$anonstr = &find_directive_struct("Anonymous", $conf);
if (!$anonstr) {
	# Go to the anon options page
	&redirect("edit_aserv.cgi?virt=$in{'virt'}&init=1");
	exit;
	}
$anon = $anonstr->{'members'};

# Display header and config icons
$desc = $in{'virt'} eq '' ? $text{'anon_header2'} :
	      &text('anon_header1', $v->{'value'});
&ui_print_header($desc, $text{'anon_title'}, "", undef, undef, undef, undef, &restart_button());

print "<h3>$text{'anon_opts'}</h3>\n";
$anon_icon = { "icon" => "images/anon.gif",
	       "name" => $text{'anon_anon'},
	       "link" => "edit_aserv.cgi?virt=$in{'virt'}" };
&config_icons("anon", "edit_anon.cgi?virt=$in{'virt'}&", $anon_icon);

# Display per-directory/limit options
@dir = ( &find_directive_struct("Directory", $anon) ,
	 &find_directive_struct("Limit", $anon) );
if (@dir) {
	print &ui_hr();
	print "<h3>$text{'virt_header'}</h3>\n";
	foreach $d (@dir) {
		if ($d->{'name'} eq 'Limit') {
			push(@links, "limit_index.cgi?virt=$in{'virt'}&".
				     "anon=1&limit=".&indexof($d, @$anon));
			push(@titles, &text('virt_limit', $d->{'value'}));
			push(@icons, "images/limit.gif");
			}
		else {
			push(@links, "dir_index.cgi?virt=$in{'virt'}&".
				     "anon=1&idx=".&indexof($d, @$anon));
			push(@titles, &text('virt_dir', $d->{'value'}));
			push(@icons, "images/dir.gif");
			}
		}
	&icons_table(\@links, \@titles, \@icons, 3);
	}

print "<table width=100%><tr><td>\n";

print "<form action=create_dir.cgi>\n";
print "<input type=hidden name=virt value='$in{'virt'}'>\n";
print "<input type=hidden name=anon value=1>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'virt_adddir'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'virt_path'}</b></td>\n";
print "<td><input name=dir size=30>\n";
print "<input type=submit value=\"$text{'create'}\"></td> </tr>\n";
print "</table></td></tr></table></form>\n";

print "</td><td>\n";

print "<form action=create_limit.cgi>\n";
print "<input type=hidden name=virt value='$in{'virt'}'>\n";
print "<input type=hidden name=anon value=1>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'virt_addlimit'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td><b>$text{'virt_cmds'}</b></td>\n";
print "<td><input name=cmd size=20>\n";
print "<input type=submit value=\"$text{'create'}\"></td> </tr>\n";
print "</table></td></tr></table></form>\n";

print "</td></tr></table>\n";

&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
	"", $text{'index_return'});

