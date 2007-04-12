#!/usr/local/bin/perl
# index.cgi
# Display GRUB menu titles

require './grub-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("grub", "man", "doc"));

# Check that GRUB is installed
if (!-r $config{'menu_file'}) {
	print "<p>",&text('index_efile', "<tt>$config{'menu_file'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
if (!&has_command($config{'grub_path'})) {
	print "<p>",&text('index_epath', "<tt>$config{'grub_path'}</tt>",
			  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# List the boot options
$conf = &get_menu_config();
$def = &find_value("default", $conf);
foreach $t (&find("title", $conf)) {
	push(@icons, $t->{'chainloader'} ? "images/chain.gif"
					 : "images/kernel.gif");
	local $tt = &html_escape($t->{'value'});
	push(@titles, $def == $i ? "<b>$tt</b>" : $tt);
	push(@links, "edit_title.cgi?idx=$t->{'index'}");
	$i++;
	}
if (@links) {
	print "<a href='edit_title.cgi?new=1'>$text{'index_add'}</a><br>\n";
	&icons_table(\@links, \@titles, \@icons, 4);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print "<a href='edit_title.cgi?new=1'>$text{'index_add'}</a><p>\n";
print "<hr>\n";

print "<table width=100%>\n";
print "<form action=edit_global.cgi>\n";
print "<tr><td><input type=submit value=\"$text{'index_global'}\"></td>\n";
print "<td>$text{'index_globalmsg'}</td></tr></form>\n";

%flang = &load_language('fdisk');
$text{'select_part'} = $flang{'select_part'};
$text{'select_device'} = $flang{'select_device'};
$text{'select_fd'} = $flang{'select_fd'};
$r = $config{'install'};
$dev = &bios_to_linux($r);
&foreign_require("mount", "mount-lib.pl");
$dev = &mount::device_name($dev);
print "<form action=install.cgi>\n";
print "<input type=hidden name=dev value='$dev'>\n";
print "<tr><td><input type=submit value=\"$text{'index_install'}\"></td>\n";
print "<td>",&text('index_installmsg', $dev),"</td></tr></form>\n";

print "</table>\n";

&ui_print_footer("/", $text{'index'});

