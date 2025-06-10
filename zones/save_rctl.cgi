#!/usr/local/bin/perl
# Update, add or delete a resource control

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
else {
	$rctl = { 'keytype' => 'rctl' };
	}

if ($in{'delete'}) {
	# Just remove this resource control
	&delete_zone_object($zinfo, $rctl);
	}
else {
	# Validate inputs
	$form = &get_rctl_form(\%in, $zinfo, $rctl);
	$table = $form->get_section(1);
	$form->validate_redirect("edit_rctl.cgi");
	$rctl->{'name'} = $form->get_value("name");
	@values = ( );
	for($i=0; $i<$table->get_rowcount(); $i++) {
		local ($priv, $limit, $action) = $table->get_values($i);
		if ($priv) {
			push(@values,
			     "(priv=$priv,limit=$limit,action=$action)");
			}
		}
	@values || &error($text{'rctl_evalues'});
	$rctl->{'value'} = join("\0", @values);
	&find_clash($zinfo, $rctl) &&
		$form->validate_redirect("edit_fs.cgi",
			[ [ "name", $text{'rctl_eclash'} ] ]);

	# Save the rctl
	if ($in{'new'}) {
		&create_zone_object($zinfo, $rctl);
		}
	else {
		&modify_zone_object($zinfo, $rctl);
		}
	}

&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "rctl", $in{'old'} || $rctl->{'name'}, $rctl);
&redirect("edit_zone.cgi?zone=$in{'zone'}");

