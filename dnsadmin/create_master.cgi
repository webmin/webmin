#!/usr/local/bin/perl
# create_master.cgi
# Create a new master zone

require './dns-lib.pl';
&ReadParse();
$whatfailed = "Failed to create zone";
%access = &get_module_acl();
$access{'master'} || &error("You cannot create master zones");
&lock_file($config{'named_boot_file'});
$conf = &get_config();

# validate inputs
if ($in{'rev'}) {
	$in{'zone'} =~ /^[\d\.]+$/ ||
		&error("'$in{'zone'}' is not a valid network");
	$in{'zone'} = &ip_to_arpa($in{'zone'});
	}
else {
	$in{'zone'} =~ /^[A-Za-z0-9\-\.]+$/ ||
		&error("'$in{'zone'}' is not a valid domain name");
	$in{'zone'} !~ /^[0-9\.]+$/ ||
		&error("'$in{'zone'}' must be a domain, not a network");
	}
$in{'zone'} =~ s/\.$//g;
$in{'master'} =~ /^[A-Za-z0-9\-\.]+$/ ||
	&error("'$in{'master'}' is not a valid master server");
if ($in{'master'} !~ /\.$/) { $in{'master'} .= "."; }
$in{'email'} =~ /^\S+\@\S+$/ ||
	&error("'$in{'email'}' is not a valid email address");
$in{'email'} =~ s/\@/\./g;
if ($in{'email'} !~ /\.$/) { $in{'email'} .= "."; }
$in{'refresh'} =~ /^\S+$/ ||
        &error("'$in{'refresh'}' is not a valid refresh time");
$in{'retry'} =~ /^\S+$/ ||
        &error("'$in{'retry'}' is not a valid transfer retry time");
$in{'expiry'} =~ /^\S+$/ ||
        &error("'$in{'expiry'}' is not a valid expiry time");
$in{'minimum'} =~ /^\S+$/ ||
        &error("'$in{'minimum'}' is not a valid default TTL");
$base = $access{'dir'} eq '/' ? &base_directory($conf) : $access{'dir'};
if (!$in{'file_def'}) {
	$in{'file'} =~ /^\S+$/ ||
		&error("'$in{'file'}' is not a valid filename");
	if ($in{'file'} !~ /^\//) {
		$in{'file'} = $base."/".$in{'file'};
		}
	&allowed_zone_file(\%access, $in{'file'}) ||
		&error("'$in{'file'}' is not an allowable zone file");
	}
elsif ($in{'rev'}) {
	# create filename for reverse zone
	$in{'file'} = $base."/".&arpa_to_ip($in{'zone'}).".rev";
	}
else {
	# create filename for forward zone
	$in{'file'} = $base."/$in{'zone'}.hosts";
	}
&lock_file($in{'file'});
open(ZONE, ">$in{'file'}") || &error("Failed to create '$in{'file'}' : $?");
close(ZONE);

# create the SOA and NS records
if ($config{'soa_style'} == 1) {
	$serial = &date_serial()."00";
	}
else {
	$serial = time();
	}
$vals = "$in{'master'} $in{'email'} (\n".
        "\t\t\t$serial\n".
        "\t\t\t$in{'refresh'}\n".
        "\t\t\t$in{'retry'}\n".
        "\t\t\t$in{'expiry'}\n".
        "\t\t\t$in{'minimum'} )";
&create_record($in{'file'}, "$in{'zone'}.", undef, "IN", "SOA", $vals);
&create_record($in{'file'}, "$in{'zone'}.", undef, "IN", "NS", $in{'master'});
&unlock_file($in{'file'});

# create the zone directive
&create_zone({ 'name' => 'primary', 'values' => [ $in{'zone'}, $in{'file'} ]});
&unlock_file($config{'named_boot_file'});
&webmin_log("create", "master", $in{'zone'}, \%in);

# Add the new zone to the access list
if ($access{'zones'} ne '*') {
        $access{'zones'} .= " ".$in{'zone'};
        &save_module_acl(\%access);
        }
&redirect("");

