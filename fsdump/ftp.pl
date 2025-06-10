#!/usr/local/bin/perl
# Pass data from stdin to an FTP server

$no_acl_check++;
require './fsdump-lib.pl';

# Parse args, and get password
select(STDERR); $| = 1; select(STDOUT);
$host = $ARGV[0];
$user = $ARGV[2];
if ($ARGV[3] =~ /touch/) {
	$touched = 1;
	}
$| = 1;
if (defined($ENV{'DUMP_PASSWORD'})) {
	$pass = $ENV{'DUMP_PASSWORD'};
	}
else {
	open(TTY, "+</dev/tty");
	print TTY "Password: ";
	$pass = <TTY>;
	$pass =~ s/\r|\n//g;
	close(TTY);
	}

# Read rmt protocol messages
while(1) {
	$line = <STDIN>;
	$line =~ s/\r|\n//g;
	if ($line =~ /^O(.*)/) {
		# File to open specified .. connect to FTP server
		$file = $1;
		$perms = <STDIN>;
		$perms = int($perms);
		&open_socket($host, 21, "SOCK", \$err);
		&error_exit("FTP connection failed : $err") if ($err);
		&ftp_command("", 2, \$err) ||
			&error_exit("FTP prompt failed : $err");

		# Login to server
		@urv = &ftp_command("USER $user", [ 2, 3 ], \$err);
		@urv || &error_exit("FTP login failed : $err");
		if (int($urv[1]/100) == 3) {
			&ftp_command("PASS $pass", 2, \$err) ||
				&error_exit("FTP login failed : $err");
			}
		&ftp_command("TYPE I", 2, \$err) ||
			&error_exit("FTP file type failed : $err");

		# Work out what we are doing
		$mode = 0;
		if (($perms & 0100) || ($perms & 01000) ||
		    (($perms & 01) || ($perms & 02)) && $touched) {
			# Writing new file
			$mode = 1;
			}
		elsif ($perms & 02000) {
			# Appending to a file
			$mode = 2;
			}
		elsif (!$perms) {
			# Reading from file
			$mode = 0;
			}
		else {
			&error_exit("Unknown permissions $perms");
			}
		print "A0\n";
		}
	elsif ($line =~ /^W(\d+)/) {
		# Write to FTP server
		$len = $1;
		if ($opened != 1) {
			&open_ftp_file($mode);
			}
		#$opened || &error_exit("FTP connection not opened yet");
		read(STDIN, $buf, $len);
		$wrote = (print CON $buf);
		print "A".($wrote ? $len : 0)."\n";
		}
	elsif ($line =~ /^R(\d+)/) {
		# Read from to FTP server
		if ($opened != 2) {
			&open_ftp_file(0);
			}
		$len = $1;
		$read = read(CON, $buf, $len);
		if ($read >= 0) {
			print "A".$read."\n";
			print $buf;
			}
		else {
			print "E",int($!),"\n";
			print "Read failed : $!\n";
			}
		}
	elsif ($line =~ /^C/) {
		# Close FTP connection
		if ($opened) {
			# Finish transfer
			close(CON);
			&ftp_command("", 2, \$err) ||
				&error_exit("FTP close failed : $err");
			}
		&ftp_command("QUIT", 2, \$err) ||
			&error_exit("FTP quit failed : $err");
		close(SOCK);
		print "A0\n";
		$opened = 0;
		}
	elsif (!$line) {
		# All done!
		last;
		}
	else {
		print "E1\nUnknown command $line\n";
		}
	}

sub error_exit
{
local $err = &html_tags_to_text(join("", @_));
print STDERR $err,"\n";
print "E1\n$err\n";
exit(1);
}

sub html_tags_to_text
{
local ($rv) = @_;
$rv =~ s/<tt>|<\/tt>//g;
$rv =~ s/<b>|<\/b>//g;
$rv =~ s/<i>|<\/i>//g;
$rv =~ s/<u>|<\/u>//g;
$rv =~ s/<pre>|<\/pre>//g;
$rv =~ s/<br>/\n/g;
$rv =~ s/<p>/\n\n/g;
return $rv;
}

sub open_ftp_file
{
local ($mode) = @_;

# Open passive port
local $pasv = &ftp_command("PASV", 2, \$err);
$pasv || &error_exit("FTP port failed : $err");
$pasv =~ /\(([0-9,]+)\)/;
local @n = split(/,/ , $1);
&open_socket("$n[0].$n[1].$n[2].$n[3]", $n[4]*256 + $n[5],
	     CON, \$err) ||
	&error_exit("FTP port failed : $err");

if ($mode == 0) {
	# Read from file
	&ftp_command("RETR $file", 1, \$err) ||
		&error_exit("FTP read failed : $err");
	$opened = 2;
	}
elsif ($mode == 1) {
	# Create new file if requested by the client, or if
	# the touch command was specified by the caller
	&ftp_command("STOR $file", 1, \$err) ||
		&error_exit("FTP write failed : $err");
	$touched = 0;
	$opened = 1;
	}
elsif ($mode == 2) {
	# Otherwise append to the file
	&ftp_command("APPE $file", 1, \$err) ||
		&error_exit("FTP write failed : $err");
	$opened = 1;
	}
else {
	$opened = 0;
	}
}

