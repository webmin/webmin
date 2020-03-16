#!/usr/local/bin/perl
# oschooser.pl
# Read the list of operating systems and ask the user to choose
# an OS and version
# auto param: 0 = always ask user
#	      1 = automatic, give up if fails
#	      2 = automatic, ask user if fails
#             3 = automatic, ask user if fails and if a TTY

$| = 1;

($oslist, $out, $auto) = @ARGV;
open(OS, "<".$oslist) || die "failed to open $oslist : $!";
while(<OS>) {
	chop;
	if (/^([^\t]+)\t+([^\t]+)\t+([^\t]+)\t+([^\t]+)\t*(.*)$/) {
		push(@list, [ $1, $2, $3, $4, $5 ]);
		push(@names, $1) if (!$donename{$1}++);
		$names_to_real{$1} ||= $3;
		}
	}
close(OS);

if ($auto) {
	# Try to guess the OS name and version
	if (-r "/etc/.issue") {
		$etc_issue = `cat /etc/.issue`;
		}
	elsif (-r "/etc/issue") {
		$etc_issue = `cat /etc/issue`;
		}
	if (-r "/etc/os-release") {
		$os_release = `cat /etc/os-release`;
		}
	if (&has_command('uname')) {
		$uname = `uname -a 2>/dev/null`;
		}
	foreach $o (@list) {
		if ("$^O" =~ /MSWin32/ && "$o->[2]" !~ /windows/) {
			next;
		}
		if ($o->[4] && eval "$o->[4]") {
			# Got a match! Resolve the versions
			$ver = $o;
			if ($ver->[1] =~ /\$/) {
				$ver->[1] = eval "($o->[4]); $ver->[1]";
				}
			if ($ver->[3] =~ /\$/) {
				$ver->[3] = eval "($o->[4]); $ver->[3]";
				}
			last;
			}
		if ($@) {
			print STDERR "Error parsing $o->[4]\n";
			}
		}

	if (!$ver) {
		if ($auto == 1) {
			# Failed .. give up
			print "Failed to detect operating system\n";
			exit 1;
			}
		elsif ($auto == 3) {
			# Do we have a tty?
			local $rv = system("tty >/dev/null 2>&1");
			if ($?) {
				print "Failed to detect operating system\n";
				exit 1;
				}
			else {
				$auto = 0;
				}
			}
		else {
			# Ask the user
			$auto = 0;
			}
		}
	}

if (!$auto) {
	if (0 && &has_command("dialog")) {
		# call the dialog command to ask for the OS (disabled for now)
		$cmd = "dialog --menu \"Please select your operating system type from the list below\" 20 60 12";
		for($i=0; $i<@names; $i++) {
			$cmd .= " ".($i+1)." '$names[$i]'";
			}
		$tmp_base = $ENV{'tempdir'} || "/tmp/.webmin";
		$temp = "$tmp_base/dialog.out";
		system("$cmd 2>$temp");
		$osnum = `cat $temp`;
		$osnum = int($osnum);
		if (!$osnum) {
			#unlink($temp);
			print "ERROR: No operating system selected\n\n";
			exit 9;
			}

		# call the dialog command to ask for the version
		$name = $names[$osnum-1];
		@vers = grep { $_->[0] eq $name } @list;
		$cmd = "dialog --menu \"Please select your operating system's version from the list below\" 20 60 12";
		for($i=0; $i<@vers; $i++) {
			$cmd .= " ".($i+1)." '$name $vers[$i]->[1]'";
			}
		system("$cmd 2>$temp");
		$vnum = `cat $temp`;
		$vnum = int($vnum);
		unlink($temp);
		if (!$vnum) {
			print "ERROR: No operating system version selected\n\n";
			exit 9;
			}
		$ver = $vers[$vnum-1];
		}
	else {
		# ask for the operating system name ourselves
		$dashes = "-" x 75;
		print <<EOF;
For Webmin to work properly, it needs to know which operating system
type and version you are running. Please select your system type by
entering the number next to it from the list below
$dashes
EOF
		for($i=0; $i<@names; $i++) {
			printf " %2d) %-20.20s ", $i+1, $names[$i];
			print "\n" if ($i%3 == 2);
			}
		print "\n" if ($i%3);
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
		$name = $names[$osnum-1];
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
		$ver = [ $name, $vnum,
			  $names_to_real{$name}, $vnum ];
		}
	}

# Write the name, version and real name and version to a file
open(OUT, ">$out");
print OUT "os_type='",$ver->[2],"'\n";
print OUT "os_version='",$ver->[3],"'\n";
print OUT "real_os_type='",$ver->[0],"'\n";
print OUT "real_os_version='",$ver->[1],"'\n";
close(OUT);

# has_command(command)
# Returns the full path if some command is in the path, undef if not
sub has_command
{
local($d);
if (!$_[0]) { return undef; }
local $rv = undef;
if ($_[0] =~ /^\//) {
	$rv = (-x $_[0]) ? $_[0] : undef;
	}
else {
	foreach $d (split(/:/ , $ENV{PATH})) {
		if (-x "$d/$_[0]") { $rv = "$d/$_[0]"; last; }
		}
	}
return $rv;
}


