#!/usr/local/bin/perl
# Show a form for editing a filesystem or adding one

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});
if (!$in{'new'}) {
	# Find the filesystem object
	($fs) = grep { $_->{'dir'} eq $in{'old'} } @{$zinfo->{'fs'}};
	$fs || &error($text{'fs_egone'});
	}
$p = new WebminUI::Page(&zone_title($in{'zone'}),
		 $in{'new'} ? $text{'fs_title1'} : $text{'fs_title2'}, "fs");
$type = $in{'type'} || $fs->{'type'};
$p->add_form(&get_fs_form(\%in, $zinfo, $fs, $type));
$p->add_footer("edit_zone.cgi?zone=$in{'zone'}", $text{'edit_return'});
$p->print();


