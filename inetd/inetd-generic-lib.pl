
# list_services()
# Returns a list of services from the services file, each being an array of
#  line name port protocol aliases index
sub list_services
{
local(@rv, $l);
$l = 0;
system("$config{'get_services_command'}") if ($config{'get_services_command'});
open(SERVICES, $config{services_file});
while(<SERVICES>) {
	chop; s/#.*$//g;
	if (/^(\S+)\s+([0-9]+)\/(\S+)\s*(.*)$/) {
		push(@rv, [ $l, $1, $2, $3, $4, scalar(@rv) ]);
		if ($config{'ipv6'}) {
			push(@rv, [ $l, $1, $2, $3.'6', $4, scalar(@rv) ]);
			}
		}
	$l++;
	}
close(SERVICES);
return @rv;
}

# create_service(name, port, proto, aliases)
# Add a new service to the list
sub create_service
{
local $p = $_[2];
if ($config{'ipv6'} && $p =~ /^(\S+)6$/) {
	# don't add the service if it is already there
	foreach $s (&list_services()) {
		return if ($s->[1] eq $_[0] && $s->[2] == $_[1] &&
			$s->[3] eq $1);
		}
	$p =~ s/6$//;
	}
&open_tempfile(SERVICES, ">> $config{services_file}");
&print_tempfile(SERVICES, "$_[0]\t$_[1]/$p",$_[3] ? "\t$_[3]\n" : "\n");
&close_tempfile(SERVICES);
system("$config{'put_services_command'}") if ($config{'put_services_command'});
}


# modify_service(line, name, port, proto, aliases)
# Change an existing service
sub modify_service
{
local(@serv);
open(SERVICES, $config{services_file});
@serv = <SERVICES>;
close(SERVICES);
$serv[$_[0]] = "$_[1]\t$_[2]/$_[3]".($_[4] ? "\t$_[4]\n" : "\n");
&open_tempfile(SERVICES, "> $config{services_file}");
&print_tempfile(SERVICES, @serv);
&close_tempfile(SERVICES);
system("$config{'put_services_command'}") if ($config{'put_services_command'});
}

# delete_service(line)
sub delete_service
{
local(@serv);
open(SERVICES, $config{services_file});
@serv = <SERVICES>;
close(SERVICES);
splice(@serv, $_[0], 1);
&open_tempfile(SERVICES, "> $config{services_file}");
&print_tempfile(SERVICES, @serv);
&close_tempfile(SERVICES);
system("$config{'put_services_command'}") if ($config{'put_services_command'});
}

# list_protocols()
# Returns a list of supported protocols on this system
sub list_protocols
{
local(@rv);
open(PROT, $config{protocols_file});
while(<PROT>) {
	chop; s/#.*$//g;
	if (!/\S/) { next; }
	/^(\S+)\s+/;
	push(@rv, $1);
	if ($config{'ipv6'}) {
		if ($1 eq 'tcp') { push(@rv, 'tcp6'); }
	elsif ($1 eq 'udp') { push(@rv, 'udp6'); }
		}
	}
close(PROT);
return &unique(@rv);
}

# list_inets()
# Returns a list of service details handled by inetd. RPC services
# will have a name like foo/1 or bar/1-3, where the thing after the / is
# the version or versions supported. For each service, the list contains
#  line active? rpc? name type protocol wait user path|internal args file
sub list_inets
{
# build list of inetd files
local (@files, @rv, $l);
@files = ( $config{'inetd_conf_file'} );
opendir(DIR, $config{'inetd_dir'});
foreach $f (readdir(DIR)) {
	next if ($f =~ /^\./);
	push(@files, "$config{'inetd_dir'}/$f");
	}
closedir(DIR);

# parse each file
foreach $f (@files) {
	$l = 0;
	open(INET, $f);
	while(<INET>) {
		chop;
		if (/^(#+|#<off>#)?\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\??\/\S+|internal)\s*(.*)$/) {
			push(@rv, [ $l, !$1, 0, $2, $3, $4,
				    $5, $6, $7, $8, $f ]);
			$rv[$#rv]->[2] = ($2 =~ /\//);
			}
		$l++;
		}
	close(INET);
	}
return @rv;
}

# create_inet(enabled, name, type, protocol, wait, user, program, args)
# Add a new service to the main inetd config file
sub create_inet
{
&open_tempfile(INET, ">> $config{inetd_conf_file}");
&print_tempfile(INET,
	 ($_[0] ? "" : "#")."$_[1]\t$_[2]\t$_[3]\t$_[4]\t$_[5]\t$_[6]".
	 ($_[7] ? "\t$_[7]\n" : "\n"));
&close_tempfile(INET);
}


# modify_inet(line, enabled, name, type, protocol,
#	      wait, user, program, args, file)
# Modify an existing inetd service
sub modify_inet
{
local(@inet);
open(INET, $_[9]);
@inet = <INET>;
close(INET);
$inet[$_[0]] = ($_[1] ? "" : "#")."$_[2]\t$_[3]\t$_[4]\t$_[5]\t$_[6]\t$_[7]".
	       ($_[8] ? "\t$_[8]\n" : "\n");
&open_tempfile(INET, ">$_[9]");
&print_tempfile(INET, @inet);
&close_tempfile(INET);
}


# delete_inet(line, file)
# Delete an internet service at some line
sub delete_inet
{
local(@inet);
open(INET, $_[1]);
@inet = <INET>;
close(INET);
splice(@inet, $_[0], 1);
&open_tempfile(INET, ">$_[1]");
&print_tempfile(INET, @inet);
&close_tempfile(INET);
}

%prot_name = ("ip", "Internet Protocol",
              "tcp", "Transmission Control Protocol",
              "udp", "User Datagram Protocol",
              "tcp6", "Transmission Control Protocol IPv6",
              "udp6", "User Datagram Protocol IPv6");

1;

