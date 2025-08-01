#!/usr/local/bin/perl
# create_slave.cgi
# Create a new slave zone
# Modified by Howard Wilkinson <howard@cohtech.co.uk> 7th NOvember 2001
#        Added a facility to create a slave zone with the master(s)
#        on a non-standard port
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %in, %config);

require './bind8-lib.pl';
&ReadParse();
&error_setup($in{'type'} ? $text{'screate_err1'} : $text{'screate_err2'});
$access{'slave'} || &error($in{'type'} ? $text{'screate_ecannot1'}
				       : $text{'screate_ecannot2'});
$access{'ro'} && &error($text{'master_ero'});
my $conf = &get_config();
my ($view, $vconf, $viewname);
if ($in{'view'} ne '') {
	$view = $conf->[$in{'view'}];
	&can_edit_view($view) || &error($text{'master_eviewcannot'});
	$vconf = $view->{'members'};
	$viewname = $view->{'values'}->[0];
	}
else {
	$vconf = $conf;
	$viewname = undef;
	}

# validate inputs
if ($in{'rev'}) {
	my $ipv4;
	($ipv4 = &check_net_ip($in{'zone'})) ||
	$config{'support_aaaa'} &&
	($in{'zone'} =~ /^([\w:]+)(\/\d+)$/ || &check_ip6address($1)) ||
                &error(&text('create_enet', $in{'zone'}));
	if ($ipv4) {
		$in{'zone'} = &ip_to_arpa($in{'zone'});
		}
	else {
		$in{'zone'} = &net_to_ip6int($1, ($2 ? substr($2, 1) : "" ));
		}
	}
else {
	($in{'zone'} =~ /^[\d\.]+$/ || $in{'zone'} =~ /^[\d\:]+(\/[\d]+)?$/) &&
		&error(&text('create_edom2', $in{'zone'}));
	&valdnsname($in{'zone'}, 0, ".") ||
		&error(&text('create_edom', $in{'zone'}));
        }
$in{'zone'} =~ s/\.$//;
foreach my $z (&find("zone", $vconf)) {
	if (lc($z->{'value'}) eq lc($in{'zone'})) {
		&error($text{'master_etaken'});
		}
	}
my $masterport = $in{'port_def'} ? undef : $in{'port'};
my $masterkey = $in{'key_def'} ? undef : $in{'key'};
my @masters = split(/\s+/, $in{'masters'});
foreach my $m (@masters) {
	&check_ipaddress($m) || &check_ip6address($m) ||
		&error(&text('create_emaster', $m));
	}
if (!@masters) {
	&error($text{'create_enone'});
	}
my $base = $access{'dir'} ne '/' ? $access{'dir'} :
	$config{'slave_dir'} ? $config{'slave_dir'} :
			       &base_directory($conf);
$base =~ s/\/+$// if ($base ne '/');
if ($base !~ /^([a-z]:)?\//) {
	# Slave dir is relative .. make absolute
	$base = &base_directory()."/".$base;
	}
my $file;
if ($in{'file_def'} == 0) {
	# Use the entered filename
	$in{'file'} =~ /^\S+$/ ||
		&error(&text('create_efile', $in{'file'}));
	if ($in{'file'} !~ /^\//) {
		$file = $base."/".$in{'file'};
		}
	else { $file = $in{'file'}; }
	&allowed_zone_file(\%access, $file) ||
		&error(&text('create_efile2', $file));
	}
elsif ($in{'file_def'} == 2) {
	# Automatically choose a filename
	$file = &automatic_filename($in{'zone'}, $in{'rev'}, $base,
				    $view ? $view->{'value'} : undef);
	}
if ($file) {
	my $ZONE;
	&open_tempfile($ZONE, ">". &make_chroot($file), 1, 1) ||
		&error(&text('create_efile3', $file, $!));
	&close_tempfile($ZONE);
	&set_ownership(&make_chroot($file));
	}

# Create the structure
my @mdirs = map { { 'name' => $_ } } @masters;
my $masters = { 'name' => 'masters',
	     'type' => 1,
	     'members' => \@mdirs };
if (defined($masterport)) {
	$masters->{'values'} = [ 'port', $masterport ];
	}
if ($masterkey) {
	$masters->{'values'} = [ 'key', $masterkey ];
	}
my $dir = { 'name' => 'zone',
	 'values' => [ $in{'zone'} ],
	 'type' => 1,
	 'members' => [ { 'name' => 'type',
			  'values' => [ $in{'type'} ? 'slave'
						    : 'stub' ] },
			$masters
		      ]
	};
if ($file) {
	push(@{$dir->{'members'}},
		{ 'name' => 'file',
		  'values' => [ $file ] });
	}

# Create zone directive
&create_zone($dir, $conf, $in{'view'});
&webmin_log("create", $in{'type'} ? 'slave' : 'stub', $in{'zone'}, \%in);

# Get the new zone's index
my $idx = &get_zone_index($in{'zone'}, $in{'view'});

&add_zone_access($in{'zone'});

# Create on slave servers
if ($in{'onslave'} && $access{'remote'}) {
	my @slaveerrs = &create_on_slaves($in{'zone'}, $masters[0],
			$in{'file_def'} == 1 ? "none" :
			$in{'file_def'} == 2 ? undef : $in{'sfile'},
			undef, $viewname);
	if (@slaveerrs) {
		&error(&text('master_errslave',
		     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				      	    @slaveerrs)));
		}
	}

&redirect(($in{'type'} ? "edit_slave.cgi" : "edit_stub.cgi").
	  "?zone=$in{'zone'}&view=$in{'view'}");

