#!/usr/local/bin/perl
#
# modified to customize for this webmin module of MON-dt 09th sept 2001
# monshow - concise, user view-based opstatus summary
#
# Jim Trocki, trockij@transmeta.com
#
# $Id: monshow 1.1 Sat, 26 Aug 2000 12:22:34 -0700 trockij $
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
require './mon-lib.pl';
&init_config();
&ui_print_header(undef, $text{'mon_status_title'}, "","monshow");
print "<hr>\n";

use strict "vars";
use Getopt::Long;
use English;
use CGI;
use Text::Wrap;
use Mon::Client;
use Data::Dumper;

#
# forward declarations
#
sub usage;
sub get_auth;
sub read_cf;
sub err_die;
sub expand_watch;
sub secs_to_hms;
sub display_allok;
sub compose_detail;
sub compose_header;
sub compose_disabled;
sub compose_table;
sub compose_trailer;
sub get_client_status;
sub opstatus_color;
sub tdiff_string;

#
# set this to the path of your view configuration files
#
my $VIEWPATH = "/etc/mon/monshow";
#my $VIEWPATH = "/home/trockij/monshow";

my %OPSTAT = %Mon::Client::OPSTAT;
my $WORD = '[a-zA-Z0-9_-]+';
my $OUT_BUF = "";
my $e;
$= = 1000;
$SIG{INT} = \&handle_sig;
$SIG{TERM} = \&handle_sig;

my ($DEP, $GROUP, $SERVICE, $STATUS, $TIME, $NEXT, $ALERTS, $SUMMARY, $DESC);

my %opt;
GetOptions (\%opt, "showall", "auth", "help", "full", "disabled",
	"rcfile=s", "login=s", "server=s", "port=i", "prot=s",
	"detail=s", "view=s");

my $CGI;
my %QUERY_ARGS;
if (defined $ENV{"REQUEST_METHOD"})
{
    $CGI = new CGI;
}

if (!$CGI && $opt{"help"})
{
    usage;
    exit 1;
}

if ($CGI)
{
    foreach my $e (split (/\?/, $ENV{"QUERY_STRING"}))
    {
	next if ($e !~ /=/);

    	my ($var, $val) = split (/=/, $e);

	$QUERY_ARGS{$var} = $val;
    }
}

my $CF = {
    "full"		=> 0,
    "show-disabled"	=> 0,
    "bg"		=> "d5d5d5",
    "bg-ok"		=> "a0d0a0",
    "bg-fail"		=> "FF66FF",
    "bg-disabled"	=> "FAEBD7",
    "bg-untested"	=> "e0e0e0",
    "table-color"	=> "cccccc",
};

my $GLOBAL = {
    "view-name"		=> undef,
};

#
# read config file
#
my ($e, $what) = read_cf ($CF);

if ($e ne "")
{
    err_die ("while reading config file, $e");
}

#
# cmdline args override config file
#
if (!$CGI)
{
    $CF->{"all"}		= 1 if ($opt{"showall"});
    $CF->{"full"}		= 1 if ($opt{"full"});
    $CF->{"detail"}		= $opt{"detail"} if ($opt{"detail"} ne "");
    $CF->{"host"}		= $opt{"server"} if ($opt{"server"});
    $CF->{"port"}		= $opt{"port"} if ($opt{"port"});
    $CF->{"prot"}		= $opt{"prot"} if ($opt{"prot"});
}

#
# retrieve client status
#
my ($e, $st) = get_client_status ($what);

if ($e ne "")
{
    err_die ($e);
}

expand_watch ($what, $st);

my $rows = select_table ($what, $st);

compose_header ($st->{"state"});

#
# CGI invocation
#
if ($CGI)
{
    if ($QUERY_ARGS{"disabled"})
    {
	compose_disabled ($st->{"disabled"});
    }

    elsif (!$QUERY_ARGS{"detail"})
    {
	compose_table ($rows, $st);

	compose_disabled ($st->{"disabled"}) if ($CF->{"show-disabled"});
    }

    elsif ($QUERY_ARGS{"detail"})
    {
	compose_detail ($QUERY_ARGS{"detail"}, $st);
    }
}

#
# cmdline invocation
#
else
{
    if ($opt{"disabled"})
    {
	compose_disabled ($st->{"disabled"});
    }

    elsif ($CF->{"detail"} ne "")
    {
	compose_detail ($CF->{"detail"}, $st);
    }

    else
    {
	compose_table ($rows, $st);

	compose_disabled ($st->{"disabled"}) if ($CF->{"show-disabled"});
    }
}

compose_trailer;

if ($CGI)
{
#Content-type: text/html
    print <<EOF;

$OUT_BUF
<br><hr><br>
EOF

&footer("./","MON Index page");
}

else
{
    print "\n";
}

exit;

#-----------------------------------------------------------------------------

format STDOUT_TOP =

  GROUP           SERVICE      STATUS      LAST       NEXT       ALERTS SUMMARY
