#!/usr/local/bin/perl
# delete_lease.cgi
# Delete one lease from the leases file

require './dhcpd-lib.pl';
&ReadParse();

%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if( !($access{'w_leases'} && $access{'r_leases'}) ) {
	&error("$text{'eacl_np'} $text{'eacl_pdl'}");
	}       

&tokenize_file($config{'lease_file'}, \@tok);
$i = $j = 0;
while($i < @tok) {
	$lease = &parse_struct(\@tok, \$i, $j++, $config{'lease_file'});
	if ($lease->{'index'} == $in{'idx'}) {
		# found the one to delete!
		&lock_file($config{'lease_file'});
		$lref = &read_file_lines($config{'lease_file'});
		splice(@$lref, $lease->{'line'},
		       $lease->{'eline'} - $lease->{'line'} + 1);
		&flush_file_lines();
		&unlock_file($config{'lease_file'});
		&restart_dhcpd();
		&webmin_log("delete", "lease", $lease->{'values'}->[0]);
		last;
		}
	}
&redirect("list_leases.cgi?all=$in{'all'}&network=$in{'network'}&netmask=$in{'netmask'}");

