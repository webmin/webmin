#!/usr/local/bin/perl
# Update, add or delete a generic attribute

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
$attr ||= { 'keytype' => 'attr' };

if ($in{'delete'}) {
	# Just remove this attribute
	&delete_zone_object($zinfo, $attr);
	}
else {
	# Validate inputs
	$form = &get_attr_form(\%in, $zinfo, $attr);
	$form->validate_redirect("edit_attr.cgi");
	$attr->{'name'} = $form->get_value("name");
	$attr->{'type'} = $form->get_value("type");
	$attr->{'value'} = $form->get_value("value");
	&find_clash($zinfo, $attr) &&
		$form->validate_redirect("edit_attr.cgi",
					[ [ "name", $text{'attr_eclash'} ] ]);

	# Save the attribute
	if ($in{'new'}) {
		&create_zone_object($zinfo, $attr);
		}
	else {
		&modify_zone_object($zinfo, $attr);
		}
	}

&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "attr", $in{'old'} || $attr->{'name'}, $attr);
&redirect("edit_zone.cgi?zone=$in{'zone'}");

