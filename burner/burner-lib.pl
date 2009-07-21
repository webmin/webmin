#!/usr/local/bin/perl
# burner-lib.pl
# Common functions for managing the CD burning profiles

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
&foreign_require("fdisk", "fdisk-lib.pl");

# list_profiles()
# Returns a list of all burn profiles available for use.
# Each profile can be for an ISO, a list of directory mappings, or a list of
# audio track files
sub list_profiles
{
local @rv;
opendir(DIR, $module_config_directory);
foreach $f (sort { $a cmp $b } readdir(DIR)) {
	next if ($f !~ /^(\S+)\.burn$/);
	push(@rv, &get_profile($1));
	}
closedir(DIR);
return @rv;
}

# get_profile(id)
sub get_profile
{
local %burn;
&read_file("$module_config_directory/$_[0].burn", \%burn);
$burn{'id'} = $_[0];
$burn{'file'} = "$module_config_directory/$_[0].burn";
return \%burn;
}

# save_profile(&profile)
sub save_profile
{
$_[0]->{'id'} = time() if (!$_[0]->{'id'});
&write_file("$module_config_directory/$_[0]->{'id'}.burn", $_[0]);
}

# delete_profile(&profile)
sub delete_profile
{
unlink("$module_config_directory/$_[0]->{'id'}.burn");
}

# list_cdrecord_devices()
# Returns a list of all possible CD burner devices
sub list_cdrecord_devices
{
local (@rv, %done);

# First get from CDrecord
open(SCAN, "$config{'cdrecord'} $config{'extra'} -scanbus 2>/dev/null |");
while(<SCAN>) {
	if (/^\s+(\S+)\s+\d+\)\s+'(.*)'\s+'(.*)'\s+'(.*)'\s+(.*)/) {
		push(@rv, { 'dev' => $1,
			    'name' => "$2$3$4",
			    'type' => $5 });
		$done{$1}++;
		}
	}
close(SCAN);

# Then add all cdrom devices
local $uname = `uname -r 2>&1`;
if ($uname =~ /^2\.(\d+)\./ && $1 >= 6) {
	local $disk;
	foreach $disk (&fdisk::list_disks_partitions(1)) {
		if ($disk->{'media'} eq "cdrom" &&
		    !$done{$disk->{'device'}}) {
			push(@rv, { 'dev' => $disk->{'device'},
				    'name' => $disk->{'model'},
				    'type' => uc($disk->{'media'}) });
			}
		}
	}

return @rv;
}

@cdr_drivers = ( 'cdd2600', 'plextor', 'plextor-scan', 'generic-mmc',
		 'generic-mmc-raw', 'ricoh-mp6200', 'yamaha-cdr10x',
		 'teac-cdr55', 'sony-cdu920', 'sony-cdu948', 'taiyo-yuden',
		 'toshiba' );

# can_use_profile(&profile)
# Returns 1 if some burn profile can be used
sub can_use_profile
{
return 1 if ($access{'profiles'} eq '*');
local %can = map { $_, 1 } split(/\s+/, $access{'profiles'});
return $can{$_[0]->{'id'}};
}

# can_directory(file)
# Returns 1 if some file is in an allowed directory
sub can_directory
{
local @dirs = split(/\s+/, $access{'dirs'});
return 1 if ($dirs[0] eq "/");
local $path = &resolve_links($_[0]);
local $d;
foreach $d (@dirs) {
	return 1 if (&is_under_directory(&resolve_links($d), $path));
	}
return 0;
}

1;

