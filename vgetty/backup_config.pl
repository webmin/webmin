
do 'vgetty-lib.pl';
&foreign_require("inittab", "inittab-lib.pl");

# backup_config_files()
# Returns files and directories that can be backed up
sub backup_config_files
{
local @rv = ( $config{'vgetty_config'},
	      $inittab::config{'inittab_file'} );
local @conf = &get_config();
local $rings = &find_value("rings", \@conf);
if ($rings =~ /^\//) {
	push(@rv, $rings);
	}
local $ans = &find_value("answer_mode", \@conf);
if ($ans =~ /^\//) {
	push(@rv, $ans);
	}
return @rv;
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
return &apply_configuration();
}

1;

