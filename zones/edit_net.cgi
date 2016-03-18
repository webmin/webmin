#!/usr/local/bin/perl
# Show a form for editing a network interface or adding one

require './zones-lib.pl';
do 'forms-lib.pl';
&ReadParse();
$zinfo = &get_zone($in{'zone'});
$zinfo || &error($text{'edit_egone'});

$p = new WebminUI::Page(&zone_title($in{'zone'}),
                 $in{'new'} ? $text{'net_title1'} : $text{'net_title2'},
                 "net");
if (!$in{'new'}) {
	# Find the network object
	($net) = grep { $_->{'address'} eq $in{'old'} } @{$zinfo->{'net'}};
	$net || &error($text{'net_egone'});
	}
$p->add_form(&get_net_form(\%in, $zinfo, $net));
$p->add_footer("edit_zone.cgi?zone=$in{'zone'}", $text{'edit_return'});
$p->print();

