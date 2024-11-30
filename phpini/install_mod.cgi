#!/usr/local/bin/perl
# Install the package for a given PHP module, based on the version

require './phpini-lib.pl';
&foreign_require("software");
&ReadParse();
&error_setup($text{'imod_err'});
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$access{'global'} || &error($text{'mods_ecannot'});
$in{'mod'} =~ /^\S+$/ || &error($text{'imod_emod'});
my $ver = &get_php_ini_version($in{'file'});
$ver || &error(&text('mods_egetver', "<tt>".&html_escape($in{'file'})."</tt>"));

# Work out possible package names
@poss = &php_module_packages($in{'mod'}, $ver);
@poss || &error($text{'mods_eposs'});

# Try to install them
&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>",
		 $text{'imod_title'}, "");

print "<b>",&text('imod_doing', "<tt>".&html_escape($in{'mod'})."</tt>",
		  $ver),"</b><p>\n";

my $ok = 0;
foreach my $pkg (@poss) {
	print &text('imod_trying', "<tt>".&html_escape($pkg)."</tt>"),"<br>\n";
	my @pinfo = &software::package_info($pkg);
	if (@pinfo) {
		print $text{'imod_already'},"<p>\n";
		$ok = 1;
		last;
		}
	my ($out, $rs) = &capture_function_output(
		\&software::update_system_install, $pkg);
	my @pinfo = &software::package_info($pkg);
	if (@pinfo && @$rs) {
		print $text{'imod_done'},"<p>\n";
		$ok = 1;
		last;
		}
	print $text{'imod_failed'},"<p>\n";
	}
if (!$ok) {
	print "<b>$text{'imod_allfailed'}</b><p>\n";
	}

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
