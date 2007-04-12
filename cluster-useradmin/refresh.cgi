#!/usr/local/bin/perl
# refresh.cgi
# Reload the lists of users and groups from all managed hosts

require './cluster-useradmin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'refresh_title'}, "");
$| = 1;

# Setup error handler for down hosts
sub ref_error
{
$ref_error_msg = join("", @_);
}
&remote_error_setup(\&ref_error);

@hosts = &list_useradmin_hosts();
@servers = &list_servers();
if (defined($in{'id'})) {
	@hosts = grep { $_->{'id'} == $in{'id'} } @hosts;
	local ($s) = grep { $_->{'id'} == $hosts[0]->{'id'} } @servers;
	print "<b>",&text('refresh_header5', undef,
			  &server_name($s)),"</b><p>\n";
	}
else {
	@hosts = &create_on_parse("refresh_header");
	}
foreach $h (@hosts) {
	$ref_error_msg = undef;
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	if ($s) {
		# Refresh the list
		local $d = $s->{'desc'} ? $s->{'desc'} : $s->{'host'};
		&remote_foreign_require($s->{'host'}, "useradmin",
					"user-lib.pl");
		if ($ref_error_msg) {
			# Host is down ..
			print &text('refresh_failed', $d,
				    $ref_error_msg),"<br>\n";
			next;
			}
		local $ousers = @{$h->{'users'}};
		local $ogroups = @{$h->{'groups'}};
		local @rusers = &remote_foreign_call($s->{'host'}, "useradmin",
						     "list_users");
		local @rgroups = &remote_foreign_call($s->{'host'}, "useradmin",
						      "list_groups");
		$h->{'users'} = \@rusers;
		$h->{'groups'} = \@rgroups;
		print &text('refresh_host', $d),"\n";
		local @ad;
		if (@rusers > $ousers) {
			push(@ad, &text('refresh_uadd', @rusers - $ousers));
			}
		elsif (@rusers < $ousers) {
			push(@ad, &text('refresh_udel', $ousers - @rusers));
			}
		if (@rgroups > $ogroups) {
			push(@ad, &text('refresh_gadd', @rgroups - $ogroups));
			}
		elsif (@rgroups < $ogroups) {
			push(@ad, &text('refresh_gdel', $ogroups - @rgroups));
			}
		if (@ad) {
			print "(",join(", ", @ad),")";
			}
		&save_useradmin_host($h);
		print "<br>\n";
		}
	else {
		# remove from managed list
		&delete_useradmin_host($h);
		print &text('refresh_del', $h->{'id'}),"<br>\n";
		}
	}
print "<p><b>$text{'refresh_done'}</b><p>\n";
&webmin_log("refresh");

&remote_finished();
if (defined($in{'id'})) {
        &ui_print_footer("edit_host.cgi?id=$in{'id'}", $text{'host_return'},
                         "", $text{'index_return'});
        }
else {
        &ui_print_footer("", $text{'index_return'});
        }

