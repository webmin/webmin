package File::MimeInfo;

use strict;
use Carp;
use Fcntl 'SEEK_SET';
use File::Spec;
use File::BaseDir qw/data_files/;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(mimetype);
our @EXPORT_OK = qw(extensions describe globs inodetype mimetype_canon mimetype_isa);
our $VERSION = '0.27';
our $DEBUG;

our ($_hashed, $_hashed_aliases, $_hashed_subclasses);
our (@globs, %literal, %extension, %mime2ext, %aliases, %subclasses);
our ($LANG, @DIRS);
# @globs = [ [ 'glob', qr//, $mime_string ], ... ]
# %literal contains literal matches
# %extension contains extensions (globs matching /^\*(\.\w)+$/ )
# %mime2ext is used for looking up extension by mime type
# %aliases contains the aliases table
# %subclasses contains the subclasses table
# $LANG can be used to set a default language for the comments
# @DIRS can be used to specify custom database directories

sub new { bless \$VERSION, shift } # what else is there to bless ?

sub mimetype {
	my $file = pop;
	croak 'subroutine "mimetype" needs a filename as argument' unless defined $file;
	return
		inodetype($file) ||
		globs($file)	 ||
		default($file);
}

sub inodetype {
	my $file = pop;
	print STDERR "> Checking inode type\n" if $DEBUG;
	lstat $file or return undef;
	return undef if -f _;
	my $t =	(-l $file) ? 'inode/symlink' :  # Win32 does not like '_' here
		(-d _) ? 'inode/directory'   :
		(-p _) ? 'inode/fifo'        :
		(-c _) ? 'inode/chardevice'  :
		(-b _) ? 'inode/blockdevice' :
		(-S _) ? 'inode/socket'      : '' ;
	if ($t eq 'inode/directory') { # compare devices to detect mount-points
		my $dev = (stat _)[0]; # device of the node under investigation
		$file = File::Spec->rel2abs($file); # get full path
		my @dirs = File::Spec->splitdir($file);
		$file = File::Spec->catfile(@dirs); # removes trailing '/' or equivalent
		return $t if -l $file; # parent can be on other dev for links
		pop @dirs;
		my $dir = File::Spec->catdir(@dirs); # parent dir
		$t = 'inode/mount-point' unless (stat $dir)[0] == $dev; # compare devices
		return $t;
	}
	else { return $t ? $t : undef }
}

sub globs {
	my $file = pop;
	croak 'subroutine "globs" needs a filename as argument' unless defined $file;
	rehash() unless $_hashed;
	(undef, undef, $file) = File::Spec->splitpath($file); # remove path
	print STDERR "> Checking globs for basename '$file'\n" if $DEBUG;

	return $literal{$file} if exists $literal{$file};

	if ($file =~ /\.(\w+(\.\w+)*)$/) {
		my @ext = split /\./, $1;
		while (@ext) {
			my $ext = join('.', @ext);
			print STDERR "> Checking for extension '.$ext'\n" if $DEBUG;
			warn "WARNING: wantarray behaviour of globs() will change in the future.\n" if wantarray;
			return wantarray
				? ($extension{$ext}, $ext)
				: $extension{$ext}
				if exists $extension{$ext};
			shift @ext;
		}
	}

	for (@globs) {
		next unless $file =~ $_->[1];
		print STDERR "> This file name matches \"$_->[0]\"\n" if $DEBUG;
		return $_->[2];
	}

	return globs(lc $file) if $file =~ /[A-Z]/; # recurs
	return undef;
}

