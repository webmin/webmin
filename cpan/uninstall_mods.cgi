#!/usr/local/bin/perl
# Uninstall a bunch of perl module groups, after asking for confirmation 

require './cpan-lib.pl';
&ReadParse();
&error_setup($text{'uninstalls_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'uninstalls_enone'});

if ($in{'upgrade'}) {
	# Just redirect to the install page from CPAN
	&redirect("download.cgi?missingok=1&source=3&cpan=".
		  &urlize(join(" ", @d)));
	exit;
	}

# Get the modules
@allmods = &list_perl_modules();
foreach $d (@d) {
	($mod) = grep { $_->{'name'} eq $d } @allmods;
	if ($mod) {
		push(@mods, $mod);
		}
	}

if ($in{'confirm'}) {
	# Go ahead and do it
	foreach $mod (@mods) {
		$err = &remove_module($mod);
		&error(&text('uninstalls_emod', "<tt>$mod</tt>", $err))
			if ($err);
		}
	&redirect("");
	}
else {
	# Ask the user if he is sure
	&ui_print_header(undef, $text{'uninstalls_title'}, "");

	print &ui_form_start("uninstall_mods.cgi", "post");
	print "<center>\n";
	foreach $d (@d) {
		print &ui_hidden("d", $d),"\n";
		}
	$mcount = 0;
	$fcount = 0;
	foreach $mod (@mods) {
		$mcount += scalar(@{$mod->{'mods'}})-1;
		$fcount += scalar(@{$mod->{'packlist'}})+1;
		}
	print &text('uninstalls_rusure', scalar(@mods), $mcount, $fcount),
	      "<p>\n";
	print "<input type=submit name=confirm ",
	      "value='$text{'uninstall_ok'}'></center></form>\n";

	&ui_print_footer("", $text{'index_return'});
	}

