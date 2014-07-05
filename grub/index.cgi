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
@crlinks = ( &ui_link("edit_title.cgi?new=1",$text{'index_add'}) );
$conf = &get_menu_config();
$def = &find_value("default", $conf);
@t = &find("title", $conf);
$i = 0;
foreach $t (@t) {
	push(@icons, $t->{'chainloader'} ? "images/chain.gif"
					 : "images/kernel.gif");
	local $tt = &html_escape($t->{'value'});
	push(@titles, $def == $i ? "<b>$tt</b>" : $tt);
	push(@links, "edit_title.cgi?idx=$t->{'index'}");
	push(@befores, $i == 0 ? "&lt;&lt;&nbsp;|&nbsp;" :
		&ui_link("up.cgi?idx=$i", "&lt;&lt;")."&nbsp;|&nbsp;");
	push(@afters, $i == @t-1 ? "&nbsp;|&nbsp;&gt;&gt;" :
		"&nbsp;|&nbsp;".&ui_link("down.cgi?idx=$i",
					 "&gt;&gt;"));
	$i++;
	}
if (@links) {
	print &ui_links_row(\@crlinks);
	&icons_table(\@links, \@titles, \@icons, 4, undef, undef, undef,
		     \@befores, \@afters);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print &ui_links_row(\@crlinks);
print &ui_hr();

print &ui_buttons_start();

# Global options button
print &ui_buttons_row("edit_global.cgi", $text{'index_global'},
		      $text{'index_globalmsg'});

# Install button
%flang = &load_language('fdisk');
$text{'select_part'} = $flang{'select_part'};
$text{'select_device'} = $flang{'select_device'};
$text{'select_fd'} = $flang{'select_fd'};
$r = $config{'install'};
$dev = &bios_to_linux($r);
&foreign_require("mount", "mount-lib.pl");
$dev = &mount::device_name($dev);
print &ui_buttons_row("install.cgi", $text{'index_install'},
		      &text('index_installmsg', $dev),
		      &ui_hidden("dev", $dev));

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

