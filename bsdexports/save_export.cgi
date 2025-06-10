#!/usr/local/bin/perl
# save_export.cgi
# Save or create an export

require './bsdexports-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

if ($in{'delete'}) {
	# Redirect to delete CGI
	&redirect("delete_export.cgi?idx=$in{'idx'}");
	exit(0);
	}

# Validate and save inputs
@dl = split(/\s+/, $in{'dirs'});
foreach $d (@dl) {
	-d $d || &error(&text('save_edir', $d));
	}
@dl || &error($text{'save_enone'});
if ($in{'alldirs'}) {
	@dl == 1 || &error($text{'save_esub'});
	if (&root_dir($dl[0]) ne $dl[0]) {
		&error($text{'save_eroot'});
		}
	}
$exp{'dirs'} = \@dl;
@devno = map { (stat($_))[0] } @dl;
$exp{'alldirs'} = $in{'alldirs'};
$exp{'ro'} = $in{'ro'};
$exp{'kerb'} = $in{'kerb'};

if (!$in{'maproot_def'}) {
	$in{'maproot'} =~ /^-?\d+$/ || defined(getpwnam($in{'maproot'})) ||
		&error(&text('save_euser', $in{'maproot'}));
	if ($in{'maprootg_def'}) {
		@rgl = split(/\s+/, $in{'maprootg'});
		foreach $g (@rgl) {
			$g =~ /^-?\d+$/ || defined(getgrnam($g)) ||
				&error(&text('save_egroup', $g));
			}
		$exp{'maproot'} = "$in{'maproot'}:".join(':', @rgl);
		}
	else { $exp{'maproot'} = $in{'maproot'}; }
	}

if (!$in{'mapall_def'}) {
	$in{'mapall'} =~ /^-?\d+$/ || defined(getpwnam($in{'mapall'})) ||
		&error(&text('save_euser', $in{'mapall'}));
	if ($in{'mapallg_def'}) {
		@rgl = split(/\s+/, $in{'mapallg'});
		foreach $g (@agl) {
			$g =~ /^-?\d+$/ || defined(getgrnam($g)) ||
				&error(&text('save_egroup', $g));
			}
		$exp{'mapall'} = "$in{'mapall'}:".join(':', @agl);
		}
	else { $exp{'mapall'} = $in{'mapall'}; }
	}

if (!$in{'maproot_def'} + !$in{'mapall_def'} + $in{'kerb'} > 1) {
	&error($text{'save_ekerb'});
	}

if ($in{'cmode'} == 0) {
	# Exporting to a list of hosts
	@hl = split(/\s+/, $in{'hosts'});
	@hl || &error($text{'save_ehosts'});
	$exp{'hosts'} = \@hl;
	foreach $h (@hl) {
		$ip = &to_ipaddress($h) || &to_ip6address($h);
		if ($ip) { push(@iplist, $ip); }
		}
	}
else {
	# Exporting to a subnet
	&check_ipaddress($in{'network'}) ||
		&error(&text('save_enetwork', $in{'network'}));
	&check_ipaddress($in{'mask'}) ||
		&error(&text('save_enetmask', $in{'netmask'}));
	$exp{'network'} = $in{'network'};
	$exp{'mask'} = $in{'mask'};
	}

# Check for an export to the same host on the same local filesystem
&lock_file($config{'exports_file'});
@exps = &list_exports();
for($i=0; $i<@exps; $i++) {
	next if (defined($in{'index'}) && $in{'index'} == $i);
	$samefs = 0;
	foreach $d (@{$exps[$i]->{'dirs'}}) {
		if (&indexof((stat($d))[0], @devno) >= 0) {
			# Same filesystem as this export..
			$samefs = $d;
			}
		}
	next if (!$samefs);
	foreach $h (@{$exps[$i]->{'hosts'}}) {
		$ip = &to_ipaddress($h) || &to_ip6address($h);
		if ($ip && &indexof($ip, @iplist) >= 0) {
			# Another export on this filesystem is to the same host
			&error(&text('save_esame1', $samefs, $h));
			}
		}
	if ($exp{'mask'} && $exp{'mask'} eq $exps[$i]->{'mask'} &&
			    $exp{'network'} eq $exps[$i]->{'network'}) {
		# Another export on this filesystem to the same net
		&error(&text('save_esame1', $samefs, $exp{'network'}));
		}
	}

if (defined($in{'index'})) {
	$old = $exps[$in{'index'}];
	$exp{'public'} = $old->{'public'};
	$exp{'webnfs'} = $old->{'webnfs'};
	$exp{'index'} = $old->{'index'};
	&modify_export($old, \%exp);
	}
else {
	&create_export(\%exp);
	}
&unlock_file($config{'exports_file'});
&redirect("");

# root_dir(path)
# Returns the root directory of the filesystem some path is in
sub root_dir
{
my $dir = $_[0];
my @pst = stat($dir);
while(1) {
	if ($dir eq "/") { return "/"; }
	my $lastdir = $dir;
	$dir =~ s/\/[^\/]+$//g;
	if ($dir eq "") { $dir = "/"; }
	my @ust = stat($dir);
	if ($ust[0] != $pst[0]) { return $lastdir; }
	}
}

