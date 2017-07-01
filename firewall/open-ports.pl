#!/usr/bin/perl
# Open some ports on the firewall. Exit statuses are :
# 0 - Nothing needed to be done
# 1 - Given ports were opened up
# 2 - IPtables is not installed or supported
# 3 - No firewall is active
# 4 - Could not apply configuration
# 5 - Bad args

$no_acl_check++;
$ENV{'WEBMIN_CONFIG'} = "/etc/webmin";
$ENV{'WEBMIN_VAR'} = "/var/webmin";
if ($0 =~ /^(.*\/)[^\/]+$/) {
	chdir($1);
	}
require './firewall-lib.pl';
if ($module_name ne 'firewall') {
	print STDERR "Command must be run with full path\n";
	exit(5);
	}

# Parse args
if ($ARGV[0] eq "--no-apply") {
	$no_apply = 1;
	shift(@ARGV);
	}
if (!@ARGV) {
	print STDERR "Missing ports to open\n";
	exit(5);
	}
foreach $p (@ARGV) {
	if ($p !~ /^\d+$/ && $p !~ /^\d+:\d+$/ && $p !~ /^\d+(,\d+)*$/) {
		print STDERR "Port $p must be number or start:end range\n";
		exit(5);
		}
	}

# Check IPtables support
if (&foreign_installed($module_name, 1) != 2) {
	print STDERR "IPtables is not available\n";
	exit(2);
	}

# Check if any rules exist
@tables = &get_iptables_save();
if (!@tables) {
	print STDERR "No IPtables rules exist yet\n";
	exit(3);
	}
($filter) = grep { $_->{'name'} eq 'filter' } @tables;
if (!$filter) {
	print STDERR "No IPtables filter table found\n";
	exit(3);
	}
elsif (!@{$filter->{'rules'}}) {
	print STDERR "No IPtables rules found in filter table\n";
	exit(3);
	}

# Check if any rules are active
@livetables = &get_iptables_save("iptables-save 2>/dev/null |");
($livefilter) = grep { $_->{'name'} eq 'filter' } @livetables;

@added = ( );
PORT: foreach $p (@ARGV) {
	# For each port, find existing rules
	print STDERR "Checking for port $p ..\n";
	foreach $r (@{$filter->{'rules'}}) {
		if ($r->{'chain'} eq 'INPUT' &&
		    $r->{'j'} && $r->{'j'}->[1] eq 'ACCEPT' &&
		    $r->{'p'} && $r->{'p'}->[0] eq '' &&
		    		 $r->{'p'}->[1] eq 'tcp') {
			# Found tcp rule .. check ports
			@rports = ( );
			$rrange = undef;
			if ($r->{'dports'} && $r->{'dports'}->[0] eq '') {
				push(@rports, split(/,/, $r->{'dports'}->[1]));
				$rrange = $r->{'dports'}->[1];
				}
			if ($r->{'dport'} && $r->{'dport'}->[0] eq '') {
				($s, $e) = split(":", $r->{'dport'}->[1]);
				if ($s && $e) {
					push(@rports, ($s .. $e));
					}
				elsif ($s) {
					push(@rports, $s);
					}
				$rrange = $r->{'dport'}->[1];
				}
			if (&indexof($p, @rports) >= 0 ||
			    $p eq $rrange) {
				print STDERR ".. already allowed\n";
				next PORT;
				}
			}
		}

	# Add a rule at the top for this port
	$r = { 'chain' => 'INPUT',
	       'm' => [ [ "", "tcp" ] ],
	       'p' => [ "", "tcp" ],
	       'j' => [ "", 'ACCEPT' ] };
	if ($p =~ /,/) {
		$r->{'dports'} = [ "", $p ];
		push(@{$r->{'m'}}, [ "", "multiport" ]);
		}
	else {
		$r->{'dport'} = [ "", $p ];
		}
	unshift(@{$filter->{'rules'}}, $r);
	push(@added, $p);
	}

if (@added) {
	# Added some rules .. save them
	&run_before_command();
	&lock_file($iptables_save_file);
	&save_table($filter);
	&unlock_file($iptables_save_file);
	&run_after_command();
	&copy_to_cluster();
	print STDERR "Opened ports ",join(" ", @added),"\n";

	# Apply, if live
	$ex = 1;
	if (!$no_apply && $livefilter && @{$livefilter->{'rules'}}) {
		$err = &apply_configuration();
		if ($err) {
			print "Failed to apply configuration : $err\n";
			$ex = 4;
			}
		else {
			print "Applied configuration successfully\n";
			}
		}
	&webmin_log("openports", undef, undef, { 'ports' => \@added });
	exit($ex);
	}
else {
	print STDERR "All ports are already open\n";
	exit(0);
	}
