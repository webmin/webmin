#!/usr/local/bin/perl
# Show a form for editing a resource control or adding one

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});
if (!$in{'new'}) {
	# Find the rctl object
	($rctl) = grep { $_->{'name'} eq $in{'old'} } @{$zinfo->{'rctl'}};
	$rctl || &error($text{'rctl_egone'});
	}
$p = new WebminUI::Page(&zone_title($in{'zone'}),
		 $in{'new'} ? $text{'rctl_title1'} : $text{'rctl_title2'},
		 "rctl");
$p->add_form(&get_rctl_form(\%in, $zinfo, $rctl));
$p->add_footer("edit_zone.cgi?zone=$in{'zone'}", $text{'edit_return'});
$p->print();

