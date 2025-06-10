#!/usr/local/bin/perl
# save_shared.cgi
# Update, create or delete a shared network

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
&lock_all_files();
($par, $sha, $indent) = &get_branch('sha', $in{'new'});
$parconf = $par->{'members'};

# check acls
%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});
if ($in{'delete'}) {
	&error("$text{'eacl_np'} $text{'eacl_pdn'}")
		if !&can('rw', \%access, $sha, 1);
	}
elsif ($in{'options'}) {
	&error("$text{'eacl_np'} $text{'eacl_psn'}")
		if !&can('r', \%access, $sha);
	}
elsif ($in{'new'}) {
	&error("$text{'eacl_np'} $text{'eacl_pin'}") 
		unless &can('c', \%access, $sha) && &can('rw', \%access, $par);
	# restrict duplicates
	if($access{'uniq_sha'}) {
		foreach $s (&find("shared-network", &get_config())) {
			&error("$text{'eacl_np'} $text{'eacl_uniq'}")
				if lc $s->{'values'}->[0] eq lc $in{'name'};
			}
		}
	}
else {
	&error("$text{'eacl_np'} $text{'eacl_pun'}")
		if !&can('rw', \%access, $sha);
	}

# save
if ($in{'options'}) {
	# Redirect to client options
	&redirect("edit_options.cgi?idx=$in{'idx'}");
	exit;
	}
