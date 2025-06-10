#!/usr/local/bin/perl
# Update, add or delete an inherited package directory

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});
if (!$in{'new'}) {
	# Find the directory
	($pkg) = grep { $_->{'dir'} eq $in{'old'} }
		      @{$zinfo->{'inherit-pkg-dir'}};
	$pkg || &error($text{'pkg_egone'});
	}
$pkg ||= { 'keytype' => 'inherit-pkg-dir' };

if ($in{'delete'}) {
	# Just remove this dir
	&delete_zone_object($zinfo, $pkg);
	}
else {
	# Validate inputs
	$form = &get_pkg_form(\%in, $zinfo, $pkg);
	$form->validate_redirect("edit_pkg.cgi");
	$pkg->{'dir'} = $form->get_value("dir");
	&find_clash($zinfo, $pkg) &&
		$form->validate_redirect("edit_pkg.cgi",
					 [ [ "dir", $text{'pkg_eclash'} ] ]);

	# Save the zone settings
	if ($in{'new'}) {
		&create_zone_object($zinfo, $pkg);
		}
	else {
		&modify_zone_object($zinfo, $pkg);
		}
	}

&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "pkg", $in{'old'} || $pkg->{'dir'}, $pkg);
&redirect("edit_zone.cgi?zone=$in{'zone'}");

