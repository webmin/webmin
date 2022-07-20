#!/usr/local/bin/perl
# Automatically discover new servers

$no_acl_check++;
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%config, %text, @cluster_modules);
&foreign_require("mailboxes", "mailboxes-lib.pl");
&foreign_require("net", "net-lib.pl");

my $debug;
if ($ARGV[0] eq "--debug" || $ARGV[0] eq "-debug") {
	$debug = 1;
	}

my $nets;
if (!$config{'auto_net'}) {
	$nets = &get_my_address();
	}
elsif (&check_ipaddress($config{'auto_net'})) {
	$nets = $config{'auto_net'};
	}
else {
	my ($iface) = grep { $_->{'fullname'} eq $config{'auto_net'} }
			   &net::active_interfaces();
	$iface && $iface->{'address'} || die $text{'find_eiface'};
	$nets = $iface->{'address'};
	}
my @broad;
foreach my $net (split(/\s+/, $nets)) {
	$net =~ s/\.\d+$/\.0/;
	$net =~ /^(\d+\.\d+\.\d+)\.0$/ || die $text{'find_escan'};
	for(my $i=0; $i<256; $i++) {
		push(@broad, "$1.$i");
		}
	}
my $limit = $config{'scan_time'};
my @cluster = grep { $config{'auto_'.$_} } @cluster_modules;
if ($debug) {
	print "Checking on ",join(" ", @broad),"\n";
	print "User = $config{'auto_user'}\n";
	print "Pass = $config{'auto_pass'}\n";
	}
my ($found, $already, $foundme, $addmods) = 
	&find_servers(\@broad, $config{'scan_time'}, !$debug,
	      $config{'auto_user'},
	      $config{'auto_pass'}, $config{'auto_type'}, \@cluster,
	      $config{'auto_self'});
if ($debug) {
	foreach my $f (@$found) {
		my $added = $addmods->{$f->{'id'}};
		print "On $f->{'host'} added $added->[0]->{'host'} ",
		      ($added->[1] ? "OK" : "FAILED")," ",
		      $added->[2],"\n";
		}
	}

# Send an email for each new system found
my @servers = &list_servers();
if ($config{'auto_email'}) {
	foreach my $f (@$found) {
		&send_auto_email(&text('email_regsubject', $f->{'host'}),
				 &text('email_reg', $f->{'host'}));
		}
	}

# See if there were any systems that are registered and on the same net, but
# were not found 3 times in a row.
if ($config{'auto_remove'}) {
	my @net = split(/\./, $nets);
	foreach my $s (@servers) {
		my $ip = &to_ipaddress($s->{'host'});
		my @ip = split(/\./, $ip);
		if ($ip[0] == $net[0] && $ip[1] == $net[1] &&
		    $ip[2] == $net[2]) {
			# On scanned net, so should have been found
			my ($f) = grep { &to_ipaddress($_->{'host'}) eq $ip }
				(@$found, @$already);
			if (!$f && $s->{'notfound'}++ >= 3) {
				# Not found too many times Delete it ..
				&delete_server($s->{'id'});
				if ($config{'auto_email'}) {
					&send_auto_email(
						&text('email_unregsubject',
						      $f->{'host'}),
						&text('email_unreg',
						      $f->{'host'}));
					}
				}
			else {
				# Found, or only not found once
				if ($f) {
					$s->{'notfound'} = 0;
					}
				&save_server($s);
				}
			}
		}
	}

sub send_auto_email
{
my ($subject, $body) = @_;
&mailboxes::send_text_mail(&mailboxes::get_from_address(),
			   $config{'auto_email'},
			   undef,
			   $subject,
			   $body,
			   $config{'auto_smtp'});
}

