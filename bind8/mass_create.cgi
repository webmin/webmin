#!/usr/local/bin/perl
# Actually create multiple zones
use strict;
use warnings;
our (%access, %in, %text, %config);

require './bind8-lib.pl';
&ReadParseMime();
&ui_print_unbuffered_header(undef, $text{'mass_title'}, "");
&error_setup($text{'mass_err'});
my $conf = &get_config();
$access{'ro'} && &error($text{'master_ero'});

# Check if the template needs IPs
my $tmpl_ip;
if ($in{'tmpl'}) {
	for(my $i=0; $config{"tmpl_$i"}; $i++) {
		my @c = split(/\s+/, $config{"tmpl_$i"}, 3);
		if ($c[1] eq 'A' && !$c[2]) {
			$tmpl_ip++;
			}
		}
	}

my $vn;
my @zones;
my $zonecount;
my $lnum;
# Build map of taken zones
if ($in{'view'} ne '') {
	# In some view
	@zones = grep { $_->{'viewindex'} eq $in{'view'} &&
			$_->{'type'} ne 'view' }
		      &list_zone_names();
	my $view = $conf->[$in{'view'}];
	&can_edit_view($view) || &error($text{'mass_eviewcannot'});
	$vn = $view->{'value'};
	}
else {
	# At top-level
	@zones = grep { !$_->{'view'} && $_->{'type'} ne 'view' }
		      &list_zone_names();
	$vn = undef;
	}
my %taken = map { $_->{'name'}, $_ } @zones;

# Get zone defaults
my %zd;
&get_zone_defaults(\%zd);

if ($in{'local'}) {
	&allowed_zone_file(\%access, $in{'local'}) ||
		&error($text{'mass_elocalcannot'});
	my $local = &read_file_contents($in{'local'});
	$local || &error($text{'mass_elocal'});
	print "<b>",&text('mass_dolocal', "<tt>$in{'local'}</tt>"),"</b><br>\n";
	&execute_batchfile($local);
	print "<b>",$text{'mass_done'},"</b><p>\n";
	}
if ($in{'upload'}) {
	print "<b>",&text('mass_doupload'),"</b><br>\n";
	&execute_batchfile($in{'upload'});
	print "<b>",$text{'mass_done'},"</b><p>\n";
	}
if ($in{'text'}) {
	print "<b>",&text('mass_dotext'),"</b><br>\n";
	&execute_batchfile($in{'text'});
	print "<b>",$text{'mass_done'},"</b><p>\n";
	}

&webmin_log("mass", undef, $zonecount);
&ui_print_footer("", $text{'index_return'});

