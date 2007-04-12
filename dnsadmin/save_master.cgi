#!/usr/local/bin/perl
# save_master.cgi
# Save changes to an SOA record

require './dns-lib.pl';
&ReadParse();
$whatfailed = "Failed to update zone";
%access = &get_module_acl();
&can_edit_zone(\%access, $in{'origin'}) ||
        &error("You are not allowed to edit this zone");

# check inputs
$in{'master'} =~ /^[A-z0-9\-\.]+$/ ||
        &error("'$in{'master'}' is not a valid master server");
$in{'email'} =~ /^\S+\@\S+$/ ||
        &error("'$in{'email'}' is not a valid email address");
$in{'refresh'} =~ /^\S+$/ ||
        &error("'$in{'refresh'}' is not a valid refresh time");
$in{'retry'} =~ /^\S+$/ ||
        &error("'$in{'retry'}' is not a valid transfer retry time");
$in{'expiry'} =~ /^\S+$/ ||
        &error("'$in{'expiry'}' is not a valid expiry time");
$in{'minimum'} =~ /^\S+$/ ||
        &error("'$in{'minimum'}' is not a valid default TTL");
$in{'email'} =~ s/\@/\./; $in{'email'} .= ".";

@recs = &read_zone_file($in{'file'}, $in{'origin'});
$old = $recs[$in{'num'}];
if ($config{'soa_style'} == 1 && $old->{'values'}->[2] =~ /^(\d{8})(\d\d)$/) {
	if ($1 eq &date_serial()) { $serial = sprintf "%d%2.2d", $1, $2+1; }
	else { $serial = &date_serial()."00"; }
	}
else {
	$serial = $old->{'values'}->[2]+1;
	}
$vals = "$in{'master'} $in{'email'} (\n".
        "\t\t\t$serial\n".
        "\t\t\t$in{'refresh'}\n".
        "\t\t\t$in{'retry'}\n".
        "\t\t\t$in{'expiry'}\n".
        "\t\t\t$in{'minimum'} )";
&lock_file($in{'file'});
&modify_record($in{'file'}, $old, $old->{'name'},
	      $old->{'ttl'}, $old->{'class'}, "SOA", $vals);
&unlock_file($in{'file'});
&webmin_log("soa", undef, $in{'origin'}, \%in);
&redirect("edit_master.cgi?index=$in{'index'}");

