package File::Grep;

use strict;
use Carp;

BEGIN {
  use Exporter   ();
  use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  $VERSION     = sprintf( "%d.%02d", q( $Revision: 0.02 $ ) =~ /\s(\d+)\.(\d+)/ );
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw( fgrep fmap fdo );
  %EXPORT_TAGS = (  );
}

# Remain silent on bad files, else shoutout.
our $SILENT = 1;

# Internal function; does the actual walk through the files, and calls 
# out to the coderef to do the work for each line.  This gives me a bit
# more flexibility with the end interface

sub _fgrep_process {
  my ( $closure, @files ) = @_;
  my $openfile = 0;
  my $abort = 0;
  my $i = 0;
  foreach my $file ( @files ) {
    my $fh;
    if ( UNIVERSAL::isa( \$file, "SCALAR" ) ) {
      # If it's a scalar, assume it's a file and open it
      open FILE, "$file" or 
	( !$SILENT and carp "Cannot open file '$file' for fgrep: $!" ) 
	  and next;
      $fh = \*FILE;
      $openfile = 1;
    } else {
      # Otherwise, we will assume it's a legit filehandle.  
      # If something's
      # amiss, we'll catch it at <> below.
      $fh = $file;
      $openfile = 0;
    }
    my $line;
    eval { $line = <$fh> };
    # Fix for perl5.8 - thanks to Benjamin Kram
    if ( $@ ) {
      !$SILENT and carp "Cannot use file '$file' for fgrep: $@";
      last;
    } else {
      while ( defined( $line ) ) {
	my $state = &$closure( $i, $., $line );
	if ( $state < 0 ) { 
	  # If need to shut down whole process...
	  $abort = 1;
	  last; # while!
	} elsif ( $state == 0 ) {
	  # If need to shut down just this file...
	  $abort = 0;
	  last; # while!
	}
	$line = <$fh>;
      }
    }
    if ( $openfile ) { close $fh; }
    last if ( $abort );  # Fileloop...
    $i++; # Increment counter
  }
  return;
}

sub fgrep (&@) {
  my ( $coderef, @files ) = @_;
  if ( wantarray ) {
    my @matches = map { { filename => $_,
			 count => 0,
			   matches => { } } } @files;
    my $sub = sub { 
      my ( $file, $pos, $line ) = @_;
      local $_ = $line;
      if ( &$coderef( $file, $pos, $_ ) ) { 
	$matches[$file]->{ count }++;
	$matches[$file]->{ matches }->{ $pos } = $line;
      } 
      return 1;
    };

    _fgrep_process( $sub, @files );
    return @matches;

  } elsif ( defined( wantarray ) ) {
    my $count = 0;
    my $sub = sub {
      my ( $file, $pos, $line ) = @_;
      local $_ = $line;
      if ( &$coderef( $file, $pos, $_ ) ) { $count++ };
      return 1;
    };
    
    _fgrep_process( $sub, @files );
    return $count;
  } else {
    my $found = 0;
    my $sub = sub {
      my ( $file, $pos, $line ) = @_;
      local $_ = $line;
      if ( &$coderef( $file, $pos, $_ ) ) 
	{ $found=1; return -1; } 
      else 
	{ return 1; }
    };
    _fgrep_process( $sub, @files );
    return $found;
  }
}

sub fgrep_flat (&@) {
  my ( $coderef, @files ) = @_;
  my @matches;
  my $sub = sub {
    my ( $file, $pos, $line ) = @_;
    local $_ = $line;
    if ( &$coderef( $file, $pos, $_ ) ) {
      push @matches, $line;
      return 1;
    }
  };
  _fgrep_process( $sub, @files );
  return @matches;
}

sub fgrep_into ( &$@ ) {
  my ( $coderef, $arrayref, @files ) = @_;
  my $sub = sub {
    my ( $file, $pos, $line ) = @_;
    local $_ = $line;
    if ( &$coderef( $file, $pos, $_ ) ) {
      push @$arrayref, $line;
      return 1;
    }
  };
  _fgrep_process( $sub, @files );
  return $arrayref;
}