sub default {
	my $file = pop;
	croak 'subroutine "default" needs a filename as argument' unless defined $file;

	my $line;
	unless (ref $file) {
		return undef unless -f $file;
		print STDERR "> File exists, trying default method\n" if $DEBUG;
		return 'text/plain' if -z $file;

		open FILE, '<', $file or return undef;
		binmode FILE, ':utf8' unless $] < 5.008;
		read FILE, $line, 32;
		close FILE;
	}
	else {
		print STDERR "> Trying default method on object\n" if $DEBUG;

		$file->seek(0, SEEK_SET);
		$file->read($line, 32);
	}

	{
		no warnings; # warnings can be thrown when input not ascii
		if ($] < 5.008 or ! utf8::valid($line)) {
			use bytes; # avoid invalid utf8 chars
			$line =~ s/\s//g; # \m, \n and \t are also control chars
			return 'text/plain' unless $line =~ /[\x00-\x1F\x7F]/;
		}
		else {
			# use perl to do something intelligent for ascii & utf8
			return 'text/plain' unless $line =~ /[^[:print:]\s]/;
		}
	}
	print STDERR "> First 10 bytes of the file contain control chars\n" if $DEBUG;
	return 'application/octet-stream';
}

sub rehash {
	(@globs, %literal, %extension, %mime2ext) = (); # clear all data
	local $_; # limit scope of $_ ... :S
	my @globfiles = @DIRS
		? ( grep {-e $_ && -r $_} map "$_/globs", @DIRS )
		: ( reverse data_files('mime/globs')        );
	print STDERR << 'EOT' unless @globfiles;
WARNING: You don't seem to have a mime-info database. The
shared-mime-info package is available from http://freedesktop.org/ .
EOT
	my @done;
	for my $file (@globfiles) {
		next if grep {$file eq $_} @done;
		_hash_globs($file);
		push @done, $file;
	}
	$_hashed = 1;
}

sub _hash_globs {
	my $file = shift;
	open GLOB, '<', $file || croak "Could not open file '$file' for reading" ;
	binmode GLOB, ':utf8' unless $] < 5.008;
	my ($string, $glob);
	while (<GLOB>) {
		next if /^\s*#/ or ! /\S/; # skip comments and empty lines
		chomp;
		($string, $glob) = split /:/, $_, 2;
		unless ($glob =~ /[\?\*\[]/) { $literal{$glob} = $string }
		elsif ($glob =~ /^\*\.(\w+(\.\w+)*)$/) {
		    $extension{$1} = $string unless exists $extension{$1};
		    $mime2ext{$string} = [] if !defined($mime2ext{$string});
		    push @{$mime2ext{$string}}, $1;
		} else { unshift @globs, [$glob, _glob_to_regexp($glob), $string] }
	}
	close GLOB || croak "Could not open file '$file' for reading" ;
}

sub _glob_to_regexp {
	my $glob = shift;
	$glob =~ s/\./\\./g;
	$glob =~ s/([?*])/.$1/g;
	$glob =~ s/([^\w\/\\\.\?\*\[\]])/\\$1/g;
	qr/^$glob$/;
}

sub extensions {
	my $mimet = mimetype_canon(pop @_);
	rehash() unless $_hashed;
        my $ref = $mime2ext{$mimet} if exists $mime2ext{$mimet};
	return $ref ? @{$ref}    : undef if wantarray;
        return $ref ? @{$ref}[0] : '';
}

sub describe {
	shift if ref $_[0];
	my ($mt, $lang) = @_;
	croak 'subroutine "describe" needs a mimetype as argument' unless $mt;
	$mt = mimetype_canon($mt);
	$lang = $LANG unless defined $lang;
	my $att =  $lang ? qq{xml:lang="$lang"} : '';
	my $desc;
	my @descfiles = @DIRS
		? ( grep {-e $_ && -r $_} map "$_/$mt.xml", @DIRS        )
		: ( reverse data_files('mime', split '/', "$mt.xml") ) ;
	for my $file (@descfiles) {
		$desc = ''; # if a file was found, return at least empty string
		open XML, '<', $file || croak "Could not open file '$file' for reading";
		binmode XML, ':utf8' unless $] < 5.008;
		while (<XML>) {
			next unless m!<comment\s*$att>(.*?)</comment>!;
			$desc = $1;
			last;
		}
		close XML || croak "Could not open file '$file' for reading";
		last if $desc;
	}
	return $desc;
}

