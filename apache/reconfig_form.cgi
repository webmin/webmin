#!/usr/local/bin/perl
# reconfig_form.cgi
# Displays a list of supported modules, and allows the user to pick which
# ones are installed in apache

require './apache-lib.pl';
&ReadParse();
$access{'global'}==1 || &error($text{'reconfig_ecannot'});
if ($in{'vol'}) {
	&ui_print_header(undef, $text{'reconfig_title'}, "");
	}
else {
	&ui_print_header(undef, $text{'reconfig_title'}, "", undef, 1, 1);
	}

# Is Apache installed OK?
($ver, $mods) = &httpd_info($httpd = &find_httpd());
if (!$ver) {
	print &text('reconfig_ever', "<tt>$httpd</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Work out which modules Apache has
%inst = map { $_, 1 } &configurable_modules();

# Build list of modules known to Webmin
push(@mods, "core");
opendir(DIR, ".");
foreach $f (readdir(DIR)) {
	if ($f =~ /^(mod_\S+|prefork|worker|perchild|mpm_\S+)\.pl$/) {
		push(@mods, $1);
		}
	}
closedir(DIR);
@mods = sort { $a cmp $b } @mods;

if (!$in{'vol'}) {
	print "$text{'reconfig_desc1'}<p>\n";
	print "$text{'reconfig_desc3'}<p>\n";
	}
else {
	print "$text{'reconfig_desc2'}<p>\n";;
	}
print &ui_form_start("reconfig.cgi", "post");
print &ui_hidden("size", $in{'size'});
print &ui_hidden("ver", $ver);

@grid = ( );
for($i=0; $i<@mods; $i++) {
	push(@grid, &ui_checkbox("mods", $mods[$i], $mods[$i],
				 $inst{$mods[$i]}));
	}
print &ui_grid_table(\@grid, 4, 100);
print &ui_form_end([ [ "", $text{'reconfig_ok'} ] ]);

if ($in{'vol'}) { &ui_print_footer("", $text{'index_return'}); }
else { &ui_print_footer("/", $text{'index'}); }

