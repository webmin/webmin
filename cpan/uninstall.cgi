#!/usr/local/bin/perl
# uninstall.cgi
# Uninstall a perl module group, after asking for confirmation 

require './cpan-lib.pl';
&ReadParse();
@mods = &list_perl_modules();
$mod = $mods[$in{'idx'}];
&error_setup($text{'uninstall_err'});

if ($in{'confirm'}) {
	# Go ahead and do it
	$err = &remove_module($mod);
	&error($err) if ($err);
	&redirect("");
	}
else {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'uninstall_title'}, "");

	print "<form action=uninstall.cgi>\n";
	print "<input type=hidden name=idx value='$in{'idx'}'>\n";
	local ($m, @sm) = @{$mod->{'mods'}};
	if (@sm) {
		print &text('uninstall_rusure2', "<tt>$m</tt>",
			    join(" , ", map { "<tt>$_</tt>" } @sm)),"\n";
		}
	else {
		print &text('uninstall_rusure', "<tt>$m</tt>"),"\n";
		}
	print "<pre>";
	foreach $f (@{$mod->{'packlist'}}, $mod->{'packfile'}) {
		print &html_escape($f),"\n";
		}
	print "</pre>\n";
	if ($mod->{'pkg'}) {
		print &text('uninstall_'.$mod->{'pkgtype'},
			    "<tt>$mod->{'pkg'}</tt>"),"<p>\n";
		}
	print "<center><input type=submit name=confirm ",
	      "value='$text{'uninstall_ok'}'></center></form>\n";

	&ui_print_footer("edit_mod.cgi?idx=$in{'idx'}", $text{'edit_return'},
		"", $text{'index_return'});
	}