sub mimetype_canon {
	my $mimet = pop;
	croak 'mimetype_canon needs argument' unless defined $mimet;
	rehash_aliases() unless $_hashed_aliases;
	return exists($aliases{$mimet}) ? $aliases{$mimet} : $mimet;
}

sub rehash_aliases {
	%aliases = _read_map_files('aliases');
	$_hashed_aliases++;
}

sub _read_map_files {
	my ($name, $list) = @_;
	my @files = @DIRS
		? ( grep {-e $_ && -r $_} map "$_/$name", @DIRS )
		: ( reverse data_files("mime/$name")        );
	my (@done, %map);
	for my $file (@files) {
		next if grep {$_ eq $file} @done;
		open MAP, '<', $file || croak "Could not open file '$file' for reading";
		binmode MAP, ':utf8' unless $] < 5.008;
		while (<MAP>) {
			next if /^\s*#/ or ! /\S/; # skip comments and empty lines
			chomp;
			my ($k, $v) = split /\s+/, $_, 2;
			if ($list) {
				$map{$k} = [] unless $map{$k};
				push @{$map{$k}}, $v;
			}
			else { $map{$k} = $v }
		}
		close MAP;
		push @done, $file;
	}
	return %map;
}

sub mimetype_isa {
	my $parent = pop || croak 'mimetype_isa needs argument';
	my $mimet = pop;
	if (ref $mimet or ! defined $mimet) {
		$mimet = mimetype_canon($parent);
		undef $parent;
	}
	else {
		$mimet = mimetype_canon($mimet);
		$parent = mimetype_canon($parent);
	}
	rehash_subclasses() unless $_hashed_subclasses;

	my @subc;
	push @subc, 'inode/directory' if $mimet eq 'inode/mount-point';
	push @subc, @{$subclasses{$mimet}} if exists $subclasses{$mimet};
	push @subc, 'text/plain' if $mimet =~ m#^text/#;
	push @subc, 'application/octet-stream' unless $mimet =~ m#^inode/#;

	return $parent ? scalar(grep {$_ eq $parent} @subc) : @subc;
}

sub rehash_subclasses {
	%subclasses = _read_map_files('subclasses', 'LIST');
	$_hashed_subclasses++;
}

1;

__END__

=head1 NAME

File::MimeInfo - Determine file type

=head1 SYNOPSIS

  use File::MimeInfo;
  my $mime_type = mimetype($file);

=head1 DESCRIPTION

This module can be used to determine the mime type of a file. It
tries to implement the freedesktop specification for a shared
MIME database.

For this module shared-mime-info-spec 0.13 was used.

This package only uses the globs file. No real magic checking is
used. The L<File::MimeInfo::Magic> package is provided for magic typing.

If you want to determine the mimetype of data in a memory buffer you should
use L<File::MimeInfo::Magic> in combination with L<IO::Scalar>.

This module loads the various data files when needed. If you want to
hash data earlier see the C<rehash> methods below.

=head1 EXPORT

The method C<mimetype> is exported by default.
The methods C<inodetype>, C<globs>, C<extensions>, C<describe>,
C<mimetype_canon> and C<mimetype_isa> can be exported on demand.

=head1 METHODS

=over 4

=item C<new()>

Simple constructor to allow Object Oriented use of this module.
If you want to use this, include the package as C<use File::MimeInfo ();>
to avoid importing sub C<mimetype()>.

=item C<mimetype($file)>

Returns a mimetype string for C<$file>, returns undef on failure.

This method bundles C<inodetype> and C<globs>.

If these methods are unsuccessful the file is read and the mimetype defaults
to 'text/plain' or to 'application/octet-stream' when the first ten chars
of the file match ascii control chars (white spaces excluded).
If the file doesn't exist or isn't readable C<undef> is returned.

=item C<inodetype($file)>

Returns a mimetype in the 'inode' namespace or undef when the file is
actually a normal file.

=item C<globs($file)>

