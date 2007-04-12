#!/usr/local/bin/perl
# save_slave.cgi
# Save changes to slave zone options in named.boot

require './dns-lib.pl';
&ReadParse();
&lock_file($config{'named_boot_file'});
$zconf = &get_config()->[$in{'index'}];
$whatfailed = "Failed to save slave zone";
%access = &get_module_acl();
&can_edit_zone(\%access, $zconf->{'values'}->[0]) ||
        &error("You are not allowed to edit this zone");

@mast = split(/\s+/, $in{'masters'});
foreach $m (@mast) {
	&check_ipaddress($m) ||
		&error("'$m' is not a valid master server IP address");
	}
if (!@mast) { &error("You must enter at least one master server address"); }
$in{'file_def'} || $in{'file'} =~ /^\S+$/ ||
	&error("'$in{'file'}' is not a valid records filename");

push(@vals, $zconf->{'values'}->[0]);
push(@vals, @mast);
if (!$in{'file_def'}) {
	$file = $in{'file'};
	$file = &base_directory($conf)."/".$file if ($file !~ /^\//);
	&allowed_zone_file(\%access, $file) ||
		&error("'$in{'file'}' is not an allowable records file");
	push(@vals, $in{'file'});
	}
&modify_zone($zconf, { 'name' => 'secondary', 'values' => \@vals });
&unlock_file($config{'named_boot_file'});
&webmin_log("opts", undef, $zconf->{'values'}->[0], \%in);
&redirect("");

