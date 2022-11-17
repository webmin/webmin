package File::BaseDir;

use strict;
use Carp;
require File::Spec;
require Exporter;

our $VERSION = 0.07;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = (
	vars => [ qw(
		xdg_data_home xdg_data_dirs
		xdg_config_home xdg_config_dirs
		xdg_cache_home
	) ],
	lookup => [ qw(
		data_home data_dirs data_files
		config_home config_dirs config_files
		cache_home
	) ],
);
our @EXPORT_OK = (
	qw(xdg_data_files xdg_config_files),
	map @$_, values %EXPORT_TAGS
);

# Set root and home directories
my $rootdir = File::Spec->rootdir();
if ($^O eq 'MSWin32') {
	$rootdir = 'C:\\'; # File::Spec default depends on CWD
	$ENV{HOME} ||= $ENV{USERPROFILE} || $ENV{HOMEDRIVE}.$ENV{HOMEPATH};
		# logic from File::HomeDir::Windows
}
my $home = $ENV{HOME};
unless ($home) {
	# Default to  operating system's home dir. NOTE: web applications may not have $ENV{HOME} assigned,
	# so don't issue a warning. See RT bug #41744
	$home = $rootdir;
}

# Set defaults
our $xdg_data_home = File::Spec->catdir($home, qw/.local share/);
our @xdg_data_dirs = (
	File::Spec->catdir($rootdir, qw/usr local share/),
	File::Spec->catdir($rootdir, qw/usr share/),
);
our $xdg_config_home = File::Spec->catdir($home, '.config');
our @xdg_config_dirs = ( File::Spec->catdir($rootdir, qw/etc xdg/) );
our $xdg_cache_home = File::Spec->catdir($home, '.cache');

# OO method
sub new { bless \$VERSION, shift } # what else is there to bless ?

# Variable methods
sub xdg_data_home { $ENV{XDG_DATA_HOME} || $xdg_data_home }

sub xdg_data_dirs {
	( $ENV{XDG_DATA_DIRS}
		? _adapt($ENV{XDG_DATA_DIRS})
		: @xdg_data_dirs
	)
}

sub xdg_config_home {$ENV{XDG_CONFIG_HOME} || $xdg_config_home }

sub xdg_config_dirs {
	( $ENV{XDG_CONFIG_DIRS}
		? _adapt($ENV{XDG_CONFIG_DIRS})
		: @xdg_config_dirs
	)
}

sub xdg_cache_home { $ENV{XDG_CACHE_HOME} || $xdg_cache_home }

sub _adapt {
	map { File::Spec->catdir( split('/', $_) ) } split /[:;]/, shift;
		# ':' defined in the spec, but ';' is standard on win32
}

# Lookup methods
sub data_home { _catfile(xdg_data_home, @_) }

sub data_dirs { _find_files(\&_dir, \@_, xdg_data_home, xdg_data_dirs) }

sub data_files { _find_files(\&_file, \@_, xdg_data_home, xdg_data_dirs) }

sub xdg_data_files { my @dirs = data_files(@_); return @dirs }

sub config_home { _catfile(xdg_config_home, @_) }

sub config_dirs { _find_files(\&_dir, \@_, xdg_config_home, xdg_config_dirs) }

sub config_files { _find_files(\&_file, \@_, xdg_config_home, xdg_config_dirs) }

sub xdg_config_files { my @dirs = config_files(@_); return @dirs }

sub cache_home { _catfile(xdg_cache_home, @_) }

sub _catfile {
	my $dir = shift;
	shift if ref $_[0] or $_[0] =~ /::/; # OO call
	return File::Spec->catfile($dir, @_);
}

sub _find_files {
	my $type = shift;
	my $file = shift;
	shift @$file if ref $$file[0] or $$file[0] =~ /::/; # OO call
	#warn "Looking for: @$file\n         in: @_\n";
	if (wantarray) {
		return grep { &$type( $_ ) && -r $_ }
		       map  { File::Spec->catfile($_, @$file) } @_;
	}
	else { # prevent unnecessary stats by returning early
		for (@_) {
			my $path = File::Spec->catfile($_, @$file);
			return $path if &$type($path) && -r $path;
		}
	}
	return ();
}

sub _dir { -d $_[0] }

sub _file { -f $_[0] }

1;

__END__

=head1 NAME

File::BaseDir - Use the Freedesktop.org base directory specification

=head1 SYNOPSIS

	use File::BaseDir qw/xdg_data_files/;
	for ( xdg_data_files('mime/globs') ) {
		# do something
	}

