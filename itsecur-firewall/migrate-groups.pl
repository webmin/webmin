$nat_file="/etc/webmin/itsecur-firewall/nat";
$groups_file="/etc/webmin/itsecur-firewall/groups";

local ($iface, @nets, @maps);

open(NAT, $nat_file) || return ( );
open(GROUPS, ">>$groups_file");

chop($iface = <NAT>);
while(<NAT>) {
	s/\r|\n//g;
	if (/^(\S+)$/) {
		}
	elsif (/^(\S+)\t+(\S+)\t+(\S+)$/) {
		print GROUPS "$2\t$2\n";
		}
	elsif (/^(\S+)\t+(\S+)$/) {
		print GROUPS "$2\t$2\n";
		}
	}
close(NAT);
close(GROUPS);

