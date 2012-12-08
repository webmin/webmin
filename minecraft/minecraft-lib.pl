# Functions for editing the minecraft config
#
# XXX java param options
# XXX plugins?
# XXX world reset

BEGIN { push(@INC, ".."); };
use strict;
use warnings;
use WebminCore;
&init_config();
our ($module_root_directory, %text, %gconfig, $root_directory, %config,
     $module_name, $remote_user, $base_remote_user, $gpgpath,
     $module_config_directory, @lang_order_list, @root_directories);

# check_minecraft_server()
# Returns an error message if the Minecraft server is not installed
sub check_minecraft_server
{
-d $config{'minecraft_dir'} ||
	return &text('check_edir', $config{'minecraft_dir'});
my $jar = $config{'minecraft_jar'} ||
	  $config{'minecraft_dir'}."/"."minecraft_server.jar";
-r $jar ||
	return &text('check_ejar', $jar);
&has_command($config{'java_cmd'}) ||
	return &text('check_ejava', $config{'java_cmd'});
return undef;
}

# is_minecraft_server_running()
# If the minecraft server is running, return the PID
sub is_minecraft_server_running
{
&foreign_require("proc");
my @procs = &proc::list_processes();
my $jar = $config{'minecraft_jar'} ||
	  $config{'minecraft_dir'}."/"."minecraft_server.jar";
my $shortjar = $jar;
$shortjar =~ s/^.*\///;
foreach my $p (@procs) {
	if ($p->{'args'} =~ /\Q$config{'java_cmd'}\E.*(\Q$jar\E|\Q$shortjar\E)/) {
		return $p->{'pid'};
		}
	}
return undef;
}

# get_minecraft_config()
# Parses the config into an array ref of hash refs
sub get_minecraft_config
{
my @rv;
my $fh = "CONFIG";
my $lnum = 0;
&open_readfile($fh, $config{'minecraft_dir'}."/server.properties") ||
	return [ ];
while(<$fh>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^([^=]+)=(.*)/) {
		push(@rv, { 'name' => $1,
			    'value' => $2,
			    'line' => $lnum });
		}
	$lnum++;
	}
close($fh);
return \@rv;
}

1;
