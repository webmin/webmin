#!/usr/local/bin/perl -w
use strict;
# Detect the operating system and version.

package OsChooser;

# Package scoped for mapping short names to long "proper" names
my %NAMES_TO_REAL;

# main
sub main {
	if ($#ARGV < 1) { die "Usage: $0 os_list.txt outfile [0|1|2|3] [issue]\n"; }
	my ($oslist, $out, $auto, $issue) = @ARGV;
	return write_file($out, oschooser($oslist, $auto, $issue));
	}
main() unless caller(); # make it testable and usable as a library

$| = 1;

sub oschooser {
my ($oslist, $auto, $issue) = @_;
my $ver_ref;

my ($list_ref, $names_ref) = parse_patterns($oslist);

if ($auto && ($ver_ref = auto_detect($oslist, $issue, $list_ref, $names_ref))) {
	return ($ver_ref->[2], $ver_ref->[3], $ver_ref->[0], $ver_ref->[1]);
	}
elsif (!$auto || ($auto == 3 && have_tty()) || $auto == 2) {
	$ver_ref = ask_user($names_ref, $list_ref);
	return ($ver_ref->[2], $ver_ref->[3], $ver_ref->[0], $ver_ref->[1]);
	}
else {
	print "Failed to detect operating system\n";
	exit 1;
	}
}

# Return a reference to a pre-parsed list array, and a ref to a names array
sub parse_patterns {
my ($oslist) = @_;
my @list;
my @names;
my %donename;
# Parse the patterns file
open(OS, "<$oslist") || die "failed to open $oslist : $!";
while(<OS>) {
	chop;
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t*(.*)$/) {
		push(@list, [ $1, $2, $3, $4, $5 ]);
		push(@names, $1) if (!$donename{$1}++);
		$NAMES_TO_REAL{$1} ||= $3;
		}
	}
close(OS);
return (\@list, \@names);
}

# auto_detect($oslist, $issue)
# Returns detected OS details in a hash ref
sub auto_detect {
my ($oslist, $issue, $list_ref) = @_;
my $ver_ref;
my @list = @$list_ref;

# Try to guess the OS name and version
my $etc_issue;
my $uname = `uname -a`;

if ($issue) {
	$etc_issue = `cat $issue`;
	$uname = $etc_issue; # Strangely, I think this will work fine.
	}
elsif (-r "/etc/.issue") {
	$etc_issue = `cat /etc/.issue`;
	}
elsif (-r "/etc/issue") {
	$etc_issue = `cat /etc/issue`;
	}

foreach my $o_ref (@list) {
	if ($issue && $o_ref->[4]) {
		$o_ref->[4] =~ s#cat [/a-zA-Z\-\s]*\s2#cat $issue 2#g;
		} # Testable, but this regex substitution is dumb.XXX
	local $^W = 0; # Disable warnings for evals, which may have undefined vars
	if ($o_ref->[4] && eval "$o_ref->[4]") {
		# Got a match! Resolve the versions
		print "$o_ref->[4]\n";
		$ver_ref = $o_ref;
		if ($ver_ref->[1] =~ /\$/) {
			$ver_ref->[1] = eval "($o_ref->[4]); $ver_ref->[1]";
			}
		if ($ver_ref->[3] =~ /\$/) {
			$ver_ref->[3] = eval "($o_ref->[4]); $ver_ref->[3]";
			}
		last;
		}
	if ($@) {
		print STDERR "Error parsing $o_ref->[4]\n";
		}
	}
	return $ver_ref;
}

sub ask_user {
my ($names_ref, $list_ref) = @_;
my @names = @$names_ref;
my @list = @$list_ref;
my $vnum;
my $osnum;
# ask for the operating system name ourselves
my $dashes = "-" x 75;
print <<EOF;
For Webmin to work properly, it needs to know which operating system
type and version you are running. Please select your system type by
entering the number next to it from the list below
$dashes
EOF
{
my $i;
for($i=0; $i<@names; $i++) {
	printf " %2d) %-20.20s ", $i+1, $names[$i];
	print "\n" if ($i%3 == 2);
	}
print "\n" if ($i%3);
}
print $dashes,"\n";
print "Operating system: ";
chop($osnum = <STDIN>);
if ($osnum !~ /^\d+$/) {
	print "ERROR: You must enter the number next to your operating\n";
	print "system, not its name or version number.\n\n";
	exit 9;
	}
if ($osnum < 1 || $osnum > @names) {
	print "ERROR: $osnum is not a valid operating system number.\n\n";
	exit 10;
	}
print "\n";

# Ask for the operating system version
my $name = $names[$osnum-1];
print <<EOF;
Please enter the version of $name you are running
EOF
print "Version: ";
chop($vnum = <STDIN>);
if ($vnum !~ /^\S+$/) {
	print "ERROR: An operating system number cannot contain\n\n";
	print "spaces. It must be like 2.1 or ES4.0.\n";
	exit 10;
	}
print "\n";
return [ $name, $vnum,
	  $NAMES_TO_REAL{$name}, $vnum ];
}

# write_file($out, $os_type, $os_version, $real_os_type, $real_os_version)
# Write the name, version and real name and version to a file
sub write_file {
my ($out, $os_type, $os_version, $real_os_type, $real_os_version) = @_;
open(OUT, ">$out") or die "Failed to open $out for writing.";
print OUT "os_type='",$os_type,"'\n";
print OUT "os_version='",$os_version,"'\n";
print OUT "real_os_type='",$real_os_type,"'\n";
print OUT "real_os_version='",$real_os_version,"'\n";
return close(OUT);
}

sub have_tty
{
# Do we have a tty?
my $rv = system("tty >/dev/null 2>&1");
if ($?) {
	return 0;
	}
else {
	return 1;
	}
}

1;

__END__

=head1 OsChooser.pm

Attempt to detect operating system and version, or ask the user to select
from a list.  Works from the command line, for usage from shell scripts,
or as a library for use within Perl scripts.

=head2 COMMAND LINE USE

OsChooser.pm os_list.txt outfile [auto] [issue]

Where "auto" can be the following values:

=over 4

=item 0

always ask user

=item 1

automatic, give up if fails

=item 2

automatic, ask user if fails

=item 3

automatic, ask user if fails and if a TTY

=back

=head2 SYNOPSIS

    use OsChooser;
    my ($os_type, $version, $real_os_type, $real_os_version) =
       OsChooser->oschooser("os_list.txt", "outfile", $auto, [$issue]);

=cut

