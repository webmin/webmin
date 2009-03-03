# inetd-lib.pl
# Common functions for managing inetd.conf and services files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

$lib = &get_mod_lib();
if ($lib) {
	do $lib;
	}

# list_inets_files()
# Returns a list of inetd configuration files
sub list_inets_files
{
local @files = ( $config{'inetd_conf_file'} );
if ($config{'inetd_dir'}) {
	opendir(DIR, $config{'inetd_dir'});
	local $f;
	foreach $f (readdir(DIR)) {
		next if ($f =~ /^\./);
		push(@files, "$config{'inetd_dir'}/$f");
		}
	closedir(DIR);
	}
return @files;
}

# list_rpcs()
# Returns a list of rpc services, in the format
#  line name number aliases index
sub list_rpcs
{
local(@rv, $l);
$l = 0;
open(RPC, $config{rpc_file});
while(<RPC>) {
	chop; s/#.*$//g;
	if (/^(\S+)\s+(\d+)\s*(.*)$/) {
		push(@rv, [ $l, $1, $2, $3, scalar(@rv) ]);
		}
	$l++;
	}
close(RPC);
return @rv;
}
	
# create_rpc(name, number, aliases)
# Create a new rpc file entry
sub create_rpc
{
&open_tempfile(RPC, ">> $config{rpc_file}");
&print_tempfile(RPC, "$_[0]\t$_[1]",($_[2] ? "\t$_[2]\n" : "\n"));
&close_tempfile(RPC);
}


# modify_rpc(line, name, number, aliases)
# Change an existing rpc program
sub modify_rpc
{
local(@rpcs);
open(RPC, $config{rpc_file});
@rpcs = <RPC>;
close(RPC);
$rpcs[$_[0]] = "$_[1]\t$_[2]".($_[3] ? "\t$_[3]\n" : "\n");
&open_tempfile(RPC, "> $config{rpc_file}");
&print_tempfile(RPC, @rpcs);
&close_tempfile(RPC);
}


# delete_rpc(line)
# Delete an entry from the rpc file
sub delete_rpc
{
local(@rpcs);
open(RPC, $config{rpc_file});
@rpcs = <RPC>;
close(RPC);
splice(@rpcs, $_[0], 1);
&open_tempfile(RPC, "> $config{rpc_file}");
&print_tempfile(RPC, @rpcs);
&close_tempfile(RPC);
}


sub lock_inetd_files
{
&lock_file($config{'inetd_conf_file'}, 0, 1);
&lock_file($config{'services_file'}, 0, 1);
&lock_file($config{'protocols_file'}, 0, 1);
&lock_file($config{'rpc_file'}, 0, 1);
}

sub unlock_inetd_files
{
&unlock_file($config{'inetd_conf_file'});
&unlock_file($config{'services_file'});
&unlock_file($config{'protocols_file'});
&unlock_file($config{'rpc_file'});
}

1;