=head1 DESCRIPTION

This module can be used to find directories and files as specified
by the Freedesktop.org Base Directory Specification. This specifications
gives a mechanism to locate directories for configuration, application data
and cache data. It is suggested that desktop applications for e.g. the 
Gnome, KDE or Xfce platforms follow this layout. However, the same layout can
just as well be used for non-GUI applications.

This module forked from L<File::MimeInfo>.

This module follows version 0.6 of BaseDir specification.

=head1 EXPORT

None by default, but all methods can be exported on demand.
Also the groups ":lookup" and ":vars" are defined. The ":vars" group
contains all routines with a "xdg_" prefix; the ":lookup" group
contains the routines to locate files and directories.

=head1 METHODS

=over 4

=item C<new()>

Simple constructor to allow Object Oriented use of this module.

=back

=head2 Lookup

The following methods are used to lookup files and folders in one of the
search paths.

=over 4

=item C<data_home(@PATH)>

Takes a list of file path elements and returns a new path by appending
them to the data home directory. The new path does not need to exist.
Use this when writing user specific application data.

Example:

  # data_home is: /home/USER/.local/share
  $path = $bd->data_home('Foo', 'Bar', 'Baz');
  # returns: /home/USER/.local/share/Foo/Bar/Baz

=item C<data_dirs(@PATH)>

Looks for directories specified by C<@PATH> in the data home and
other data directories. Returns (possibly empty) list of readable
directories. In scalar context only the first directory found is
returned. Use this to lookup application data.

=item C<data_files(@PATH)>

Looks for files specified by C<@PATH> in the data home and other data
directories. Only returns files that are readable. In scalar context only
the first file found is returned. Use this to lookup application data.

=item C<config_home(@PATH)>

Takes a list of path elements and appends them to the config home
directory returning a new path. The new path does not need to exist.
Use this when writing user specific configuration.

=item C<config_dirs(@PATH)>

Looks for directories specified by C<@PATH> in the config home and
other config directories. Returns (possibly empty) list of readable
directories. In scalar context only the first directory found is
returned. Use this to lookup configuration.

=item C<config_files(@PATH)>

Looks for files specified by C<@PATH> in the config home and other
config directories. Returns a (possibly empty) list of files that
are readable. In scalar context only the first file found is returned.
Use this to lookup configuration.

=item C<cache_home(@PATH)>

Takes a list of path elements and appends them to the cache home
directory returning a new path. The new path does not need to exist.

=back

=head2 Variables

The following methods only returns the value of one of the XDG variables.

=over 4

=item C<xdg_data_home>

Returns either C<$ENV{XDG_DATA_HOME}> or it's default value.
Default is F<$HOME/.local/share>.

=item C<xdg_data_dirs>

Returns either C<$ENV{XDG_DATA_DIRS}> or it's default value as list.
Default is F</usr/local/share>, F</usr/share>.

=item C<xdg_config_home>

Returns either C<$ENV{XDG_CONFIG_HOME}> or it's default value.
Default is F<$HOME/.config>.

=item C<xdg_config_dirs>

Returns either C<$ENV{XDG_CONFIG_DIRS}> or it's default value as list.
Default is F</etc/xdg>.

=item C<xdg_cache_home>

Returns either C<$ENV{XDG_CACHE_HOME}> or it's default value.
Default is F<$HOME/.cache>.

=back

=head1 NON-UNIX PLATFORMS

The use of L<File::Spec> ensures that all paths are returned in the appropriate
form for the current platform. On Windows this module will try to set C<$HOME>
to a sensible value if it is not defined yet. On other platforms one can use
e.g. L<File::HomeDir> to set $HOME before loading File::BaseDir.

Please note that the specification is targeting Unix platforms only and
will only have limited relevance on other platforms. Any platform dependent
behavior in this module should be considered an extension of the spec.

=head1 BACKWARDS COMPATIBILITY

The methods C<xdg_data_files()> and C<xdg_config_files()> are exported for
backwards compatibility with version 0.02. They are identical to C<data_files()>
and C<config_files()> respectively but without the C<wantarray> behavior.

=head1 BUGS

Please mail the author if you encounter any bugs.

=head1 AUTHOR

Jaap Karssenberg || Pardus [Larus] E<lt>pardus@cpan.orgE<gt>

Copyright (c) 2003, 2007 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

Currently being maintained by Kim Ryan

=head1 SEE ALSO

L<http://www.freedesktop.org/wiki/Specifications/basedir-spec>

