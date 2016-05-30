use strict;
use warnings;

do 'bind8-lib.pl';
# Globals from bind8-lib.pl
our (%config, %text, %in);

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
my @rv;

# Add main .conf files
my $conf = &get_config();
push(@rv, map { $_->{'file'} } @$conf);

# Add all master and hint zone files
my @views = &find("view", $conf);
my @zones;
foreach my $v (@views) {
	my @vz = &find("zone", $v->{'members'});
	push(@zones, @vz);
	}
push(@zones, &find("zone", $conf));
foreach my $z (@zones) {
	my $tv = &find_value("type", $z->{'members'});
	next if ($tv ne "master" && $tv ne "hint");
	my $file = &find_value("file", $z->{'members'});
	next if (!$file);
	my @recs = &read_zone_file($file, $z->{'value'});
	push(@rv, map { $_->{'file'} } @recs);
	}

return map { &make_chroot($_) } &unique(@rv);
}

# pre_backup(&files)
# Called before the files are actually read
sub pre_backup
{
return undef;
}

# post_backup(&files)
# Called after the files are actually read
sub post_backup
{
return undef;
}

# pre_restore(&files)
# Called before the files are restored from a backup
sub pre_restore
{
return undef;
}

# post_restore(&files)
# Called after the files are restored from a backup
sub post_restore
{
&flush_zone_names();
my $pidfile = &get_pid_file();
if (&check_pid_file(&make_chroot($pidfile, 1))) {
	return &restart_bind();
	}
return undef;
}

1;

