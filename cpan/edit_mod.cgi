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

print &ui_table_start($text{'edit_header'}, "width=100%", 4);

# Module name and version
@m = @{$mod->{'mods'}};
($desc, $ver) = &module_desc($mod, $midx);
print &ui_table_row($text{'edit_mod'}, "$m[$midx] $ver");

# Description
print &ui_table_row($text{'edit_desc'},
	$desc ? &html_escape($desc) : $text{'edit_none'}, 2);

# Install date
print &ui_table_row($text{'edit_date'}, $mod->{'date'});

# Main file
print &ui_table_row($text{'edit_file'}, $mod->{'files'}->[$midx]);

# Install method (RPM or whatever)
print &ui_table_row($text{'edit_method'},
    $mod->{'pkg'} ? &text('edit_'.$mod->{'pkgtype'}, "<tt>$mod->{'pkg'}</tt>")
		  : $text{'edit_manual'});

if ($midx == $mod->{'master'} && @m > 1) {
	# Sub-modules
	@links = ( );
	for($i=0; $i<@m; $i++) {
		push(@links, &ui_link("edit_mod.cgi?idx=$in{'idx'}&midx=$i&name=$in{'name'}","$m[$i]")) if ($i != $mod->{'master'});
		}
	print &ui_table_row($text{'edit_subs'}, &ui_links_row(\@links), 3);
	}

print &ui_table_end();

# Un-install form
print "<table> <tr>\n";
if ($midx == $mod->{'master'} && !$mod->{'noremove'}) {
	print &ui_form_start("uninstall.cgi");
	print &ui_hidden("idx", $in{'idx'});
	print "<td>",&ui_submit($text{'edit_uninstall'}),"</td>\n";
	print &ui_form_end();
	}

# Upgrade form
if ($midx == $mod->{'master'} && !$mod->{'noupgrade'}) {
	print &ui_form_start("download.cgi");
	print &ui_hidden("cpan", $mod->{'mods'}->[0]);
	print &ui_hidden("source", 3);
	print "<td>",&ui_submit($text{'edit_upgrade'}),"</td>\n";
	print &ui_form_end();
	}
print "</table>\n";

# Module documentation
open(DOC, "$perl_doc -t '$m[$midx]' 2>/dev/null |");
while(<DOC>) { $doc .= $_; }
close(DOC);
if ($doc =~ /\S/) {
	print &ui_table_start($text{'edit_header2'}, "width=100%", 2);
	print &ui_table_row(undef, "<pre>".&html_escape($doc)."</pre>", 2);
	print &ui_table_end();
	}

&ui_print_footer($midx != $mod->{'master'} ?
	 ( "edit_mod.cgi?idx=$in{'idx'}&midx=$mod->{'master'}&name=$in{'name'}",
	   $text{'edit_return'} ) : ( ),
	"", $text{'index_return'});