.


#
# usage
#
sub usage
{
    print <<EOF;

usage: monshow [--auth] [--showall] [--full] [--login user] [--disabled]
               [--server host] [--port num] [--rcfile file]
	       [--detail group,service] [--view name]
    --showall      do not read rcfile and show opstatus of all services
    --full         show disabled, failures, successes, and untested
    --detail g,s   show detail (alert acks, etc.) for group,service
    --view name    display a pre-defined view
    --auth         authenticate to mon server
    --disabled     show disabled
    --prot ver     set protocol version, must match 1.2.3 format
    --login user   use "login" as username while authenticating
    --server host  use "host" as monhost, instead of MONHOST
    --port num     use "num" as port number instead of default
    --rcfile file  use "file" as config file instead of \$HOME/.monshowrc

EOF
}


#
# signal handler
#
sub handle_sig
{
    system "stty echo" unless ($CGI);
    exit;
}


#
# get auth info
#
# returns a list "error", "login", "password"
#
sub get_auth
{
    my ($login, $pass);

    if ($CGI)
    {
    	$login = $CGI->query ("login");
    	$pass  = $CGI->query ("password");
    }

    else
    {
	if ($opt{"login"})
	{
	    $login = $opt{"login"};
	}

	else
	{
	    return "could not determine username"
	    	if (!defined ($login = getpwuid($EUID)));
	}

	if (-t STDIN)
	{
	    system "stty -echo";
	    print "Password: ";
	    chop ($pass = <STDIN>);
	    print "\n";
	    system "stty echo";
	    return "invalid password" if ($pass =~ /^\s*$/);
	}

	else
	{
	    my $cmd;

	    while (defined ($cmd = <>))
	    {
		chomp $cmd;
		if ($cmd =~ /^user=(\S+)$/i)
		{
		    $login = $1;
		}

		elsif ($cmd =~ /^pass=(\S+)$/i)
		{
		    $pass = $1;
		}

		last if (defined ($login) && defined ($pass));
	    }
	}
    }

    return "inadequate authentication information supplied"
	if ($login eq "" || $pass eq "");
    
    return ("", $login, $pass);
}

