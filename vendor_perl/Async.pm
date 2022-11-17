
package Async;
$VERSION = '0.10';

sub new {
  my ($pack, $task) = @_;
  my $r   = \ do {local *FH};
  my $w = \ do {local *FH};
  unless (pipe $r, $w) {
    $ERROR = "Couldn't make pipe: $!";
    return;
  }
  my $pid = fork();
  unless (defined $pid) {
    $ERROR = "Couldn't fork: $!";
    return;
  }
  if ($pid) {			# parent
    close $w;
    my $self = { TASK => $task,
		 PID => $pid,
		 PIPE => $r,
		 FD => fileno($r),
		 DATA => '',
	       };
    bless $self => $pack;
  } else {			# child
    close $r;
    my $result = $task->();
    print $w $result;
    exit 0;
  }
}

# return true iff async process is complete
# with true `$force' argmuent, wait until process is complete before returning
sub ready {
  my ($self, $force) = @_;
  my $timeout;
  $timeout = 0 unless $force;
  return 1 if $self->{FINISHED};
  my $fdset = '';
  vec($fdset, $self->{FD}, 1) = 1;
  while (select($fdset, undef, undef, $timeout)) {
    my $buf;
    my $nr = read $self->{PIPE}, $buf, 8192;
    if ($nr) {
      $self->{DATA} .= $buf;
    } elsif (defined $nr) {		# EOF
      $self->{FINISHED} = 1;
      return 1;
    } else {
      $self->{ERROR} = "Read error: $!";
      $self->{FINISHED} = 1;
      return 1;
    }
  }
  return 0;
}

# Return error message if an error occurred
# Return false if no error occurred 
sub error {
  $_[0]{ERROR};
}

# Return resulting data if async process is complete
# return undef if it is incopmplete
# a true $force argument waits for the process to complete before returning
sub result {
  my ($self, $force) = @_;
  if ($self->{FINISHED}) {
    $self->{DATA};
  } elsif ($force) {
    $self->ready('force completion');
    $self->{DATA};
  } else {
    return;
  }
}

sub DESTROY {
  my ($self) = @_;
  my $pid = $self->{PID};
  kill 9 => $pid;	# I don't care.
  waitpid($pid, 0);
}

package AsyncTimeout;
@ISA = 'Async';

sub new {
  my ($pack, $task, $timeout, $msg) = @_;
  $msg = "Timed out\n" unless defined $msg;
  my $newtask = 
    sub { 
      local $SIG{ALRM} = sub {  die "TIMEOUT\n"  };
      alarm $timeout; 
      my $s = eval {$task->()};
      return $msg if !defined($s) && $@ eq "TIMEOUT\n";
      return $s;
    };
  my $self = Async->new($newtask);
  return unless $self;
  bless $self => AsyncTimeout;
}

package AsyncData;
@ISA = 'Async';

sub new {
  require Storable;
  my ($pack, $task) = @_;
  my $newtask =
    sub {
      my $v = $task->();
      return Storable::freeze($v);
    };
  my $self = Async->new($newtask);
  return unless $self;
  bless $self => AsyncData;
}

sub result {
  require Storable;
  my $self = shift;
  my $rc = $self->SUPER::result(@_);
  return defined $rc ? Storable::thaw($rc) : $rc;
}

1;

=head1 NAME

Async - Asynchronous evaluation of Perl code (with optional timeouts)

=head1 SYNOPSIS

  my $proc = Async->new(sub { any perl code you want executed });
  
  if ($proc->ready) {
    # the code has finished executing
    if ($proc->error) {
      # something went wrong
    } else {
      $result = $proc->result;  # The return value of the code
    }
  }

  # or:
  $result = $proc->result('force completion');  # wait for it to finish
  

=head1 DESCRIPTION

C<Async> executes some code in a separate process and retrieves the
result.  Since the code is running in a separate process, your main
program can continue with whatever it was doing while the separate
code is executing.  This separate code is called an `asynchronous
computation'.  When your program wants to check to see if the
asynchronous computation is complete, it can call the C<ready()>
method, which returns true if so, and false if it is still running.

After the asynchronous computation is complete, you should call the
C<error()> method to make sure that everything went all right.
C<error()> will return C<undef> if the computation completed normally,
and an error message otherwise.

Data returned by the computation can be retrieved with the C<result()>
method.  The data must be a single string; any non-string value
returned by the computation will be stringized. (See AsyncData below
for how to avoid this.)  If the computation has not completed yet,
C<result()> will return an undefined value.

C<result()> takes an optional parameter, C<$force>.  If C<$force> is
true, then the calling process will wait until the asynchronous
computation is complete before returning.  

=head2 C<AsyncTimeout>

  use Async;
  $proc = AsyncTimeout->new(sub {...}, $timeout, $special);

C<Async::Timeout> implements a version of C<Async> that has an
automatic timeout.  If the asynchronous computation does not complete
before C<$timeout> seconds have elapsed, it is forcibly terminated and
returns a special value C<$special>.  The default special value is the
string "Timed out\n".

All the other methods for C<AsyncTimeout> are exactly the same as for
C<Async>.

=head2 C<AsyncData>

  use Async;
  $proc = AsyncData->new(sub {...});

C<AsyncData> is just like C<Async> except that instead of returning a
string, the asynchronous computation may return any scalar value.  If
the scalar value is a reference, the C<result()> method will yield a
refernce to a copy of this data structure.

The C<AsyncData> module requires that C<Storable> be installed.
C<AsyncData::new> will die if C<Storable> is unavailable.

All the other methods for C<AsyncData> are exactly the same as for
C<Async>.



=head1 WARNINGS FOR THE PROGRAMMER

The asynchronous computation takes place in a separate process, so
nothing it does can affect the main program.  For example, if it
modifies global variables, changes the current directory, opens and
closes filehandles, or calls C<die>, the parent process will be
unaware of these things.  However, the asynchronous computatin does
inherit the main program's file handles, so if it reads data from
files that the main program had open, that data will not be availble
to the main program; similarly the asynchronous computation can write
data to the same file as the main program if it inherits an open
filehandle for that file.

=head1 ERRORS

The  errors that are reported by the C<error()> mechanism are: those that are internal to C<Async> itself:

	Couldn't make pipe: (reason)
	Couldn't fork: (reason)
	Read error: (reason)

If your asynchronous computation dies for any reason, that is not
considered to be an `error'; that is the normal termination of the
process.  Any messages written to C<STDERR> will go to the
computation's C<STDERR>, which is normally inherited from the main
program, and the C<result()> will be the empty string.

=head1 EXAMPLE

  use Async;
  sub long_running_computation {
     # This function simulates a computation that takes a long time to run
     my ($x) = @_;
     sleep 5;
     return $x+2;  # Eureka!
  }

  # Main program:
  my $proc = Async->new(sub {long_running_computation(2)}) or die;
  # The long-running computation is now executing.
  #

  while (1) {
    print "Main program:  The time is now ", scalar(localtime), "\n";
    my $e;
    if ($proc->ready) {
      if ($e = $proc->error) {
	print "Something went wrong.  The error was: $e\n";
      } else {
	print "The result of the computation is: ", $proc->result, "\n";
      }
      undef $proc;
    }
    # The result is not ready; we can go off and do something else here.
    sleep 1; # One thing we could do is to take nap.
  }

=head1 AUTHOR

Mark-Jason Dominus C<mjd-perl-async+@plover.com>.

=cut
