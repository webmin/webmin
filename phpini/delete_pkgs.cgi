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

# Actually do the deletion
&ui_print_unbuffered_header(undef, $text{'dpkgs_title'}, "");

foreach my $pkg (@delpkgs) {
	print &text('dpkgs_doing', "<tt>$pkg->{'name'}</tt>",
				   $pkg->{'phpver'}),"<br>\n";
	$err = &delete_php_base_package($pkg);
	if ($err) {
		print &text('dpkgs_failed', $err),"<p>\n";
		}
	else {
		print $text{'dpkgs_done'},"<p>\n";
		}
	}

&ui_print_footer("list_pkgs.cgi", $text{'pkgs_return'});
