#!/usr/local/bin/perl
# Delete multiple leases

require './dhcpd-lib.pl';
&ReadParse();

%access = &get_module_acl();
&error_setup($text{'listl_err'});
if( !($access{'w_leases'} && $access{'r_leases'}) ) {
	&error("$text{'eacl_np'} $text{'eacl_pdl'}");
	}       
@d = split(/\0/, $in{'d'});
@d || &error($text{'listl_enone'});

# Find the leases to remove
&tokenize_file($config{'lease_file'}, \@tok);
$i = $j = 0;
while($i < @tok) {
	$lease = &parse_struct(\@tok, \$i, $j++, $config{'lease_file'});
	if (&indexof($lease->{'index'}, @d) >= 0) {
		push(@todelete, $lease);
		}
	}

# Delete them, in reverse order so that line numbers aren't messed up
&lock_all_files();
$lref = &read_file_lines($config{'lease_file'});
foreach $lease (reverse(@todelete)) {
	splice(@$lref, $lease->{'line'},
	       $lease->{'eline'} - $lease->{'line'} + 1);
	}
&flush_file_lines($config{'lease_file'});
&unlock_all_files();

&restart_dhcpd();
&webmin_log("delete", "lease", $lease->{'values'}->[0]);
&redirect("list_leases.cgi?all=$in{'all'}&network=$in{'network'}&netmask=$in{'netmask'}");

