#!/usr/local/bin/perl
# Show a gallery of the widgets of ui-lib.pl, together with the existing
# tabs, forms, buttons and tables they are meant to be combined with.
#
# The page chrome around the gallery follows modules like grub2 and the
# Virtualmin Podman module :
#
#  - ui_print_header(subtext, title, image, help, config, nomodule,
#    nowebmin, rightside) : the first argument is a subtitle shown under
#    the title, typically a version ("GRUB version 2.12", "Webmin 2.660").
#    It may hold several lines separated by <br>, the way the Virtualmin
#    Podman module shows the domain and the image pool under its title.
#
#  - The buttons at the top right of the title come from the other
#    arguments, and each appears only when its source exists :
#     help    - the name of a page in the module's help directory, here
#               help/intro.html, shown as a question mark that opens the
#               page in a popup; nothing is shown without it.
#     config  - set to 1 to show the cog linking to the module's
#               configuration page, which needs a config.info file in the
#               module listing the options, and a config file with their
#               defaults. The theme hides it when the user's ACL has
#               noconfig set. Here one option chooses the tab opened
#               first.
#     nomodule - set to 1 on the index page, where the "module index"
#               back arrow would only lead to itself; every other page of
#               a module leaves it 0 to get that arrow.
#     rightside - HTML placed at the right of the title, and where a
#               module puts its apply, restart or regenerate link. Lines
#               are separated by <br>. Modules about a system service,
#               such as BIND, also append help_search_link(term,
#               sections...) here, which returns a documentation search
#               link only when the man module is available to the user;
#               this demo has no such documentation and leaves it out.
#
#  - Authentic turns links in that rightside area into icon buttons when
#    their URL contains config.cgi, restart.cgi, restart_progressive.cgi,
#    generate.cgi, apply.cgi, apply_progressive.cgi, start.cgi, stop.cgi
#    or their _progressive variants (plus index.cgi for a back link). A
#    plain ui_link to apply.cgi is shown as a small refresh icon with the
#    link text as its tooltip. When the link text is wrapped in <b>, as
#    grub2 does while the menu needs regenerating, the same button is
#    shown large with its text, to call attention to the pending change.
#    The demo shows the pending state when opened with ?changed=1.
#
#  - The block of action buttons that modules put at the bottom of a
#    page after a ui_hr is shown at the end of the Buttons tab, built by
#    demo_page_actions in ui-demo-pages.pl.

use strict;
use warnings;

require './ui-demo-lib.pl'; ## no critic
our (%gconfig, %in, %text);

ReadParse();

# Apply link for the right of the title, emphasized while a change is
# pending, and returning to this page afterwards
my $apply = $text{'index_apply'};
$apply = ui_tag('b', $apply) if ($in{'changed'});
my $rightside = ui_link("apply.cgi?redir=".urlize("index.cgi"), $apply);

# Two-line subtitle : the version, then the theme in use
my $subtext = text('index_subtitle', get_webmin_version())."<br>".
	      text('index_subtitle_theme',
		   ui_tag('tt', html_escape($gconfig{'theme'} || 'gray-theme')));

ui_print_header($subtext, $text{'index_title'}, "", "intro", 1, 1, undef,
		$rightside);
print demo_gallery_page();
# The footer link becomes the "Return to ..." button under the page; an
# index page points back to the Webmin index (see edit_manual.cgi for a
# page with two return links)
ui_print_footer("/", $text{'index'});
