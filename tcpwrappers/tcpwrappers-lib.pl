# tcpwrappers-lib.pl
# Library for TCP Wrappers

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

# list_rules($filename)
# Parse rules from /etc/hosts.*
# File format described in "man 5 hosts_access"
sub list_rules {
    my $file = shift;
    my @ret;
    my $id = 0;

    open(HOSTS, $file) || return ();
    my $line;
    my $last_line = '';
    my $lnum = 0;
    while ($line = <HOSTS>) {
	my ($slnum, $elnum) = ($lnum, $lnum);
	s/\r|\n//g;

	while ($line =~ /^(.*)\\/) {
	    # Continuation line! Read the next one and append it
	    local $before = $1;
	    local $nxt = <HOSTS>;
	    $nxt =~ s/\r|\n//g;
	    $line = $before.$nxt;
	    $elnum++; $lnum++;
        }

	if ($line =~ /^\#(.*)/) {
	    # Comment
	    $cmt = $cmt ? $cmt."\n".$1 : $1;
	} elsif ($line =~ /^\s*$/) {
	    $cmt = undef;
	} else {
	    my @cmtlines = split(/\n/, $cmt);
	    $cmt = undef;
	    my ($service, $host, $cmd) = split /:/, $line, 3;
	    $service =~ s/^\s*//; $service =~ s/\s*$//;
	    $host =~ s/^\s*//; $host =~ s/\s*$//;
	    
	    push @ret, { 'id' => $id++,
			 'service' => $service,
			 'host' => $host,
			 'cmd' => $cmd,
			 'line' => $slnum-scalar(@cmtlines),
			 'eline' => $elnum
			 };
	}
	$lnum++;
    }
    close FILE;

    return @ret;
}

# list_services()
# List system services from (x)inetd or return ()
sub list_services {
    my @ret;

    if (&foreign_installed("xinetd")) {
	&foreign_require("xinetd", "xinetd-lib.pl");
	my @conf = &foreign_call('xinetd', 'get_xinetd_config');
	foreach $x (@conf) {
	    next if ($x->{'quick'}{'server'}[0] !~ /\/([^\/]+)$/);
	    push @ret, $1;
	}
    } elsif (&foreign_installed("inetd")) {
	&foreign_require("inetd", "inetd-lib.pl");
	my @conf = &foreign_call('inetd', 'list_inets');
	foreach $x (@conf) {
	    next unless ($x->[9] =~ /^(\S+)/);
	    push @ret, $1;
	}
    }

    return &unique(@ret);
}

# delete_rule($filename, &rule)
# Removes one rule entry from the file
sub delete_rule {
    my ($filename, $rule) = @_;

    my $lref = &read_file_lines($filename);
    my $len = $rule->{'eline'} - $rule->{'line'} + 1;
    splice(@$lref, $rule->{'line'}, $len);
    &flush_file_lines($filename);
}

# create_rule($filename, &rule)
# Adds new rule
sub create_rule {
    my ($file, $rule) = @_;

    my $lref = &read_file_lines($file);
    my $newline = $rule->{'service'}.' : '.$rule->{'host'}.($rule->{'cmd'} ? ' : '.$rule->{'cmd'} : '');
    push(@$lref, $newline);
    &flush_file_lines($file);
}

# modify_rule($filename, &old_rule, &new_rule)
# Updates rule
sub modify_rule {
    my ($filename, $oldrule, $newrule) = @_;

    my @newline = ($newrule->{'service'}.' : '.$newrule->{'host'}.($newrule->{'cmd'} ? ' : '.$newrule->{'cmd'} : ''));

    my $lref = &read_file_lines($filename);
    my $len = $oldrule->{'eline'} - $oldrule->{'line'} + 1;
    splice(@$lref, $oldrule->{'line'}, $len, @newline);
    &flush_file_lines($filename);
}

1;
