package File::BaseDir;

use strict;
use warnings;
use Exporter 5.57 qw( import );
use File::Spec;
use Config;

# ABSTRACT: Use the Freedesktop.org base directory specification
our $VERSION = '0.09'; # VERSION

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

if($^O eq 'MSWin32')
{
  *_rootdir = sub { 'C:\\' };
  *_home    = sub { $ENV{USERPROFILE} || $ENV{HOMEDRIVE}.$ENV{HOMEPATH} || 'C:\\' };
}
else
{
  *_rootdir = sub { File::Spec->rootdir };
  *_home    = sub { $ENV{HOME} || eval { [getpwuid($>)]->[7] } || File::Spec->rootdir };
}

# OO method
sub new { bless \$VERSION, shift } # what else is there to bless ?

# Variable methods
sub xdg_data_home { $ENV{XDG_DATA_HOME} || File::Spec->catdir(_home(), qw/.local share/) }

sub xdg_data_dirs {
  ( $ENV{XDG_DATA_DIRS}
    ? _adapt($ENV{XDG_DATA_DIRS})
    : (File::Spec->catdir(_rootdir(), qw/usr local share/), File::Spec->catdir(_rootdir(), qw/usr share/))
  )
}

sub xdg_config_home {$ENV{XDG_CONFIG_HOME} || File::Spec->catdir(_home(), '.config') }

sub xdg_config_dirs {
  ( $ENV{XDG_CONFIG_DIRS}
    ? _adapt($ENV{XDG_CONFIG_DIRS})
    : File::Spec->catdir(_rootdir(), qw/etc xdg/)
  )
}

sub xdg_cache_home { $ENV{XDG_CACHE_HOME} || File::Spec->catdir(_home(), '.cache') }

sub _adapt {
  map { File::Spec->catdir( split(/\//, $_) ) } split /\Q$Config{path_sep}\E/, shift;
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
  if (wantarray) {  ## no critic (Community::Wantarray)
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

=pod

=encoding UTF-8

=head1 NAME

File::BaseDir - Use the Freedesktop.org base directory specification

=head1 VERSION

version 0.09

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
GNOME, KDE or Xfce platforms follow this layout. However, the same layout can
just as well be used for non-GUI applications.

This module forked from L<File::MimeInfo>.

This module follows version 0.6 of BaseDir specification.

=head1 CONSTRUCTOR

=head2 new

 my $bd = File::BaseDir->new;

Simple constructor to allow calling functions as object oriented methods.

=head1 FUNCTIONS

None of these are exported by default, but all functions can be exported
by request.  Also the groups C<:lookup> and C<:vars> are defined.  The
C<:vars> group contains all the routines with a C<xdg_> prefix. The
C<:lookup> group contains the routines to locate files and directories.

=head2 data_home

 my $path = data_home(@path);
 my $path = $bd->data_home(@path);

Takes a list of file path elements and returns a new path by appending
them to the data home directory. The new path does not need to exist.
Use this when writing user specific application data.

Example:

 # data_home is: /home/USER/.local/share
 $path = $bd->data_home('Foo', 'Bar', 'Baz');
 # returns: /home/USER/.local/share/Foo/Bar/Baz

=head2 data_dirs

 # :lookup
 my $dir = data_dirs(@path);
 my $dir = $bd->data_dirs(@path);
 my @dirs = data_dirs(@path);
 my @dirs = $bd->data_dirs(@path);

Looks for directories specified by C<@path> in the data home and
other data directories. Returns (possibly empty) list of readable
directories. In scalar context only the first directory found is
returned. Use this to lookup application data.

=head2 data_files

 # :lookup
 my $file = data_files(@path);
 my $file = $bd->data_files(@path);
 my @files = data_files(@path);
 my @files = $bd->data_files(@path);

Looks for files specified by C<@path> in the data home and other data
directories. Only returns files that are readable. In scalar context only
the first file found is returned. Use this to lookup application data.

=head2 config_home

 # :lookup
 my $dir = config_home(@path);
 my $dir = $bd->config_home(@path);

Takes a list of path elements and appends them to the config home
directory returning a new path. The new path does not need to exist.
Use this when writing user specific configuration.

=head2 config_dirs

 # :lookup
 my $dir = config_dirs(@path);
 my $dir = $bd->config_dirs(@path);
 my @dirs = config_dirs(@path);
 my @dirs = $bd->config_dirs(@path);

Looks for directories specified by C<@path> in the config home and
other config directories. Returns (possibly empty) list of readable
directories. In scalar context only the first directory found is
returned. Use this to lookup configuration.

=head2 config_files

 # :lookup
 my $file = config_files(@path);
 my $file = $bd->config_files(@path);
 my @files = config_files(@path);
 my @files = $bd->config_files(@path);

Looks for files specified by C<@path> in the config home and other
config directories. Returns a (possibly empty) list of files that
are readable. In scalar context only the first file found is returned.
Use this to lookup configuration.

=head2 cache_home

 # :lookup
 my $dir = cache_home(@path);
 my $dir = $bd->cache_home(@path);

Takes a list of path elements and appends them to the cache home
directory returning a new path. The new path does not need to exist.

=head2 xdg_data_home

 # :var
 my $dir = xdg_data_home;
 my $dir = $bd->xdg_data_home;

Returns either C<$ENV{XDG_DATA_HOME}> or it's default value.
Default is F<$HOME/.local/share>.

=head2 xdg_data_dirs

 # :var
 my @dirs = xdg_data_dirs;
 my @dirs = $bd->xdg_data_dirs;

Returns either C<$ENV{XDG_DATA_DIRS}> or it's default value as list.
Default is F</usr/local/share>, F</usr/share>.

=head2 xdg_config_home

 # :var
 my $dir = xdg_config_home;
 my $dir = $bd->xdg_config_home;

Returns either C<$ENV{XDG_CONFIG_HOME}> or it's default value.
Default is F<$HOME/.config>.

=head2 xdg_config_dirs

 # :var
 my @dirs = xdg_config_dirs;
 my @dirs = $bd->xdg_config_dirs;

Returns either C<$ENV{XDG_CONFIG_DIRS}> or it's default value as list.
Default is F</etc/xdg>.

=head2 xdg_cache_home

 # :var
 my $dir = xdg_cache_home;
 my $dir = $bd->xdg_cache_home;

Returns either C<$ENV{XDG_CACHE_HOME}> or it's default value.
Default is F<$HOME/.cache>.

=head1 NON-UNIX PLATFORMS

The use of L<File::Spec> ensures that all paths are returned in their native
formats regardless of platform.  On Windows this module will use the native
environment variables, rather than the default on UNIX (which is traditionally
C<$HOME>).

Please note that the specification is targeting Unix platforms only and
will only have limited relevance on other platforms. Any platform dependent
behavior in this module should be considered an extension of the spec.

=head1 BACKWARDS COMPATIBILITY

The methods C<xdg_data_files()> and C<xdg_config_files()> are exported for
backwards compatibility with version 0.02. They are identical to C<data_files()>
and C<config_files()> respectively but without the C<wantarray> behavior.

=head1 AUTHORS

=over 4

=item *

Jaap Karssenberg || Pardus [Larus] <pardus@cpan.org>

=item *

Graham Ollis <plicease@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2003-2021 by Jaap Karssenberg || Pardus [Larus] <pardus@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