else {
	if ($in{'delete'}) {
		&error_setup($text{'sshared_faildel'});
		}
	else {
		&error_setup($text{'sshared_failsave'});
		$in{'name'} =~ /^\S+$/ ||
			&error($text{'sshared_invalidsname'});
		$sha->{'values'} = [ $in{'name'} ];
		$sha->{'comment'} = $in{'desc'};
	}

	# Move hosts, groups and subnets into or out of this shared network
	@wasin = &find("host", $sha->{'members'});
	foreach $hn (split(/\0/, $in{'hosts'})) {
		if ($hn =~ /(\d+),(\d+)/) {
			push(@nowin, $parconf->[$2]->{'members'}->[$1]);
			$nowpr{$parconf->[$2]->{'members'}->[$1]} =
				$parconf->[$2];
			}
		elsif ($hn =~ /(\d+),/) {
			push(@nowin, $parconf->[$1]);
			$nowpr{$parconf->[$1]} = $par;
			}
		if ($nowin[$#nowin]->{'name'} ne "host") {
			&error($text{'sgroup_echanged'});
			}
		}
	@wasgin = &find("group", $sha->{'members'});
	foreach $gn (split(/\0/, $in{'groups'})) {
		if ($gn =~ /(\d+),(\d+)/) {
			push(@nowgin, $parconf->[$2]->{'members'}->[$1]);
			$nowgpr{$parconf->[$2]->{'members'}->[$1]} =
				$parconf->[$2];
			}
		elsif ($gn =~ /(\d+),/) {
			push(@nowgin, $parconf->[$1]);
			$nowgpr{$parconf->[$1]} = $par;
			}
		if ($nowgin[$#nowgin]->{'name'} ne "group") {
			&error($text{'sgroup_echanged'});
			}
		}
	@wasuin = &find("subnet", $sha->{'members'});
	foreach $un (split(/\0/, $in{'subnets'})) {
		if ($un =~ /(\d+),(\d+)/) {
			push(@nowuin, $parconf->[$2]->{'members'}->[$1]);
			$nowupr{$parconf->[$2]->{'members'}->[$1]} =
				$parconf->[$2];
			}
		elsif ($un =~ /(\d+),/) {
			push(@nowuin, $parconf->[$1]);
			$nowupr{$parconf->[$1]} = $par;
			}
		if ($nowuin[$#nowuin]->{'name'} ne "subnet") {
			&error($text{'sgroup_echanged'});
			}
		}

	&error_setup($text{'eacl_aviol'});
	foreach $h (&unique(@wasin, @nowin)) {
		$was = &indexof($h, @wasin) != -1;
		$now = &indexof($h, @nowin) != -1;

		# per-host ACLs for new or updated hosts
		if ($was != $now && !&can('rw', \%access, $h)) {
			&error("$text{'eacl_np'} $text{'eacl_pun'}");
			}
		if ($was && !$now) {
			# Move out of the shared network
			&save_directive($sha, [ $h ], [ ], 0);
			&save_directive($par, [ ], [ $h ], 0);
			}
		elsif ($now && !$was) {
			# Move into the shared network (maybe from another)
			&save_directive($nowpr{$h}, [ $h ], [ ], 0);
			&save_directive($sha, [ ], [ $h ], 1);
			}
		}
	foreach $g (&unique(@wasgin, @nowgin)) {
		$was = &indexof($g, @wasgin) != -1;
		$now = &indexof($g, @nowgin) != -1;

		# per-group ACLs for new or updated groups
		if ($was != $now && !&can('rw', \%access, $g)) {
			&error("$text{'eacl_np'} $text{'eacl_pun'}");
			}	
		if ($was && !$now) {
			# Move out of the shared network
			&save_directive($sha, [ $g ], [ ], 0);
			&save_directive($par, [ ], [ $g ], 0);
			}
		elsif ($now && !$was) {
			# Move into the shared network (maybe from another)
			&save_directive($nowgpr{$g}, [ $g ], [ ], 0);
			&save_directive($sha, [ ], [ $g ], 1);
			}
		}
	foreach $u (&unique(@wasuin, @nowuin)) {
		$was = &indexof($u, @wasuin) != -1;
		$now = &indexof($u, @nowuin) != -1;

		# per-subnet ACLs for new or updated subnetss
		if ($was != $now && !&can('rw', \%access, $u)) {
			&error("$text{'eacl_np'} $text{'eacl_pun'}");
			}		 
		if ($was && !$now) {
			# Move out of the shared network
			&save_directive($sha, [ $u ], [ ], 0);
			&save_directive($par, [ ], [ $u ], 0);
			if ($par->{'name'} eq "shared-network") {
				&fix_sequence($par);
				}
			}
		elsif ($now && !$was) {
			# Move into the shared network (maybe from another)
			&save_directive($nowupr{$u}, [ $u ], [ ], 0);
			&save_directive($sha, [ ], [ $u ], 1);
			if ($nowupr{$u}->{'name'} eq "shared-network") {
				&check_subnets($nowupr{$u});
				}
			}
		}
	&check_subnets($sha);
	&fix_sequence($sha);

	if (!$in{'delete'}) {
		&parse_params($sha);

		if ($in{'new'}) {
			# Add this shared net
			&save_directive($par, [ ], [ $sha ], 0);
			}
		else {
			# Update shared net
			&save_directive($par, [ $sha ], [ $sha ], 0);
			}
		}
	}
&flush_file_lines();
if ($in{'delete'}) {
	# Delete this net
	if ($in{'hosts'} eq "" && $in{'groups'} eq "" && $in{'subnets'} eq "") {
		&save_directive($par, [ $sha ], [ ], 0);
		&flush_file_lines();
		}
	else {
		&unlock_all_files();
		&redirect("confirm_delete.cgi?idx=$in{'idx'}\&type=0");
		exit;
		}
	}
&unlock_all_files();
&webmin_log($in{'delete'} ? 'delete' : $in{'new'} ? 'create' : 'modify',
	    'shared', $sha->{'values'}->[0], \%in);
&redirect("");

# check whether thist shared network contains any subnet
sub check_subnets
{
local(@subnets);
@subnets = &find("subnet", $_[0]->{'members'});
if (@subnets == 0) {
	&error_setup($text{'sshared_failsave'});
	&error(&text('sshared_nosubnet', $_[0]->{'values'}->[0]));
	}
}

# force hosts and groups to follow subnets
sub fix_sequence
{
local(@subnets, $max, $u, $i);
@subnets = &find("subnet", $_[0]->{'members'});
$max = -1;
foreach $u (@subnets) {
	$max = $u->{'index'} > $max ? $u->{'index'} : $max;
	}
for ($i = 0; $i < $max; $i++) {
	$u = $_[0]->{'members'}->[$i];
	if ($u->{'name'} eq "host" || $u->{'name'} eq "group") {
		# move to the end of list
		&save_directive($_[0], [ $u ], [ ], 0);
		&save_directive($_[0], [ ], [ $u ], 0);
		}
	}
}

