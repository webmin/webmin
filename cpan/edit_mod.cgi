#!/usr/local/bin/perl
# edit_mod.cgi
# Display the details and documentation of a perl module

require './cpan-lib.pl';
&ReadParse();
if ($in{'name'}) {
	@mods = &list_perl_modules($in{'name'});
	$mod = $mods[0];
	}
else {
	@mods = &list_perl_modules($in{'name'});
	$mod = $mods[$in{'idx'}];
	}
$midx = $in{'midx'} ? $in{'midx'} : 0;

&ui_print_header(undef, $text{'edit_title'}, "");

print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

@m = @{$mod->{'mods'}};
($desc, $ver) = &module_desc($mod, $midx);
print "<tr> <td><b>$text{'edit_mod'}</b></td>\n";
print "<td>$m[$midx] $ver</td>\n";

print "<td><b>$text{'edit_desc'}</b></td>\n";
print "<td>",$desc ? &html_escape($desc) : $text{'edit_none'},"</td> </tr>\n";

print "<tr> <td><b>$text{'edit_date'}</b></td>\n";
print "<td nowrap>$mod->{'date'}</td>\n";

print "<td><b>$text{'edit_file'}</b></td>\n";
print "<td>$mod->{'files'}->[$midx]</td> </tr>\n";

print "<tr> <td><b>$text{'edit_method'}</b></td>\n";
print "<td>",$mod->{'pkg'} ?
		&text('edit_'.$mod->{'pkgtype'}, "<tt>$mod->{'pkg'}</tt>") :
		$text{'edit_manual'},"</td>\n";
print "</tr>\n";

if ($midx == $mod->{'master'} && @m > 1) {
	print "<tr> <td valign=top><b>$text{'edit_subs'}</b></td>\n";
	print "<td colspan=3>";
	for($i=0; $i<@m; $i++) {
		print "<a href='edit_mod.cgi?idx=$in{'idx'}&midx=$i&name=$in{'name'}'>$m[$i]</a>&nbsp;&nbsp;\n" if ($i != $mod->{'master'});
		}
	print "</td> </tr>\n";
	}

print "</table></td></tr></table>\n";

print "<table width=100%> <tr>\n";
if ($midx == $mod->{'master'} && !$mod->{'noremove'}) {
	print "<form action=uninstall.cgi><td>\n";
	print "<input type=hidden name=idx value='$in{'idx'}'>\n";
	print "<input type=submit value='$text{'edit_uninstall'}'>\n";
	print "</td></form>\n";
	}

if ($midx == $mod->{'master'} && !$mod->{'noupgrade'}) {
	print "<form action=download.cgi><td align=right>\n";
	print "<input type=hidden name=cpan value='$mod->{'mods'}->[0]'>\n";
	print "<input type=hidden name=source value=3>\n";
	print "<input type=submit value='$text{'edit_upgrade'}'>\n";
	print "</td></form>\n";
	}
print "</table>\n";
print "<br>\n";

open(DOC, "$perl_doc -t '$m[$midx]' 2>/dev/null |");
while(<DOC>) { $doc .= $_; }
close(DOC);
if ($doc =~ /\S/) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'edit_header2'}</b></td> </tr>\n";
	print "<tr $cb> <td><pre>";
	print &html_escape($doc);
	print "</pre></td></tr></table><br>\n";
	}

&ui_print_footer($midx != $mod->{'master'} ?
	 ( "edit_mod.cgi?idx=$in{'idx'}&midx=$mod->{'master'}&name=$in{'name'}",
	   $text{'edit_return'} ) : ( ),
	"", $text{'index_return'});

