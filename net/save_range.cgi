#!/usr/local/bin/perl
# save_range.cgi
# Create, save or delete a boot-time address range

require './net-lib.pl';
$access{'ifcs'} == 2 || $access{'ifcs'} == 3 || &error($text{'ifcs_ecannot'});
&ReadParse();
@boot = &boot_interfaces();

sub check_restricted_interfaces() {
       if ($access{'ifcs'} == 3) {
               map { $can_interfaces{$_}++ } split(/\s+/, $access{'interfaces'});
               if (! $can_interfaces{$b->{'name'}}) {
                       &error($text{'ifcs_ecannot_this'});
               }
       }
}

if ($in{'delete'} || $in{'unapply'}) {
	# Delete interface
	&error_setup($text{'range_err1'});
	$b = $boot[$in{'idx'}];
	&check_restricted_interfaces();

	if ($in{'unapply'}) {
		# Shut down this range
		&error_setup($text{'range_err4'});
		$err = &unapply_interface($act);
		$err && &error("<pre>$err</pre>");
		}
	&delete_interface($b);
	&webmin_log("delete", "range", $b->{'fullname'}, $b);
	}
else {
	# Save or create interface
	&error_setup($text{'range_err2'});
	if (!$in{'new'}) {
		$b = $boot[$in{'idx'}];
		}
	else {
		$b = { };
		}
	&parse_range($b, \%in);
	&check_restricted_interfaces();
	&save_interface($b);

	if ($in{'activate'}) {
		# Make this interface active (if possible)
		&error_setup($text{'range_err3'});
		$err = &apply_interface($b);
		$err && &error("<pre>$err</pre>");
		}
	&webmin_log($in{'new'} ? 'create' : 'modify',
		    "range", $b->{'fullname'}, $b);
	}
&redirect("list_ifcs.cgi?mode=boot");

