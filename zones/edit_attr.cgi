#!/usr/local/bin/perl
# Show a form for editing a generic attribute or adding one

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});
if (!$in{'new'}) {
	# Find the filesystem object
	($attr) = grep { $_->{'name'} eq $in{'old'} } @{$zinfo->{'attr'}};
	$attr || &error($text{'attr_egone'});
	}
$p = new WebminUI::Page(&zone_title($in{'zone'}),
                 $in{'new'} ? $text{'attr_title1'} : $text{'attr_title2'},
                 "attr");
$p->add_form(&get_attr_form(\%in, $zinfo, $attr));
$p->add_footer("edit_zone.cgi?zone=$in{'zone'}", $text{'edit_return'});
$p->print();

