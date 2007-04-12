#!/usr/local/bin/perl

require "./inittab-lib.pl";
&ReadParse();
@inittab = &parse_inittab();
($init) = grep { $_->{'id'} eq $in{'oldid'} } @inittab
	if ($in{'oldid'} ne '');

&lock_file($config{ 'inittab_file' });
if ($in{ 'button' } eq $text{ 'edit_inittab_del' } ) {
	# Just delete the entry
	&delete_inittab($init);
	}
else {
	# Validate and store inputs
	&error($text{'save_inittab_noid'}) if(!$in{'id'});
	if ($in{'id'} ne $in{'oldid'}) {
		($clash) = grep { $_->{'id'} eq $in{'id'} } @inittab;
		&error($text{'save_inittab_already'}) if ($clash);
		}
	$init->{'id'} = $in{'id'};
	$init->{'comment'} = $in{'comment'};
	foreach $l ( 0..6, "a", "b", "c" ) {
		push(@levels, $l) if ($in{$l});
		}
	$init->{'levels'} = \@levels;
	$init->{'action'} = $in{'action'};
	$init->{'process'} = $in{'process'};

	if ($in{'oldid'} ne '') {
		# Update the entry
		&modify_inittab($init);
		}
	else {
		# Add a new entry
		&create_inittab($init);
		}
	}
&unlock_file($config{ 'inittab_file' });

if ( $in{ 'button' } eq $text{ 'edit_inittab_del' }) {
	&webmin_log("delete", "inittab", $in{ 'oldid' }, \%in);
	}
elsif ( $number == -1 ) {
	&webmin_log("create", "inittab", $in{ 'id' }, \%in);
	}
else {
	&webmin_log("modify", "inittab", $in{ 'id' }, \%in);
	}

&redirect("");

