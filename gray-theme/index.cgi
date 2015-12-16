#!/usr/bin/perl

use strict;
use warnings;
require 'gray-theme/gray-theme-lib.pl';
&ReadParse();
our ($current_theme, %in);
our %text = &load_language($current_theme);

my $minfo;
if ($in{'mod'}) {
	$minfo = { &get_module_info($in{'mod'}) };
	}
else {
	$minfo = &get_goto_module();
	}
my $goto = $minfo ? $minfo->{'dir'}."/" :
	   $in{'page'} ? "" : "right.cgi";
if ($in{'page'}) {
	$goto .= "/".$in{'page'};
	}
my $cat = $minfo ? "?$minfo->{'category'}=1" : "";

# Show frameset
my $title = &get_html_framed_title();
my $cols = &get_product_name() eq 'usermin' ? 180 : 230;
&popup_header($title, undef, undef, 1);

print <<EOF;
<frameset cols="$cols,*" border=0>
	<frame name="left" src="left.cgi$cat" scrolling="auto">
	<frame name="right" src="$goto" noresize>
<noframes>
<body>
<p>This page uses frames, but your browser doesn't support them.</p>
</body>
</noframes>
</frameset>
EOF
&popup_footer(1);

