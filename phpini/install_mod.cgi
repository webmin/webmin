#!/usr/local/bin/perl
# Install the package for a given PHP module, based on the version

require './phpini-lib.pl';
&foreign_require("software");
&ReadParse();
&error_setup($text{'imod_err'});
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$access{'global'} || &error($text{'mods_ecannot'});
&trim($in{'mod'}) || &error($text{'imod_emod'});
my $filever = &get_php_ini_version($in{'file'});
my $ver = $filever || &get_php_binary_version($in{'file'});
$ver || &error(&text('mods_egetver', "<tt>".&html_escape($in{'file'})."</tt>"));

# Work out possible package names
my @mods = &unique(split /(?:\s*,\s*|\s+)/, ($in{'mod'}));
my %want = map { lc($_) => 1 } grep { length } @mods;
my @poss;
foreach my $mod (@mods) {
	push(@poss,
		{ mod => $mod,
		  packages => [&php_module_packages($mod, $ver, $filever)] });
	}
(grep { @{ $_->{packages} } } @poss) or &error($text{'mods_eposs'});

# Is it already installed?
$inidir = &get_php_ini_dir($in{'file'});
my @got = grep { $want{ lc($_->{'mod'}) } } &list_php_ini_modules($inidir);
my @already;
if (@got) {
	foreach my $g (@got) {
		my ($p) = grep { $_->{'mod'} eq $g->{'mod'} } @poss;
		next unless $p && @{$p->{'packages'}};
		foreach my $pkg (@{$p->{'packages'}}) {
			my @pinfo = &software::package_info($pkg);
			@pinfo = &software::virtual_package_info($pkg)
				if (!@pinfo);
			if (@pinfo) {
				# Update list of modules to install
				@mods = grep { lc($_) ne lc($g->{'mod'}) }
					@mods;
				push(@already, $g->{'mod'});
				}
			}		
		}
	}

# Print header
&ui_print_unbuffered_header(
	"<tt>".&html_escape($in{'file'})."</tt>",
	$text{'imod_title'}, "");
if (@already) {
	print &text('imod_skipwhy')."<br>\n";
	print &text('imod_skipwhich', "<tt>".
		&html_escape(join(", ", &unique(@already)))."</tt>",
			$ver)."<p></p>\n";
	}

# Try to install them
foreach my $mod (@mods) {
	print &text('imod_alldoing', "<tt>".&html_escape($mod)."</tt>",
		    $ver),"<br>\n";

	my $ok = 0;
	my ($p) = grep { $_->{'mod'} eq $mod } @poss;
	next unless $p && @{$p->{'packages'}};
	foreach my $pkg (@{$p->{'packages'}}) {
		my @pinfo = &software::package_info($pkg);
		@pinfo = &software::virtual_package_info($pkg) if (!@pinfo);
		next if (@pinfo);
		my ($out, $rs) = &capture_function_output(
			\&software::update_system_install, $pkg);
		@pinfo = &software::package_info($pkg);
		@pinfo = &software::virtual_package_info($pkg) if (!@pinfo);
		if (@pinfo && @$rs) {
			($got) = grep { $_->{'mod'} eq $mod }
				&list_php_ini_modules($inidir);
			if ($got) {
				$ok = $pkg;
				last;
				}
			}
		}
	if ($ok) {
		print &text('imod_alldone',
			"<tt>".&html_escape($ok)."</tt>")."<p></p>\n";
		&graceful_apache_restart($in{'file'});
		&webmin_log("imod", undef, $in{'file'}, { 'mod' => $mod });
		}
	else {
		print &text('imod_allfailed',
			"<tt>".&html_escape(
				join(" ", @{$p->{'packages'}}))."</tt>").
					"<p></p>\n";
		}
	}

&ui_print_footer("edit_mods.cgi?file=".&urlize($in{'file'}),
		 $text{'mods_return'});
