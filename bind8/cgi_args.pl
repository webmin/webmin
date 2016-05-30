use strict;
use warnings;

do 'bind8-lib.pl';
# Globals from bind8-lib.pl
our (%config, %text, %in);

sub cgi_args
{
my ($cgi) = @_;
if ($cgi =~ /^conf_/) {
	# All config pages can be linked to
	return '';
	}
elsif ($cgi =~ /^edit_(master|slave|stub|forward|delegation|hint).cgi$/) {
	# Find a zone of this type
	my @allzones = grep { &can_edit_zone($_) } &list_zone_names();
	my ($z) = grep { $_->{'type'} eq $1 } @allzones;
	return $z ? 'zone='.$z->{'zone'}.
		    ($z->{'view'} ? '&view='.$z->{'viewindex'} : '') : 'none';
	}
elsif ($cgi eq 'edit_view.cgi') {
	# Find a view
	my ($v) = grep { $_->{'type'} eq 'view' &&
			 &can_edit_view($_) } &list_zone_names();
	return $v ? 'index='.$v->{'index'} : 'none';
	}
elsif ($cgi eq 'edit_text.cgi' || $cgi eq 'edit_soa.cgi' ||
       $cgi eq 'edit_options.cgi' || $cgi eq 'find_free.cgi' ||
       $cgi eq 'list_gen.cgi' || $cgi eq 'whois.cg' ||
       $cgi eq 'edit_zonekey.cgi' || $cgi eq 'edit_recs.cgi' ||
       $cgi eq 'edit_record.cgi') {
	# Find a master zone
	my ($z) = grep { $_->{'type'} eq 'master' &&
			 &can_edit_zone($_) } &list_zone_names();
	return 'none' if (!$z);
	my $rv = 'zone='.$z->{'zone'}.
                 ($z->{'view'} ? '&view='.$z->{'viewindex'} : '');
	if ($cgi eq 'edit_recs.cgi' || $cgi eq 'edit_record.cgi') {
		$rv .= '&type=A';
		}
	if ($cgi eq 'edit_record.cgi') {
		# Link to first A record
		my @recs = &read_zone_file($z->{'file'}, $z->{'name'});
		my ($r) = grep { $_->{'type'} eq 'A' } @recs;
		if ($r) {
			$rv .= '&num='.$r->{'num'};
			}
		else {
			return 'none';
			}
		}
	return $rv;
	}
elsif ($cgi eq 'view_text.cgi' || $cgi eq 'edit_soptions.cgi') {
	# Find a slave zone
	my ($z) = grep { $_->{'type'} eq 'slave' &&
			 &can_edit_zone($_) } &list_zone_names();
	return $z ? 'zone='.$z->{'zone'}.
		    ($z->{'view'} ? '&view='.$z->{'viewindex'} : '') : 'none';
	}
return undef;
}
