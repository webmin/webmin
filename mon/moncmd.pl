#!/usr/local/bin/perl
#
# moncmd - send a command to the mon server
#
# original file is modified to suit for the operation in this webmin module of msclinux--dt 09 Sept 2001
#
# Jim Trocki, trockij@transmeta.com
#
# $Id: moncmd 1.2 Fri, 12 Jan 2001 08:13:31 -0800 trockij $
#
#    Copyright (C) 1998, Jim Trocki
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
use Getopt::Std;
use Socket;
use English;

getopts ("ahf:l:s:p:rd");

sub usage;
sub do_cmd;

$MONSERVER = $ENV{"MONHOST"}
    if (defined ($ENV{"MONHOST"}));
$MONSERVER = $opt_s if ($opt_s);
$MONPORT   = $opt_p || getservbyname ("mon", "tcp") || 2583;

if ($opt_h) {
    usage;
}

if (!defined ($MONSERVER)) {
    die "No host specified or found in MONHOST\n";
}

$SIG{INT} = \&handle_sig;
$SIG{TERM} = \&handle_sig;

#
# does the input come from stdin or a file?
#
if ($opt_f) {
    if ($opt_f eq "-") {
    	$H = STDIN;
#print LOG "READING H from STDIN<br>";
    } else {
    	open (IN, $opt_f) ||
	    die "could not open input file: $!\n";
	$H = IN;
#print LOG "READING H from IN<br>";
    }

} elsif (!@ARGV) {
    if (-t STDIN) {
      print <<EOF
You did not give a command on the command line nor a -f flag and
the program is running interactively (e.g. reading from terminal).
This is not supported.  Exiting
EOF
    ;
        exit 1;
    }

    $H = STDIN;
}

#
# get auth info
#
if ($opt_a) {
#open (LOG,">/tmp/monlog");
    if ($opt_l) {
    	$USER = $opt_l;
#print LOG "USER READ FROM -l OPTION =$USER\n";
    } else {
	die "could not determine username\n"
	    unless defined ($USER = getpwuid($EUID));
#print LOG "USER DEFAULT TAKEN=$USER\n";
    }

    if (-t STDIN) {
#print LOG "READING PASSWD FROM STDIN\n";
	system "stty -echo";
	print "Password: ";
	chop ($PASS = <STDIN>);
	print "\n";
	system "stty echo";
	die "invalid password\n" if ($PASS =~ /^\s*$/);

    } elsif (!@ARGV) {
	$cmd = <$H>;
#print LOG "READING CMD FROM $H\n";
#print LOG "CMD:$cmd\n";
	while (defined ($cmd) && $cmd =~ /user=|pass=/i) {
	#while (defined ($cmd) && $cmd =~ /user|pass/i) {
	    chomp $cmd;
#print LOG "CMD AFTER CHOMP:$cmd\n";
	    if ($cmd =~ /^user=(\S+)$/i) {
		$USER=$1 if (!defined ($USER));
#print LOG "READING USER FROM $H:$USER\n";
	    } elsif ($cmd =~ /^pass=(\S+)$/i) {
		$PASS=$1;
#print LOG "READING PASSWD FROM $H:$PASS\n";
	    }
	    
	    $cmd = <$H>;
	    $cmd1=$cmd;	
#print LOG "FINAL CMD: $cmd\n";
	}

    }
     
    die "inadequate authentication information supplied\n"
    	if ($USER eq "" || $PASS eq "");
}

#
# set up TCP socket
#
$iaddr = inet_aton ($MONSERVER) ||
	die "Unable to find server '$MONSERVER'\n";

if ($MONPORT =~ /\D/) { $MONPORT = getservbyname ($MONPORT, 'tcp') }
$paddr = pack_sockaddr_in ($MONPORT, $iaddr);
$proto = getprotobyname ('tcp');

socket (MON, PF_INET, SOCK_STREAM, $proto) ||
    die "could not create socket: $!\n";
connect (MON, $paddr) ||
    die "could not connect: $!\n";

select (MON); $| = 1; select (STDOUT);

#if( defined(my $line = <MON>)) {
#    chomp $line;
#    unless( $line =~ /^220\s/) {
#	die "didn't receive expected welcome message\n";
#    }
#} else {
#    die "error communicating with mon server: $!\n";
#}

#
# authenticate self to the server if necessary
#
if ($opt_a) {
    ($l, @out) = do_cmd(MON, "login $USER $PASS");
    die "Could not authenticate\n"
	if ($l =~ /^530/);
}


if ($opt_f or !@ARGV) {
    #$cmd = <$H> if ($opt_f || !@ARGV);
    $cmd = (<$H>||$cmd1) if ($opt_f || !@ARGV);
    $l = "";
#print LOG "ENTERING TO SEND THE CMD:$cmd\n";
    while (defined ($cmd) && defined ($l)) {
	#
	# send the command
	#
	chomp $cmd;
#print LOG "SENDING THE CMD:$cmd\n";
	($l, @out) = do_cmd (MON, $cmd);
	last if (!defined ($l));
	for (@out) {
	    print "$_\n";
	}
	print "$l\n";

	$cmd = <$H>;
    }
    close ($H);

} else {
    ($l, @out) = do_cmd (MON, "@ARGV");
    for (@out) {
	print "$_\n";
    }
    print "$l\n";
}

#
# log out
#
do_cmd (MON, "quit");

close(MON);

#close(LOG);

#
# submit a command to the server, wait for a response
#
sub do_cmd {
    my ($fd, $cmd) = @_;
    my ($l, @out);

    return ("", undef) if ($cmd =~ /^\s*$/);

    @out = ();
    print $fd "$cmd\n";
#print LOG "SUBMITTING CMD:$cmd\n";
    while (defined($l = <$fd>)) {
        chomp $l;
        if ($l =~ /^(\d{3}\s)/) {
            last;
        }
        push (@out, $l);
    }

    ($l, @out);
}


#
# usage
#
sub usage {
    print <<EOF;

usage: moncmd [-a] [-l login] [-s host] [-p port] [-f file] commands

Valid commands are:
    quit
    reset [stopped]
    term
    list group "groupname"
    list disabled
    list alerthist
    list failurehist
    list successes
    list failures
    list opstatus
    list pids
    list watch
    stop
    start
    loadstate
    savestate
    set "group" "service" "variable" "value"
    get "group" "service" "variable"
    disable service "group" "service"
    disable host "host" ["host"...]
    disable watch "watch"
    enable service "group" "service"
    enable host "host" ["host"...]
    enable watch "watch"
EOF
    exit 0;
}


#
# signal handler
#
sub handle_sig {
    system "stty echo";
    exit;
}
