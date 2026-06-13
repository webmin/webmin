use strict;
use warnings;

require 'systemd-lib.pl'; ## no critic

our %access;

# backup_config_files()
# Returns local system and user unit files that should be included in backups.
sub backup_config_files
{
my @rv;
my %seen;
return @rv if (!systemd_acl_bool(\%access, 'backup'));
my $add_file = sub {
	my ($file) = @_;
	push(@rv, $file) if ($file && !$seen{$file}++);
	};

# System unit backups should only include locally managed files under /etc.
foreach my $u (list_units()) {
	$add_file->($u->{'file'})
		if ($u->{'file'} && $u->{'file'} =~ m!^/etc/systemd/system/!);
	my $name = backup_unit_name($u);
	if ($name && dropin_exists(0, undef, $name)) {
		$add_file->(system_dropin_file($name));
		}
	}

# User units live under home directories and are safe to include by path.
foreach my $u (list_all_user_units()) {
	next if (!systemd_acl_user_allowed(\%access, $u->{'user'}));
	$add_file->($u->{'file'}) if ($u->{'file'});
	my $name = backup_unit_name($u);
	if ($name && dropin_exists(1, $u->{'user'}, $name)) {
		$add_file->(user_dropin_file($u->{'user'}, $name));
		}
	}
return @rv;
}

# backup_unit_name(unit)
# Returns the safe unit name from a listed unit row.
sub backup_unit_name
{
my ($u) = @_;
return $u->{'name'} if ($u->{'name'} && valid_unit_name($u->{'name'}));
if ($u->{'file'} && $u->{'file'} =~ m{/([^/]+)$} &&
    valid_unit_name($1)) {
	return $1;
	}
return;
}

# pre_backup()
# No preparation is needed before Webmin copies systemd unit files.
sub pre_backup
{
return;
}

# post_backup()
# No cleanup is needed after Webmin copies systemd unit files.
sub post_backup
{
return;
}

# pre_restore()
# No preparation is needed before Webmin restores systemd unit files.
sub pre_restore
{
return;
}

# post_restore()
# Reloads systemd after restored unit files are back on disk.
sub post_restore
{
reload_manager();
}

1;
