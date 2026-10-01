#!/usr/local/bin/perl
# Show the menu in the left frame of the frameset: the Virtualmin or Cloudmin
# menu, or the Webmin modules
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

# Globals
our %in;
our %text;

# The menu only shows links and changes nothing, so it loads without the
# referer check
our $trust_unknown_referers = 1;

# Load the theme and the functions that build the menu
require "gray-theme/gray-theme-lib.pl";
require "gray-theme/theme.pl";
ReadParse();
theme_menu_lib() || error(text('left_elib', html_escape($@)));

# The body class selects the left frame styles
our $gray_theme_body_class = 'left-frame';

# Print the frame page, titled with the product name, and the menu
my (undef, $prodname) = theme_menu_product(\%text);
popup_header($prodname);
print &ui_switch_theme_javascript();
print theme_menu_html({ 'in' => \%in });

# The loader starts on a click or a form submission aimed at the right
# frame and stops when the new page there reports, through the functions
# below, that it has loaded; a stuck loader stops on its own after 20
# seconds
print <<'EOF';
<script type='text/javascript'>
(function() {
var root = document.documentElement, timer;
function start() {
	root.classList.add('loading-right');
	clearTimeout(timer);
	timer = setTimeout(stop, 20000);
	}
function stop() {
	root.classList.remove('loading-right');
	clearTimeout(timer);
	}
window.rightLoading = start;
window.rightLoaded = stop;
// Links and forms aimed at the right frame start the loader
document.addEventListener('click', function(e) {
	var a = e.target.closest ? e.target.closest('a') : null;
	if (a && a.target == 'right' && !/^javascript:/.test(a.href)) start();
	});
document.addEventListener('submit', function(e) {
	if (e.target.target == 'right') start();
	});
})();
</script>
EOF
popup_footer();