# execute_batchfile(data)
sub execute_batchfile
{
my @lines = split(/[\r\n]+/, $_[0]);
my $l;
$lnum = 0;
foreach my $l (@lines) {
	$lnum++;
	my @w = split(/:/, $l);
	my $dom = $w[0];
	if ($dom !~ /^[a-z0-9\.\-\_]+$/) {
		&line_error($l, $text{'mass_edom'});
		next;
		}
	my $isrev = 0;
	if (&check_ipaddress($dom)) {
		$dom = &ip_to_arpa($dom);
		$isrev = 1;
		}

	# Check for a clash
	if ($taken{$dom}) {
		&line_error($l, $text{'mass_etaken'});
		next;
		}

	# Get the IP addresses
	my @mips = split(/\s+/, $w[3]);
	foreach my $mip (@mips) {
		if (!&check_ipaddress($mip)) {
			&line_error($l, $text{'mass_eip'});
			next;
			}
		}

	my $type = $w[1] || "master";
	my $file = $w[2];
	my $dir;
	my $base;
	if ($type eq "master") {
		# Creating a master zone
		if (!$access{'master'}) {
			&line_error($l, $text{'mcreate_ecannot'});
			next;
			}

		# Work out the base
		$base = $config{'master_dir'} ? $config{'master_dir'} :
			$access{'dir'} eq '/' ? &base_directory($conf) :
						$access{'dir'};
		if ($base !~ /^([a-z]:)?\//) {
			# Master dir is relative .. make absolute
			$base = &base_directory()."/".$base;
			}

		# Make sure a template IP was given, if needed
		if ($tmpl_ip && !@mips) {
			&line_error($l, $text{'mass_etmpl'});
			next;
			}

		# Work out the filename
		if ($file) {
			if ($file !~ /^\//) {
				$file = $base."/".$file;
				}
			if (!&allowed_zone_file(\%access, $file)) {
				&line_error($l, &text('create_efile2', $file));
				next;
				}
			}
		else {
			$file = &automatic_filename($dom, $isrev, $base, $vn);
			}
		if (-r &make_chroot($file)) {
			&line_error($l, &text('create_efile4', $file));
			next;
			}

		# Create the zone file and initial records
		my $master = $config{'default_prins'} ||
				&get_system_hostname();
		$master =~ s/\.$//;
		$master .= ".";
		my $email = $config{'tmpl_email'} || "root\@$master";
		$email = &email_to_dotted($email);
		&create_master_records($file, $dom, $master, $email,
				       $zd{'refresh'}.$zd{'refunit'},
				       $zd{'retry'}.$zd{'retunit'},
				       $zd{'expiry'}.$zd{'expunit'},
				       $zd{'minimum'}.$zd{'minunit'},
				       1,
				       $in{'onslave'} && $access{'remote'},
				       $in{'tmpl'}, $mips[0]);

		# Create the zone directive
		$dir = { 'name' => 'zone',
			 'values' => [ $dom ],
			 'type' => 1,
			 'members' => [ { 'name' => 'type',
					  'values' => [ 'master' ] },
					{ 'name' => 'file',
					  'values' => [ $file ] } ]
			};
		}
	elsif ($type eq "slave" || $type eq "stub") {
		# Creating a slave or stub zone
		if (!$access{'slave'}) {
			&line_error($l, $text{'screate_ecannot1'});
			next;
			}

		# Work out the base
		$base = $config{'slave_dir'} ? $config{'slave_dir'} :
			$access{'dir'} eq '/' ? &base_directory($conf) :
						$access{'dir'};
		if ($base !~ /^([a-z]:)?\//) {
			# Slave dir is relative .. make absolute
			$base = &base_directory()."/".$base;
			}

		# Make sure some master IPs were given
		if (!@mips) {
			&line_error($l, $text{'mass_emips'});
			next;
			}

		# Work out the filename
		if ($file eq "none") {
			$file = undef;	# no file!
			}
		elsif ($file) {
			if ($file !~ /^\//) {
				$file = $base."/".$file;
				}
			if (!&allowed_zone_file(\%access, $file)) {
				&line_error($l, &text('create_efile2', $file));
				next;
				}
			}
		else {
			$file = &automatic_filename($dom, $isrev, $base, $vn);
			}

		# Create the file now
		if ($file) {
		        my $ZONE;
			if (!open($ZONE, ">", &make_chroot($file))) {
				&line_error($l, &text('create_efile3',
						      $file, $!));
				next;
				}
			close($ZONE);
			&set_ownership(&make_chroot($file));
			}

		# Create the structure
		my @mdirs = map { { 'name' => $_ } } @mips;
		my $masters = { 'name' => 'masters',
				   'type' => 1,
				   'members' => \@mdirs };
		$dir = { 'name' => 'zone',
			 'values' => [ $dom ],
			 'type' => 1,
			 'members' => [ { 'name' => 'type',
					  'values' => [ $type ] },
					$masters
				      ]
			};
		if ($file) {
			push(@{$dir->{'members'}},
				{ 'name' => 'file',
				  'values' => [ $file ] });
			}
		}
	elsif ($type eq "forward") {
		# Creating a forward
		if (!$access{'forward'}) {
			&line_error($l, $text{'fcreate_ecannot'});
			next;
			}

		# Make sure some master IPs were given
		if (!@mips) {
			&line_error($l, $text{'mass_emips'});
			next;
			}

		# Create the structure
		my @mdirs = map { { 'name' => $_ } } @mips;
		my $masters = { 'name' => 'forwarders',
				   'type' => 1,
				   'members' => \@mdirs };
		$dir = { 'name' => 'zone',
			 'values' => [ $dom ],
			 'type' => 1,
			 'members' => [ { 'name' => 'type',
					  'values' => [ 'forward' ] },
					$masters
				      ]
			};
		}

	else {
		&line_error($l, $text{'mass_etype'});
		next;
		}

	if ($dir) {
		# Add the zone structure
		&create_zone($dir, $conf, $in{'view'});
		&add_zone_access($dom);
		$taken{$dom}++;
		&line_ok($dom, $type);
		$zonecount++;
		}

	if ($type eq "master" && $in{'onslave'} && $access{'remote'}) {
		# Create on slave servers
		my @slaveerrs = &create_on_slaves($dom,
		  $config{'this_ip'} || &to_ipaddress(&get_system_hostname()),
		  undef, undef, $vn);
		print "&nbsp;&nbsp;\n";
		if (@slaveerrs) {
			my $serrs = join(", ", map { "$_->[0]->{'host'} : $_->[1]" } @slaveerrs);
			print "<font color=#ff0000>",
			      &text('mass_eonslave', $serrs),"</font><br>\n";
			}
		else {
			print &text('mass_addedslaves', $dom),"<br>\n";
			}
		}
	}
}

sub line_error
{
print "<font color=#ff0000>",&text('mass_eline', $lnum, $_[1], $_[0]),
      "</font><br>\n";
}

sub line_ok
{
print &text('mass_added'.$_[1], $_[0]),"<br>\n";
}

