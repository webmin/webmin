#!/usr/local/bin/perl
# Install the package for a given PHP module, based on the version

require './phpini-lib.pl';
&foreign_require("software");
&ReadParse();
&error_setup($text{'imod_err'});
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$access{'global'} || &error($text{'mods_ecannot'});
$in{'mod'} =~ /^\S+$/ || &error($text{'imod_emod'});
my $filever = &get_php_ini_version($in{'file'});
my $ver = $filever || &get_php_binary_version($in{'file'});
$ver || &error(&text('mods_egetver', "<tt>".&html_escape($in{'file'})."</tt>"));

# Work out possible package names
@poss = &php_module_packages($in{'mod'}, $ver, $filever);
@poss || &error($text{'mods_eposs'});

# Is it already installed?
$inidir = &get_php_ini_dir($in{'file'});
($got) = grep { $_->{'mod'} eq $in{'mod'} } &list_php_ini_modules($inidir);
if ($got) {
	my $already;
	foreach my $pkg (@poss) {
		my @pinfo = &software::package_info($pkg);
		@pinfo = &software::virtual_package_info($pkg) if (!@pinfo);
		$already++ if (@pinfo);
		}
	$already && &error(&text('imod_alreadygot',
				 "<tt>".&html_escape($in{'mod'})."</tt>"));
	}

# Try to install them
&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>",
		 $text{'imod_title'}, "");

print &text('imod_alldoing', "<tt>".&html_escape($in{'mod'})."</tt>",
	    $ver),"<p>\n";

my $ok = 0;
foreach my $pkg (@poss) {
	my @pinfo = &software::package_info($pkg);
	@pinfo = &software::virtual_package_info($pkg) if (!@pinfo);
	next if (@pinfo);
	my ($out, $rs) = &capture_function_output(
		\&software::update_system_install, $pkg);
	@pinfo = &software::package_info($pkg);
	@pinfo = &software::virtual_package_info($pkg) if (!@pinfo);
	if (@pinfo && @$rs) {
		($got) = grep { $_->{'mod'} eq $in{'mod'} }
			      &list_php_ini_modules($inidir);
		if ($got) {
			$ok = $pkg;
			last;
			}
		}
	}
if ($ok) {
	print &text('imod_alldone',
		"<tt>".&html_escape($ok)."</tt>"),"<p>\n";
	&graceful_apache_restart($in{'file'});
	&webmin_log("imod", undef, $in{'file'}, { 'mod' => $in{'mod'} });
	}
else {
	print &text('imod_allfailed',
		"<tt>".&html_escape(join(" ", @poss))."</tt>"),"<p>\n";
	}

&ui_print_footer("edit_mods.cgi?file=".&urlize($in{'file'}),
		 $text{'mods_return'});