#
# config file
#
sub read_cf
{
    my $CF = shift;

    my ($group, $service);
    my @RC;
    my $view = 0;

    my $RC = "/webmin-0.87/mon/monshowrc";

    if ($CGI)
    {
	if ($ENV{"PATH_INFO"} =~ /^\/\S+/)
	{
	    my $p=$ENV{"PATH_INFO"};
	    $p =~ s/^[.\/]*//;
	    $p =~ s/\/*$//;
	    $p =~ s/\.\.//g;
	    $RC = "$VIEWPATH/$p";
	    $GLOBAL->{"view-name"} = $p;
	    $view = 1;
	}

	elsif ($QUERY_ARGS{"view"} ne "")
	{
	    $QUERY_ARGS{"view"} =~ s/^[.\/]*//;
	    $QUERY_ARGS{"view"} =~ s/\.\.//g;
	    $GLOBAL->{"view-name"} = $QUERY_ARGS{"view"};
	    $RC = "$VIEWPATH/$QUERY_ARGS{view}";
	    $view = 1;
	}

	elsif (-f ".monshowrc")
	{
	    $RC = ".monshowrc";
	}
    }

    else
    {
	if ($opt{"rcfile"})
	{
	    $RC = $opt{"rcfile"};
	}

	elsif ($opt{"view"} ne "")
	{
	    $RC = "$VIEWPATH/$opt{view}";
	    $GLOBAL->{"view-name"} = $opt{"view"};
	    $view = 1;
	}

	elsif (-f "$ENV{HOME}/.monshowrc")
	{
	    $RC = "$ENV{HOME}/.monshowrc";
	}
    }

    if ($opt{"old"})
    {
	$CF->{"prot"} = "0.37.0";
	$CF->{"port"} = 32777;
    }

    if (-f $RC)
    {
	open (IN, $RC) || return "could not read $RC: $!";

	my $html_header = 0;
	my $link_text = 0;
	my $link_group = "";
	my $link_service = "";

	while (<IN>)
	{
	    next if (/^\s*#/ || /^\s*$/);

	    if ($html_header)
	    {
	    	if (/^END\s*$/)
		{
		    $html_header = 0;
		    next;
		}

		else
		{
		    $CF->{"html-header"} .= $_;
		    next;
		}
	    }

	    elsif ($link_text)
	    {
	    	if (/^END\s*$/)
		{
		    $link_text = 0;
		    next;
		}

		else
		{
		    $CF->{"links"}->{$link_group}->{$link_service}->{"link-text"} .= $_;
		    next;
		}
	    }
	    
	    else
	    {
		chomp;
		s/^\s*//;
		s/\s*$//;
	    }

	    if (/^set \s+ (\S+) \s* (\S+)?/ix)
	    {
		my $cmd = $1;
		my $arg = $2;
		if ($cmd eq "show-disabled") { }
		elsif ($cmd eq "host") { }
		elsif ($cmd eq "prot") { }
		elsif ($cmd eq "port") { }
		elsif ($cmd eq "full") { }
		elsif ($cmd eq "bg") { }
		elsif ($cmd eq "bg-ok") { }
		elsif ($cmd eq "bg-fail") { }
		elsif ($cmd eq "bg-disabled") { }
		elsif ($cmd eq "bg-untested") { }
		elsif ($cmd eq "table-color") { }
		elsif ($cmd eq "html-header") { $html_header = 1; next; }
		elsif ($cmd eq "refresh") { }
		else
		{
		    print STDERR "unknown set, line $.\n";
		    next;
		}

		if ($arg ne "")
		{
		    $CF->{$cmd} = $arg;
		}

		else
		{
		    $CF->{$cmd} = 1;
		}
	    }

	    elsif (/^watch \s+ (\S+)/x)
	    {
	    	push (@RC, [$1]);
	    }

	    elsif (/^service \s+ (\S+) \s+ (\S+)/x)
	    {
	    	push (@RC, [$1, $2]);
	    }

	    elsif (/^link \s+ (\S+) \s+ (\S+) \s+ (.*)\s*/ix)
	    {
	    	$CF->{"links"}->{$1}->{$2}->{"link"} = $3;
	    }

	    elsif (/^link-text \s+ (\S+) \s+ (\S+)/ix)
	    {
		$link_text = 1;
		$link_group = $1;
		$link_service = $2;
	    	next;
	    }

	    else
	    {
		my $lnum = $.;
	    	close (IN);
		err_die ("error in config file, line $.");
	    }
	}
	close (IN);
    }

    elsif (! -f $RC && $view)
    {
    	err_die ("no view found");
    }

    return ("", \@RC);
}


sub secs_to_hms
{
    my ($s) = @_;
    my ($dd, $hh, $mm, $ss);

    $dd = int ($s / 86400);
    $s -= $dd * 86400;

    $hh = int ($s / 3600);
    $s -= $hh * 3600;

    $mm = int ($s / 60);
    $s -= $mm * 60;

    $ss = $s;

    if ($dd == 0)
    {
        sprintf("%02d:%02d", $hh, $mm);
    }

    else
    {
        sprintf("%d days, %02d:%02d", $dd, $hh, $mm);
    }
}


#
# exit displaying error in appropriate output format
#
sub err_die
{
    my $msg = shift;

    if ($CGI)
    {
print <<EOF;
Content-type: text/html

<html>
<head>
<title> Error </title>
</head>
<body>
<h2> Error </h2>
<pre>
$msg
</pre>
</body>
</html>
EOF
    }

    else
    {
print <<EOF;
Error: $msg

EOF
    }

    exit 1;
}


#
# everything is cool
#
sub display_allok
{
    if ($CGI)
    {
    	$OUT_BUF .= <<EOF;
<h2> All systems OK </h2>
<p>

EOF
    }

    else
    {
	print "\nAll systems OK\n";
    }
}


#
# client status
#
# return ("", $state, \%opstatus, \%disabled, \%deps, \%groups, \%descriptions);
#
sub get_client_status {
    my $what = shift;

    my $cl;

    if (!defined ($cl = Mon::Client->new))
    {
	return "could not create client object: $@";
    }

    my ($username, $pass);

    if ($opt{"auth"} && !$CGI)
    {
	my $e;
	($e, $username, $pass) = get_auth;
	if ($e eq "")
	{
	    return "$e";
	}
	$cl->username ($username);
	$cl->password ($pass);
    }

    $cl->host ($CF->{"host"}) if (defined $CF->{"host"});
    $cl->port ($CF->{"port"}) if (defined $CF->{"port"});
    $cl->port ($CF->{"prot"}) if (defined $CF->{"prot"});

    $cl->connect;

    if ($cl->error) {
	return "Could not connect to server: " . $cl->error;
    }

    #
    # authenticate self to the server if necessary
    #
    if ($opt{"auth"} && !defined ($cl->login)) {
	my $e = $cl->error;
	$cl->disconnect;
	return "Could authenticate: $e";
    }

    #
    # get disabled things
    #
    my %disabled = $cl->list_disabled;
    if ($cl->error) {
	my $e = $cl->error;
	$cl->disconnect;
	return "could not get disabled: $e";
    }

    #
    # get state
    #
    my ($running, $t) = $cl->list_state;
    if ($cl->error) {
	my $e = $cl->error;
	$cl->disconnect;
	return "could not get state: $e";
    }

    my $state;
    if ($running) {
	$state = $t;
    }

    else
    {
	$state = "scheduler stopped since " . localtime ($t);
    }

    #
    # group/service list
    #
    my @watch = $cl->list_watch;

    if ($cl->error) {
	my $e = $cl->error;
	$cl->disconnect;
	return "could not get opstatus: $e";
    }

    #
    # get opstatus
    #
    my %opstatus;
    if (@{$what} == 0)
    {
	%opstatus = $cl->list_opstatus;
	if ($cl->error) {
	    my $e = $cl->error;
	    $cl->disconnect;
	    return "could not get opstatus: $e";
	}
    }

    else
    {
    	my @list;
	foreach my $r (@{$what})
	{
	    if (@{$r} == 2)
	    {
	    	push @list, $r;
	    }

	    else
	    {
	    	foreach my $w (@watch)
		{
		    next if ($r->[0] ne $w->[0]);
		    push @list, $w;
		}
	    }
	}

	%opstatus = $cl->list_opstatus (@list);
	if ($cl->error) {
	    my $e = $cl->error;
	    $cl->disconnect;
	    return "could not get opstatus: $e";
	}
    }

    #
    # dependencies
    #
    my %deps;
    if ($opt{"deps"}) {
	%deps = $cl->list_deps;
	if ($cl->error) {
	    my $e = $cl->error;
	    $cl->disconnect;
	    return "could not list deps: $e";
	}
    }

    #
    # descriptions
    #
    my %desc;
    %desc = $cl->list_descriptions;
    if ($cl->error) {
	my $e = $cl->error;
	$cl->disconnect;
	return "could not list descriptions: $e";
    }

    #
    # groups
    #
    my %groups;

    if ($QUERY_ARGS{"detail"} || $CF->{"detail"} ne "")
    {
    	foreach my $g (keys %opstatus)
	{
	    my @g = $cl->list_group ($g);
	    if ($cl->error)
	    {
	    	my $e = $cl->error;
		$cl->disconnect;
		return "could not list group: $e";
	    }

	    $groups{$g} = [@g];
	}
    }

    #
    # log out
    #
    if (!defined $cl->disconnect) {
	return "error while disconnecting: " . $cl->error;
    }


    return ("", {
	"state"		=> $state,
	"opstatus"	=> \%opstatus,
	"disabled"	=> \%disabled,
	"deps"		=> \%deps,
	"groups"	=> \%groups,
	"desc"		=> \%desc,
	"watch"		=> \@watch,
	});
}


sub compose_header {
    my $state = shift;

    my $t = localtime;

    #
    # HTML stuff
    #
    if ($CGI)
    {
	$OUT_BUF = <<EOF;
<html>
<head>
<title> Operational Status </title>
EOF

	if ($CF->{"refresh"})
	{
	    $OUT_BUF .= <<EOF;
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Refresh" CONTENT=$CF->{refresh}>
EOF
	}

	$OUT_BUF .= "</head>\n";

	if ($CF->{"html-header"} ne "")
	{
	    $OUT_BUF .= $CF->{"html-header"};
	}

	$OUT_BUF .= <<EOF;
<body bgcolor="$CF->{'bg'}">

<table width="100%" border>
    <tr bgcolor=$CF->{'table-color'}>
	<td>
	    <table>
		<tr>
		    <td align=right><b>Server:</b></td>
		    <td> $CF->{host} </td>
		</tr>
		<tr>
		    <td align=right><b>Time:</b></td>
		    <td> $t </td>
		</tr>
		<tr>
		    <td align=right><b>State:</b></td>
		    <td> $state </td>
		</tr>
EOF

	if ($GLOBAL->{"view-name"} ne "")
	{
	    $OUT_BUF .= <<EOF;
		<tr>
		    <td align=right><b>View:</b></td>
		    <td><b>$GLOBAL->{"view-name"}</b></td>
		</tr>
EOF
	}

	$OUT_BUF .= <<EOF;
	    </table>
	</td>

	<td>
	    <table cellpadding=2 cellspacing=3>
		<tr>
		    <td><FONT FACE="sans-serif" size=+1><b>Color legend</b></FONT></td>
		</tr>
		<tr>
		    <td bgcolor="$CF->{'bg-ok'}"> all is OK </td>
		    <td bgcolor="$CF->{'bg-fail'}"> failure </td>
		    <td bgcolor="$CF->{'bg-untested'}"> untested </td>
		    <td bgcolor="$CF->{'bg-disabled'}"> disabled </td>
		</tr>
	    </table>
	</td>
    </tr>
</table>
<p>
<br>
EOF
    }

    else
    {
    	print <<EOF;

     server: $CF->{host}
       time: $t
      state: $state
EOF
    }
}


sub select_table {
    my ($what, $st) = @_;

    my @rows;

    #
    # display everything real nice
    #
    if ($CF->{"all"} || @{$what} == 0)
    {
	foreach my $group (keys %{$st->{"opstatus"}})
	{
	    foreach my $service (keys %{$st->{"opstatus"}->{$group}})
	    {
		push (@rows, [$group, $service]);
	    }
	}
    }

    else
    {
	@rows = @{$what};
    }

    my (%DEP, %DEPROOT);

    foreach my $l (@rows)
    {
	my ($group, $service) = @{$l};

	my $sref = \%{$st->{"opstatus"}->{$group}->{$service}};

	next if (!defined $sref->{"opstatus"});

	#
	# disabled things
	#
	# fuckin' Perl, man. Just be referencing
	# $st->{"disabled"}->{"watches"}->{$group}, perl automagically
	# defines that hash element for you. Great.
	#
	if (defined ($st->{"disabled"}->{"watches"}) &&
	    defined ($st->{"disabled"}->{"watches"}->{$group}))
	{
	    next;
	}

	elsif (defined ($st->{"disabled"}->{"services"}) &&
	       defined ($st->{"disabled"}->{"services"}->{$group}) &&
	       defined ($st->{"disabled"}->{"services"}->{$service}))
	{
	    next;
	}

	#
	# potential root dependencies
	#
	elsif ($sref->{"depend"} eq "")
	{
	    push (@{$DEPROOT{$sref->{"opstatus"}}}, ["R", $group, $service]);
	}

	#
	# things which have dependencies
	#
	else
	{
	    push (@{$DEP{$sref->{"opstatus"}}}, ["D", $group, $service]);
	}
    }

    if ($CF->{"full"})
    {
	[
	    @{$DEPROOT{$OPSTAT{"fail"}}},
	    @{$DEPROOT{$OPSTAT{"linkdown"}}},
	    @{$DEPROOT{$OPSTAT{"timeout"}}},
	    @{$DEPROOT{$OPSTAT{"coldstart"}}},
	    @{$DEPROOT{$OPSTAT{"warmstart"}}},
	    @{$DEPROOT{$OPSTAT{"untested"}}},
	    @{$DEPROOT{$OPSTAT{"unknown"}}},

	    @{$DEP{$OPSTAT{"fail"}}},
	    @{$DEP{$OPSTAT{"linkdown"}}},
	    @{$DEP{$OPSTAT{"timeout"}}},
	    @{$DEP{$OPSTAT{"coldstart"}}},
	    @{$DEP{$OPSTAT{"warmstart"}}},

	    @{$DEPROOT{$OPSTAT{"ok"}}},
	    @{$DEP{$OPSTAT{"ok"}}},
	    @{$DEP{$OPSTAT{"untested"}}},
	    @{$DEP{$OPSTAT{"unknown"}}},
	];
    }

    else
    {
	[
	    @{$DEPROOT{$OPSTAT{"fail"}}},
	    @{$DEPROOT{$OPSTAT{"linkdown"}}},
	    @{$DEPROOT{$OPSTAT{"timeout"}}},
	    @{$DEPROOT{$OPSTAT{"coldstart"}}},
	    @{$DEPROOT{$OPSTAT{"warmstart"}}},

	    @{$DEP{$OPSTAT{"fail"}}},
	    @{$DEP{$OPSTAT{"linkdown"}}},
	    @{$DEP{$OPSTAT{"timeout"}}},
	    @{$DEP{$OPSTAT{"coldstart"}}},
	    @{$DEP{$OPSTAT{"warmstart"}}},
	];
    }
}


#
# build the table
#
sub compose_table {
    my ($rows, $st) = @_;

    if (@{$rows} == 0)
    {
	display_allok;
	return;
    }

    #
    # display the failure table
    #
    if ($CGI)
    {
	$OUT_BUF .= <<EOF;
	<h2><center>Full View </h2>(To Disable / View Details, Click on the link under Service column)</center>
<table border cellpadding=2 cellspacing=1 bgcolor="#$CF->{'table-color'}" width="100%">
    <th><FONT FACE="sans-serif" size=+1>Depends</FONT>
    <th><FONT FACE="sans-serif" size=+1>Group</FONT>
    <th><FONT FACE="sans-serif" size=+1>Service</FONT>
    <th><FONT FACE="sans-serif" size=+1>Desc.</FONT>
    <th><FONT FACE="sans-serif" size=+1>Last check</FONT>
    <th><FONT FACE="sans-serif" size=+1>Next check</FONT>
    <th><FONT FACE="sans-serif" size=+1>Alerts</FONT>
    <th><FONT FACE="sans-serif" size=+1>Status</FONT>
    <th><FONT FACE="sans-serif" size=+1>Summary</FONT>

EOF
    }

    foreach my $l (@{$rows})
    {
	my ($depstate, $group, $service) = @{$l};

	my $sref = \%{$st->{"opstatus"}->{$group}->{$service}};

	$STATUS = "unknown";
	$TIME = "";
	$DEP = $depstate;
	my $last = "";
	my $bgcolor = opstatus_color ($sref->{"opstatus"});

	if ($sref->{"opstatus"} == $OPSTAT{"untested"})
	{
	    $STATUS = "untested";
	    $TIME = "untested";
	}

	elsif ($sref->{"opstatus"} == $OPSTAT{"ok"})
	{
	    $STATUS = "-";
	}

	elsif ($sref->{"opstatus"} == $OPSTAT{"fail"})
	{
	    if ($sref->{"ack"})
	    {
		if ($CGI) {
	    	$STATUS = "<a href=\"$ENV{SCRIPT_NAME}?detail=$group,$service\">" .
			  "<b>ACK FAIL</b></a>";
		} else {
		    $STATUS = "ACK FAIL";
		}
	    }

	    else
	    {
		$STATUS = "FAIL";
	    }
	}

	if ($depstate eq "")
	{
	    $DEP = "-";
	}

	$GROUP = $group;
	$SERVICE = $service;
	$DESC = $st->{"desc"}->{$group}->{$service}."&nbsp;";


	if ($TIME eq "")
	{
	    $TIME = tdiff_string (time - $sref->{"last_check"}) . " ago";
	}

	if ($sref->{"timer"} < 60)
	{
	    $NEXT = "$sref->{timer} secs";
	}

	else
	{
	    $NEXT = secs_to_hms ($sref->{"timer"});
	}

	$SUMMARY = $sref->{"last_summary"};

	$ALERTS = $sref->{"alerts_sent"} || "none";

	my $fmt;
	if (!$CGI)
	{
	    $fmt = <<EOF;
format STDOUT =
@ @<<<<<<<<<<<<<< @<<<<<<<<<<< @<<<<<<<<<  @<<<<<<<   @<<<<<<<<< @<<<   @
EOF
	    chomp $fmt;
	    $fmt .= "<" x length($SUMMARY) . "\n";
	    $fmt .= <<'EOF';
$DEP, $GROUP, $SERVICE, $STATUS, $TIME, $NEXT, $ALERTS, $SUMMARY
.
EOF
	    eval $fmt;
	    write;
	}

	else
	{
	    if ($SUMMARY =~ /^\s*$/)
	    {
		$SUMMARY = "<pre> </pre>";
	    }
	    if ($bgcolor ne "")
	    {
	    	$bgcolor = "bgcolor='#$bgcolor'";
	    }
	    $OUT_BUF .= <<EOF;

<tr $bgcolor>
   <td> $DEP
   <td> $GROUP
   <td> <a href="$ENV{SCRIPT_NAME}?detail=$group,$service">$SERVICE</a>
   <td> $DESC
   <td> $TIME
   <td> $NEXT
   <td> $ALERTS
   <td> $STATUS
   <td> $SUMMARY
EOF

	}
    }

    if ($CGI)
    {
	$OUT_BUF .= <<EOF;
</table><br><br>
<center><font color=red size=+1><b>Disabled Hosts/Watch/Services</b></font></center>
EOF
    }
}


sub compose_disabled {
    my $disabled = shift;

    if (!keys %{$disabled->{"watches"}} &&
    	!keys %{$disabled->{"services"}} &&
	!keys %{$disabled->{"hosts"}})
    {
    	if ($CGI)
	{
	    $OUT_BUF .= <<EOF;
<br>
<center><table width=50% border>
<tr align=center bgcolor="$CF->{'bg-ok'}">
<td>Nothing is disabled</td></tr></table></center>
<p>
EOF
	}

	else
	{
	    print "\nNothing is disabled.\n";
	}

	return;
    }

    if (keys %{$disabled->{"watches"}})
    {
	if ($CGI)
	{
	    $OUT_BUF .= <<EOF;
<br>
<center><table width=100% border>
<tr align=center bgcolor="$CF->{'table-color'}">
<td width=50%><b>Disabled Watches</b></td><td>Click Link to Enable Desired Watch</td></tr>
EOF
	}

	else
	{
	    print "\nDISABLED WATCHES:\n";
	}

	foreach my $watch (keys %{$disabled->{"watches"}})
	{
	    if ($CGI)
	    {
	    	$OUT_BUF .= "<tr bgcolor=$CF->{'bg-disabled'}><td>$watch</td><td><a href='moncmd.cgi?enable=watch&watch=$watch'>Enable Watch</a></td></tr>\n";
	    }

	    else
	    {
		print "$watch\n";
	    }
	}
	if ($CGI)
        {
               $OUT_BUF .= "</table></center>\n";
        }
    }

    my @disabled_services;
    foreach my $watch (keys %{$disabled->{"services"}})
    {
	foreach my $service (keys %{$disabled->{"services"}{$watch}})
	{
	    push (@disabled_services, "$watch $service");;
	}
    }

    if (@disabled_services)
    {
	if ($CGI)
	{
	    $OUT_BUF .= <<EOF;
<br>
<center><table width=100% border>
<tr align=center bgcolor="$CF->{'table-color'}">
<td width=50%><b>Disabled Services (Hostgroup -> Service) </b></td><td>Click Link to Enable Desired Service</td></tr>
EOF
	}

	else
	{
	    print "\nDISABLED SERVICES\n";
	}
	for (@disabled_services)
	{
	    if ($CGI)
	    {
		my $aaa=$_;
		$aaa=~s/\s+/ -> /;
	    	$OUT_BUF .= "<tr bgcolor=$CF->{'bg-disabled'}><td>$aaa</td><td><a href='moncmd.cgi?enable=service&service=$_'>Enable Service</a></td></tr>\n";
	    }

	    else
	    {
		print "$_\n";
	    }
	}
        if ($CGI)
        {
           $OUT_BUF .= "</table></center>\n";
        }
    }

    if (keys %{$disabled->{"hosts"}})
    {
	if ($CGI)
	{
	    $OUT_BUF .= <<EOF;
<br>
<center><table width=100% border>
<tr align=center bgcolor="$CF->{'table-color'}">
<td width=50%><b>Disabled Hosts (Hostgroup -> Host)</b><td>Click Link to Enable Desired Host</td></td></tr>
EOF
	}

	else
	{
	    print "\nDISABLED HOSTS:\n";
	}
	foreach my $group (keys %{$disabled->{"hosts"}})
	{
	    my @HOSTS = ();
	    foreach my $host (keys %{$disabled->{"hosts"}{$group}})
	    {
		push (@HOSTS, $host);
	    }
	    if ($CGI)
	    {
		foreach my $sdd(@HOSTS){
			$OUT_BUF .= sprintf ("<tr bgcolor=$CF->{'bg-disabled'}><td>%-15s -> %s </td><td><a href='moncmd.cgi?enable=host&host=$sdd'>Enable Host</a></td></tr>\n", $group, $sdd);
		}
	    }

	    else
	    {
		printf ("%-15s %s\n", $group, "@HOSTS");
	    }
	}
        if ($CGI)
        {
           $OUT_BUF .= "</table></center>\n";
        }
    }
}


sub compose_trailer {
    if ($CGI)
    {
    	$OUT_BUF .= <<EOF;
</body>
</html>
EOF
    }
}


sub compose_detail {
    my ($args, $st) = @_;

    my ($group, $service) = split (/,/, $args, 2);

    if (!defined ($st->{"opstatus"}->{$group}->{$service}))
    {
    	err_die ("$group/$service not a valid service");
    }

    my $sref = \%{$st->{"opstatus"}->{$group}->{$service}};

    my $d;

    my $bgcolor = opstatus_color ($sref->{"opstatus"});

    $bgcolor = "bgcolor='#$bgcolor'" if ($bgcolor ne "");

    foreach my $k (keys %OPSTAT)
    {
        if ($OPSTAT{$k} == $sref->{"opstatus"})
        {
            $sref->{"opstatus"} = "$k ($sref->{opstatus})";
            last; 
        }
    }

    foreach my $k (qw (opstatus exitval last_check timer ack ackcomment))
    {
    	if ($CGI && $sref->{$k} =~ /^\s*$/)
	{
	    $d->{$k} = "<pre> </pre>";
	}

	else
	{
	    $d->{$k} = $sref->{$k};
	}
    }

    my $t = time;

    $d->{"last_check"} = tdiff_string ($t - $d->{"last_check"}) . " ago";
    $d->{"timer"} = "in " . tdiff_string ($d->{"timer"});

    foreach my $k (qw (last_success last_failure first_failure last_alert))
    {
	if ($sref->{$k})
	{
	    $d->{$k} = localtime ($sref->{$k});
	}
    }

    if ($sref->{"first_failure"})
    {
    	$d->{"failure_duration"} = secs_to_hms ($sref->{"failure_duration"});
    }


    #
    # HTML output
    #
    if ($CGI)
    {
    $OUT_BUF .= <<EOF;

<h1><center><FONT FACE="sans-serif">Detail for $group/$service</font></h1>(Click the link to Disable Watch/Service/Hosts )</center>

<table width="100%" border>
    <tr $bgcolor>
    	<td align=right width="15%"> <b> Description: </b> <td> $st->{desc}->{$group}->{$service}&nbsp;<td bgcolor="#FFFF00"><a href='moncmd.cgi?disable=service&service=$group $service'>Disable Service</a> 
    <tr $bgcolor>
	<td align=right width="15%"> <b> Summary: </b> <td> $sref->{last_summary}&nbsp;<td bgcolor="#FFFF00">&nbsp;
    <tr $bgcolor>
	<td align=right width="15%"> <b> Hosts: </b> <td> @{$st->{groups}->{$group}}&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(Note: * indicates disabled host)<td bgcolor="#FFFF00">
EOF
	foreach $_(@{$st->{groups}->{$group}}){
		$OUT_BUF .= sprintf ("%s <a href='moncmd.cgi?disable=host&host=$_'>Disable Host: $_</a><br>");
	}
$OUT_BUF .= <<EOF;    
<tr $bgcolor>
	<td valign=top align=right width="15%"> <b> Detail: </b>&nbsp;
	<td>
	<pre>
$sref->{last_detail}
	</pre><td bgcolor="#FFFF00"><a href='moncmd.cgi?disable=watch&watch=$group'>Disable Watch</a>
</table>
EOF

	if ($d->{"ack"}){
	    $OUT_BUF .= <<EOF;
<table width="100%" border>
    <tr>
    	<td align=right width="15%"> <h2>Acknowledgment of failure</h2> </td>
    <tr>
	<td align=right width="15%"> $d->{ackcomment}
</table>

EOF
	}

	$OUT_BUF .= <<EOF;
<table cellpadding=2 cellspacing=1 bgcolor="#CCCCCC" width="100%" border>
EOF

	#
	# 0 = nothing special
	# 1 = do not display if zero
	# 2 = do not display if eq ""
	#
	foreach my $k (
		["opstatus", "Operational Status", 0],
		["exitval", "Exit Value", 0],
		["depend", "Dependency", 2],
		["monitor", "Monitor Program", 2],
		["last_check", "Last Check", 2],
		["next_check", "Next Check", 2],
		["last_success", "Last Success", 2],
		["last_failure", "Last Failure", 2],
		["first_failure", "First Failure", 2],
		["failure_duration", "Failure Duration", 2],
		["interval", "Schedule Interval", 0],
		["exclude_period", "Exclude Period", 2],
		["exclude_hosts", "Exclude Hosts", 2],
		["randskew", "Random Skew", 1],
		["alerts_sent", "Alerts Sent", 1],
		["last_alert", "Last Alert", 2])
	{
	    my $v = undef;

	    if ($d->{$k->[0]} ne "") {
	    	$v = \$d->{$k->[0]};

	    } elsif ($sref->{$k->[0]} ne "") {
	    	$v = \$sref->{$k->[0]};
	    }

	    next if ($k->[2] == 1 && $$v == 0);
	    next if ($k->[2] == 2 && $$v eq "");

	    $OUT_BUF .= <<EOF;
    <tr>
    	<td align=right width="15%"><b>$k->[1]:</b></td>
	<td> $$v </td>
EOF
	}

	$OUT_BUF .= <<EOF;
</table>

EOF

	#
	# custom links
	#
	if (defined ($CF->{"links"}->{$group}->{$service}))
	{
	    if (defined ($CF->{"links"}->{$group}->{$service}->{"link-text"}))
	    {
	    	$OUT_BUF .= <<EOF;
<p>
<h2><a href=\"$CF->{links}->{$group}->{$service}->{link}\">More Information</a></h2>
$CF->{links}->{$group}->{$service}->{'link-text'}

EOF
	    }

	    else
	    {
	    	$OUT_BUF .= <<EOF;
<p>
<a href="$CF->{links}->{$group}->{$service}->{link}">$CF->{links}->{$group}->{$service}->{link}</a>

EOF
	    }
	}

    	$OUT_BUF .= <<EOF;
<p>
<hr><a href="$ENV{SCRIPT_NAME}">Back to summary table</a>
<p>

EOF
    }

    #
    # text output
    #
    else
    {
	my $n;
	$Text::Wrap::columns = 70;
	$n->{"desc"}         = wrap ("    ", "    ", $st->{"desc"}->{$group}->{$service});
	$n->{"last_summary"} = wrap ("    ", "    ", $sref->{"last_summary"});
	$n->{"hosts"}        = wrap ("    ", "    ", join (" ", @{$st->{groups}->{$group}}));

    	print <<EOF;

Detail for group $group service $service

description
-----------
$n->{desc}
summary
-------
$n->{last_summary}
hosts
-----
$n->{hosts}

-----DETAIL-----
$sref->{last_detail}
-----DETAIL-----

EOF
    	if ($d->{"ack"})
	{
	    print <<EOF;
alert ack:  $d->{ackcomment}

EOF
	}

	print <<EOF;
  opstatus: $d->{opstatus}
   exitval: $d->{exitval}
    depend: $d->{depend}
   monitor: $d->{monitor}
last check: $d->{last_check}
next_check: $d->{timer}

EOF
    }
}


sub opstatus_color {
    my $o = shift;

    my %color_hash = (
    	$OPSTAT{"untested"}	=> $CF->{"bg-untested"},
	$OPSTAT{"ok"}		=> $CF->{"bg-ok"},
	$OPSTAT{"fail"}		=> $CF->{"bg-fail"},
    );

    $color_hash{$o} || "";
}


sub tdiff_string {
    my $time = shift;

    my $s;

    if ($time <= 90)
    {
    	$s = "$time secs";
    }

    else
    {
    	$s = secs_to_hms ($time);
    }
}


#
# for each watch entry which specifies only "group",
# expand it into "group service"
#
sub expand_watch {
    my $what = shift;
    my $st = shift;

    for (my $i=0; $i<@{$what}; $i++)
    {
    	if (@{$what->[$i]} == 1)
	{
	    my @list;
	    foreach my $l (@{$st->{"watch"}})
	    {
	    	if ($l->[0] eq $what->[$i]->[0])
		{
		    push @list, $l;
		}
	    }
	    splice (@{$what}, $i, 1, @list);
	}
    }
}

