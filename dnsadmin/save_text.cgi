#!/usr/local/bin/perl
# save_text.cgi
# Save a manually edit zone file

require './dns-lib.pl';
&ReadParseMime();
%access = &get_module_acl();
$zconf = &get_config()->[$in{'index'}];
&can_edit_zone(\%access, $zconf->{'values'}->[0]) ||
	&error("You are not allowed to edit this zone");
$file = &absolute_path($zconf->{'values'}->[1]);

$in{'text'} =~ s/\r//g;
&lock_file($file);
open(FILE, ">$file");
print FILE $in{'text'};
close(FILE);
&unlock_file($file);
&webmin_log("text", undef, $zconf->{'values'}->[0], { 'file' => $file } );
&redirect("edit_master.cgi?index=$in{'index'}");

