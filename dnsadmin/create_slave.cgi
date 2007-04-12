#!/usr/local/bin/perl
# create_slave.cgi
# Create a new slave zone

require './dns-lib.pl';
&ReadParse();
$whatfailed = "Failed to create slave zone";
%access = &get_module_acl();
$access{'slave'} || &error("You are not allowed to create slave zones");

# validate inputs
if ($in{'rev'}) {
        $in{'zone'} =~ /^[\d\.]+$/ ||
                &error("'$in{'zone'}' is not a valid network");
        $in{'zone'} = &ip_to_arpa($in{'zone'});
        }
else {
        $in{'zone'} =~ /^[A-z0-9\-\.]+$/ ||
                &error("'$in{'zone'}' is not a valid domain name");
        }
$in{'zone'} =~ s/\.$//g;
@masters = split(/\s+/, $in{'masters'});
foreach $m (@masters) {
        &check_ipaddress($m) ||
                &error("'$m' is not a valid master server address");
        }
if (!@masters) {
        &error("You must enter at least one master server");
        }
$base = $access{'dir'} eq '/' ? &base_directory($conf) : $access{'dir'};
if ($in{'file_def'} == 0) {
        $in{'file'} =~ /^\S+$/ ||
                &error("'$in{'file'}' is not a valid filename");
        if ($in{'file'} !~ /^\//) {
                $file = $base."/".$in{'file'};
                }
        else { $file = $in{'file'}; }
	&allowed_zone_file(\%access, $file) ||
		&error("'$file' is not an allowable zone file");
	if (!-r $file) {
		&lock_file($file);
		open(ZONE, "> $file") ||
			&error("Failed to create '$file' : $?");
		close(ZONE);
		&unlock_file($file);
		}
        }
elsif ($in{'file_def'} == 2) {
	if ($in{'rev'}) {
		$file = $base."/".&arpa_to_ip($in{'zone'}).".rev";
		}
	else {
		$file = $base."/".$in{'zone'}.".hosts";
		}
	}


@vals = ($in{'zone'}, @masters);
if ($file) { push(@vals, $file); }
&lock_file($config{'named_boot_file'});
&create_zone({ 'name' => 'secondary', 'values' => \@vals });
&unlock_file($config{'named_boot_file'});
&webmin_log("create", "slave", $in{'zone'}, \%in);

# Add the new zone to the access list
if ($access{'zones'} ne '*') {
        $access{'zones'} .= " ".$in{'zone'};
        &save_module_acl(\%access);
        }
&redirect("");