sub fmap (&@) {
  my ( $mapper, @files ) = @_;

  my @mapped;
  my $sub = sub {
    my ( $file, $pos, $line ) = @_;
    local $_ = $line;
    push @mapped, &$mapper( $file, $pos, $_ );
    return 1;
  };
  _fgrep_process( $sub, @files );
  return @mapped;
}

sub fdo (&@) {
  my ( $doer, @files ) = @_;
  my $sub = sub {
    my ( $file, $pos, $line ) = @_;
    local $_ = $line;
    &$doer( $file, $pos, $_ );
    return 1;
  };
  _fgrep_process( $sub, @files );
}

1;
__END__

=head1 NAME

File::Grep - Find matches to a pattern in a series of files and related
             functions

=head1 SYNOPSIS

  use File::Grep qw( fgrep fmap fdo );
  
  # Void context
  if ( fgrep { /$user/ } "/etc/passwd" ) { do_something(); }

  # Scalar context
  print "The index page was hit ",
	( fgrep { /index\.html/ } glob "/var/log/httpd/access.log.*"),
	" times\n";

  # Array context
  my @matches = fgrep { /index\.html } glob "/var/log/httpd/access.log.*";
  print SUMMARY $_ foreach @matches;

  # Mapping
  my @lower = fmap { chomp; lc; } glob "/var/log/httpd/access.log.*";

  # Foreach style..
  my $count;
  fdo { $count++ } @filelist;
  print "Total lines: $count\n";
 
  # More complex handling
  my @matchcount;
  fdo { my ( $file, $pos, $line ) = @_;
        $matchcount[$file]++ if ( $line =~ /keyword/ );
      } @filelist;


=head1 DESCRIPTION

File::Grep mimics the functionality of the grep function in perl, but
applying it to files instead of a list.  This is similar in nature to 
the UNIX grep command, but more powerful as the pattern can be any legal
perl function. 

The main functions provided by this module are:

=over

=item fgrep BLOCK LIST

Performs a grep operation on the files in LIST, using BLOCK as the
critiria for accepting a line or not.  Any lines that match will be 
added to an array that will be returned to the caller.  Note that 
in void context, this function will immediate return true on the first
match, false otherwise, and in scalar context, it will only return
the number of matches.

When entering BLOCK, the $_ variable will be localized to the current
line.  In addition, you will be given the position in LIST of the current
file, the line number in that file, and the line itself as arguments 
to this function.  While you can change $_ if necessary, only the 
original value of the line will be added to the returned list.  If you
need to get the modified value, use fmap (described below).

The LIST can contain either scalars or filehandle (or filehandle-like
objects).  If the item is a scalar, it will be attempted to be opened 
and read in as normal.  Otherwise it will be treated as a filehandle.  
Any errors resulting from IO may be reported to STDERR by setting the 
class variable, $File::Grep::SILENT to false; otherwise, no error
indication is given.

=item fmap BLOCK LIST

Performs a map operation on the files in LIST, using BLOCK as the
mapping function.  The results from BLOCK will be appended to the 
list that is returned at the end of the call.

=item fdo BLOCK LIST

Performs the equivalent of a foreach operation on the files in LIST,
performing BLOCK for each line in each file.  This function has no
return value.  If you need to specialize more than what fgrep or fmap
offer, you can use this function.

=back

In addition, if you need additional fine control, you can use the internal
function _fgrep_process.  This is called just like fgrep/fmap/fdo, as
in "_fgrep_process BLOCK LIST" except that you can control when the 
fucntion 'short circuits' by the return value from BLOCK.  If, after
processing a line, the BLOCK returns a negative number, the entire 
process is aborted, closing any open filehandles that were opened by 
the function.  If the return value is 0, the current file is aborted,
closed if opened by the function and the next file is then searched.
A positive return value will simply go on to the next line as appropriate.

=head1 EXPORT

"fgrep", "fmap", and "fdo" may be exported, but these are not set by default.

=head1 AUTHOR

Michael K. Neylon, E<lt>mneylon-pm@masemware.comE<gt>

=head1 SEE ALSO

L<perl>.

=cut