Returns a mimetype string for C<$file> based on the filename and filename extensions.
Returns undef on failure. The file doesn't need to exist.

Behaviour in list context (wantarray) is unspecified and will change in future
releases.

=item C<default($file)>

This method decides whether a file is binary or plain text by looking at
the first few bytes in the file. Used to decide between "text/plain" and
"application/octet-stream" if all other methods have failed.

The spec states that we should check for the ascii control chars and let
higher bit chars pass to allow utf8. We try to be more intelligent using
perl utf8 support.

=item C<extensions($mimetype)>

In list context, returns the list of filename extensions that map to the given mimetype.
In scalar context, returns the first extension that is found in the database
for this mimetype.

=item C<describe($mimetype, $lang)>

Returns a description of this mimetype as supplied by the mime info database.
You can specify a language with the optional parameter C<$lang>, this should be
the two letter language code used in the xml files. Also you can set the global
variable C<$File::MimeInfo::LANG> to specify a language.

This method returns undef when no xml file was found (i.e. the mimetype
doesn't exist in the database). It returns an empty string when the xml file doesn't
contain a description in the language you specified.

I<Currently no real xml parsing is done, it trusts the xml files are nicely formatted.>

=item C<mimetype_canon($mimetype)>

Returns the canonical mimetype for a given mimetype.
Deprecated mimetypes are typically aliased to their canonical variants.
This method only checks aliases, doesn't check whether the mimetype
exists.

Use this method as a filter when you take a mimetype as input.

=item C<mimetype_isa($mimetype)>

=item C<mimetype_isa($mimetype, $mimetype)>

When give only one argument this method returns a list with mimetypes that are parent
classes for this mimetype.

When given two arguments returns true if the second mimetype is a parent class of
the first one.

This method checks the subclasses table and applies a few rules for implicit
subclasses.

=item C<rehash()>

Rehash the data files. Glob information is preparsed when this method is called.

If you want to by-pass the XDG basedir system you can specify your database
directories by setting C<@File::MimeInfo::DIRS>. But normally it is better to
change the XDG basedir environment variables.

=item C<rehash_aliases()>

Rehashes the F<mime/aliases> files.

=item C<rehash_subclasses()>

Rehashes the F<mime/subclasses> files.

=back

=head1 DIAGNOSTICS

This module throws an exception when it can't find any data files, when it can't
open a data file it found for reading or when a subroutine doesn't get enough arguments.
In the first case you either don't have the freedesktop mime info database installed,
or your environment variables point to the wrong places,
in the second case you have the database installed, but it is broken
(the mime info database should logically be world readable).

=head1 TODO

Make an option for using some caching mechanism to reduce init time.

Make C<describe()> use real xml parsing ?

=head1 LIMITATIONS

Perl versions prior to 5.8.0 do not have the ':utf8' IO Layer, thus
for the default method and for reading the xml files
utf8 is not supported for these versions.

Since it is not possible to distinguish between encoding types (utf8, latin1, latin2 etc.)
in a straightforward manner only utf8 is supported (because the spec recommends this).

This module does not yet check extended attributes for a mimetype.
Patches for this are very welcome.

=head1 AUTHOR

Jaap Karssenberg E<lt>pardus@cpan.orgE<gt>
Maintained by Michiel Beijen E<lt>michiel.beijen@gmail.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2003, 2012 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<File::BaseDir>,
L<File::MimeInfo::Magic>,
L<File::MimeInfo::Applications>,
L<File::MimeInfo::Rox>

=over 4

=item related CPAN modules

L<File::MMagic>

=item freedesktop specifications used

L<http://www.freedesktop.org/wiki/Specifications/shared-mime-info-spec>,
L<http://www.freedesktop.org/wiki/Specifications/basedir-spec>,
L<http://www.freedesktop.org/wiki/Specifications/desktop-entry-spec>

=item freedesktop mime database

L<http://www.freedesktop.org/wiki/Software/shared-mime-info>

=back

=cut
