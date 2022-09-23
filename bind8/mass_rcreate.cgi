#!/usr/local/bin/perl
# Add a record to multiple domains
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'rmass_err'});

# Get the zones
my @zones;
foreach my $d (split(/\0/, $in{'d'})) {
	my ($zonename, $viewidx) = split(/\s+/, $d);
	my $zone = &get_zone_name_or_error($zonename, $viewidx);
	$zone || &error($text{'umass_egone'});
	&can_edit_zone($zone) ||
		&error($text{'master_edelete'});
	push(@zones, $zone);
	}
$access{'ro'} && &error($text{'master_ero'});

# Validate inputs
&valdnsname($in{'name'}) || $in{'name'} eq '@' || &error($text{'rmass_ename'});
$in{'name'} =~ /\.$/ && &error($text{'rmass_ename2'});
my $mxpri;
if ($in{'type'} eq 'A') {
	&check_ipaddress($in{'value'}) ||
		&error(&text('edit_eip', $in{'value'}));
	}
elsif ($in{'type'} eq 'AAAA') {
	&check_ip6address($in{'value'}) ||
		&error(&text('edit_eip6', $in{'value'}));
	}
elsif ($in{'type'} eq 'NS') {
	&valname($in{'value'}) ||
		&error(&text('edit_ens', $in{'value'}));
	}
elsif ($in{'type'} eq 'CNAME') {
	&valname($in{'value'}) || $in{'value'} eq '@' ||
		&error(&text('edit_ecname', $in{'value'}));
	}
elsif ($in{'type'} eq 'MX') {
	$in{'value'} =~ /^(\d+)\s+(\S+)$/ && &valname("$2") ||
		&error(&text('emass_emx', $in{'value'}));
	$mxpri = $1;
	}
elsif ($in{'type'} eq 'TXT') {
	$in{'value'} = "\"$in{'value'}\"";
	}
elsif ($in{'type'} eq 'PTR') {
	&valname($in{'value'}) ||
		&error(&text('edit_eptr', $in{'value'}));
	}
$in{'ttl_def'} || $in{'ttl'} =~ /^\d+$/ ||
	&error($text{'rmass_ettl'});

# Do each one
&ui_print_unbuffered_header(undef, $text{'rmass_title'}, "");

foreach my $zi (@zones) {
	print &text('rmass_doing', "<tt>$zi->{'name'}</tt>"),"<br>\n";
	if ($zi->{'type'} ne 'master' && $zi->{'type'} ne 'primary') {
		# Skip - not a master zone
		print $text{'umass_notmaster'},"<p>\n";
		next;
		}
	my $fullname = $in{'name'} eq '@' ?
			$zi->{'name'}."." :
			$in{'name'}.".".$zi->{'name'}.".";
	&before_editing($zi);
	my @recs = &read_zone_file($zi->{'file'}, $zi->{'name'});
	my $clash;
	if ($in{'type'} eq 'CNAME' || $in{'clash'}) {
		# Check if a record with the same name exists
		if ($in{'type'} eq 'MX') {
			# MX has to clash on priority too
			($clash) = grep { $_->{'name'} eq $fullname &&
					  $_->{'type'} eq $in{'type'} &&
					  $_->{'values'}->[0] == $mxpri } @recs;
			}
		else {
			# Other types clash on name
			($clash) = grep { $_->{'name'} eq $fullname &&
					  $_->{'type'} eq $in{'type'} } @recs;
			}
		if ($clash) {
			print &text('rmass_eclash',
			    "<tt>".join(" ", @{$clash->{'values'}})."</tt>"),
			    "<p>\n";
			next;
			}
		}
	# Check if a record with the same name and value exists
	($clash) = grep { $_->{'name'} eq $fullname &&
			  $_->{'type'} eq $in{'type'} &&
			  join(" ", @{$_->{'values'}}) eq $in{'value'} } @recs;
	if ($clash) {
		print &text('rmass_eclash2',
		    "<tt>".join(" ", @{$clash->{'values'}})."</tt>"),"<p>\n";
		next;
		}
	&create_record($zi->{'file'}, $in{'name'}, $in{'ttl'}, "IN",
		       $in{'type'}, $in{'value'});
	&bump_soa_record($zi->{'file'}, \@recs);
	eval {
		# XXX Can't we use autodie or something standard here?
		no warnings;
		local $main::error_must_die = 1;
		use warnings;
		&sign_dnssec_zone_if_key($zi, \@recs);
		};
	if ($@) {
		print &text('rmass_esign', $@),"<p>\n";
		}
	else {
		print $text{'rmass_done'},"<p>\n";
		}
	&after_editing($zi);
	}

&unlock_all_files();
&webmin_log("rcreate", "zones", scalar(@zones));

&ui_print_footer("", $text{'index_return'});

# valname(name)
sub valname
{
return valdnsname($_[0], 0, $in{'origin'});
}

