#!/usr/local/bin/perl
# Show a form for editing a package directory or adding one

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});

if (!$in{'new'}) {
	# Find the package dir object
	($pkg) = grep { $_->{'dir'} eq $in{'old'} }
		      @{$zinfo->{'inherit-pkg-dir'}};
	$pkg || &error($text{'pkg_egone'});
	}
$p = new WebminUI::Page(&zone_title($in{'zone'}),
		 $in{'new'} ? $text{'pkg_title1'} : $text{'pkg_title2'},
		 "pkg");
$p->add_form(&get_pkg_form(\%in, $zinfo, $pkg));
$p->add_footer("edit_zone.cgi?zone=$in{'zone'}", $text{'edit_return'});
$p->print();

