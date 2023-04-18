# allocate_miniserv_websocket()
# Allocate a new websocket and
# stores it miniserv.conf file
sub allocate_miniserv_websocket
{
# Find ports already in use
&lock_file(&get_miniserv_config_file());
my %miniserv;
&get_miniserv_config(\%miniserv);
my %inuse;
foreach my $k (keys %miniserv) {
    if ($k =~ /^websockets_/ && $miniserv{$k} =~ /port=(\d+)/) {
        $inuse{$1} = 1;
        }
    }

# Pick a port and configure Webmin to proxy it
my $port = $config{'base_port'} || 555;
while(1) {
    if (!$inuse{$port}) {
        &open_socket("127.0.0.1", $port, my $fh, \$err);
        last if ($err);
        close($fh);
        }
    $port++;
    }
my $wspath = "/$module_name/ws-".$port;
my $now = time();
$miniserv{'websockets_'.$wspath} = "host=127.0.0.1 port=$port wspath=/ user=$remote_user time=$now";
&put_miniserv_config(\%miniserv);
&unlock_file(&get_miniserv_config_file());
&reload_miniserv();
return $port;
}

# remove_miniserv_websocket(port)
# Remove old websocket
# from miniserv.conf
sub remove_miniserv_websocket
{
my ($port) = @_;
my %miniserv;
if ($port) {
    &lock_file(&get_miniserv_config_file());
    &get_miniserv_config(\%miniserv);
    my $wspath = "/$module_name/ws-".$port;
    if ($miniserv{'websockets_'.$wspath}) {
        delete($miniserv{'websockets_'.$wspath});
        &put_miniserv_config(\%miniserv);
        &reload_miniserv();
        }
    &unlock_file(&get_miniserv_config_file());
    }
}

# cleanup_miniserv_websockets([&skip-ports])
# Called by scheduled status collection to remove any
# websockets in miniserv.conf that are no longer used
sub cleanup_miniserv_websockets
{
my ($skip) = @_;
$skip ||= [ ];
&lock_file(&get_miniserv_config_file());
my %miniserv;
&get_miniserv_config(\%miniserv);
my $now = time();
my @clean;
foreach my $k (keys %miniserv) {
    $k =~ /^websockets_\/$module_name\/ws-(\d+)$/ || next;
    my $port = $1;
    next if (&indexof($port, @$skip) >= 0);
    my $when = 0;
    if ($miniserv{$k} =~ /time=(\d+)/) {
        $when = $1;
        }
    if ($now - $when > 60) {
        # Has been open for a while, check if the port is still in use?
        my $err;
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

1;
