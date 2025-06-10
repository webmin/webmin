#!/usr/local/bin/perl
# Remove some PHP versions

require './phpini-lib.pl';
&error_setup($text{'dpkgs_err'});
$access{'global'} || &error($text{'pkgs_ecannot'});
&foreign_available("software") || &error($text{'pkgs_ecannot2'});
&ReadParse();

my @d = split(/\0/, $in{'d'});
@d || &error($text{'dpkgs_enone'});
my $vmap = &get_virtualmin_php_map();

# Find all packages and check that they can be safely removed
my @pkgs = &list_php_base_packages();
my @delpkgs;
foreach my $name (@d) {
	($pkg) = grep { $_->{'name'} eq $name } @pkgs;
	$pkg || &error($text{'dpkgs_eexists'});
	if ($vmap) {
		$ulist = $vmap->{$pkg->{'shortver'}};
		if ($ulist && @$ulist) {
			&error(&text('dpkg_eusers', $pkg->{'phpver'},
						    scalar(@$ulist)));
			}
		}
	push(@delpkgs, $pkg);
	}

&ui_print_unbuffered_header(undef, $text{'dpkgs_title'}, "");

if (!$in{'confirm'}) {
	# Find the packages first
	print "<center>\n";
	print &ui_form_start("delete_pkgs.cgi");
	foreach my $d (@d) {
		print &ui_hidden("d", $d);
		}
	my @alldel;
	foreach my $pkg (@delpkgs) {
		push(@alldel, &list_all_php_version_packages($pkg));
		}
	print &text('dpkgs_rusure',
		join(" ", map { "<tt>$_</tt>" } @alldel)),"<p>\n";
	print &ui_form_end([ [ 'confirm', $text{'pkgs_delete'} ] ]);
	print "</center>\n";
	}
else {
	# Actually do the deletion
	foreach my $pkg (@delpkgs) {
		print &text('dpkgs_doing', "<tt>$pkg->{'name'}</tt>",
					   $pkg->{'phpver'}),"<br>\n";
		$err = &delete_php_base_package($pkg, \@pkgs);
		if ($err) {
			print &text('dpkgs_failed', $err),"<p>\n";
			}
		else {
			print $text{'dpkgs_done'},"<p>\n";
			}
		}
	&webmin_log("delete", "pkgs", scalar(@delpkgs));
	}

&ui_print_footer("list_pkgs.cgi", $text{'pkgs_return'});
