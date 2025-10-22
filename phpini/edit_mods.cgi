#!/usr/local/bin/perl
# Show per-module include files with an option to disable

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
my $conf = &get_config($in{'file'});
my $inidir = &get_php_ini_dir($in{'file'});
$inidir || &error($text{'mods_edir'});
my $filever = &get_php_ini_version($in{'file'});
my $ver = $filever || &get_php_binary_version($in{'file'});
$access{'global'} || &error($text{'mods_ecannot'});

&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>",
		 $text{'mods_title'}, "");

print &text('mods_desc', $ver),"<p>\n";

# Find software packages if possible
my $n;
if (&foreign_installed("software")) {
	&foreign_require("software");
	$n = &software::list_packages();
	for(my $i=0; $i<$n; $i++) {
		my $n = $software::packages{$i,'name'};
		my $v = $software::packages{$i,'version'};
		$pkgmap{$n} = { 'name' => $n, 'version' => $v };
		}
	}

# Show modules with .ini files
@mods = &list_php_ini_modules($inidir);
print &ui_form_start("save_mods.cgi", "post");
print &ui_hidden("file", $in{'file'});
print &ui_columns_start([ $text{'mods_enabled'},
			  $text{'mods_name'},
			  $text{'mods_file'},
			  $n ? ( $text{'mods_pkg'} ): ( ) ]);
foreach my $m (@mods) {
	my $pkg;
	if ($n && $ver) {
		my @poss = &php_module_packages($m->{'mod'}, $ver, $filever);
		($pkg) = grep { $_ } map { $pkgmap{$_} } @poss;
		if (!$pkg) {
			# Package is referenced by another name
			foreach (@poss) {
				my @pinfo = &software::virtual_package_info($_);
				$pkg = { 'name' => $pinfo[0],
					 'version' => $pinfo[4] } if @pinfo;
				}
			}
		}
	my $pkg_version_simple = $pkg->{'version'};
	$pkg_version_simple =~ s/\+.*//;         # deb
	$pkg_version_simple =~ s/\.[a-zA-Z].*//; # rpm
	
	print &ui_columns_row([
		&ui_checkbox("mod", $m->{'mod'}, "", $m->{'enabled'}),
		$m->{'mod'},
		$m->{'path'},
		!$n ? ( ) :
		  !$pkg ? ( "" ) :
		  ( &ui_link("../software/edit_pack.cgi?package=".
			     &urlize($pkg->{'name'})."&version=".
			     &urlize($pkg->{'version'}),
			     "$pkg->{'name'}-$pkg_version_simple") ),
		]);
	}
print &ui_columns_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

# Show form to install a package
if (&foreign_installed("software") &&
    &foreign_available("software")) {
	print &ui_hr();
	print $text{'mods_idesc'},"<p>\n";
	print &ui_form_start("install_mod.cgi");
	print &ui_hidden("file", $in{'file'});
	print "$text{'mods_newpkg'}&nbsp; ",
	      &ui_textbox("mod", undef, 30),"\n";
	print &ui_form_end([ [ undef, $text{'mods_setup'} ] ]);
	}

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
