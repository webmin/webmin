# Common functions for the xterm module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();

# cleanup_old_websockets()
# Called by scheduled status collection to remove any websockets in
# miniserv.conf that are no longer used
sub cleanup_old_websockets
{
&lock_file(&get_miniserv_config_file());
my %miniserv;
&get_miniserv_config(\%miniserv);
my $now = time();
my @clean;
foreach my $k (keys %miniserv) {
	$k =~ /^websockets_\/$module_name\/ws-(\d+)$/ || next;
	my $port = $1;
	my $when = 0;
	if ($miniserv{$k} =~ /time=(\d+)/) {
		$when = $1;
		}
	if ($now - $when > 60) {
		# Has been open for a while, check if the port is still in use?
		&open_socket("127.0.0.1", $port, my $fh, \$err);
		if ($err) {
			# Closed now, can clean up
			push(@clean, $k);
			}
		else {
			# Still active
			close($fh);
			}
		}
	}
if (@clean) {
	foreach my $k (@clean) {
		delete($miniserv{$k});
		}
	&put_miniserv_config(\%miniserv);
	&reload_miniserv();
	}
&unlock_file(&get_miniserv_config_file());
}
