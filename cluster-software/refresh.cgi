#!/usr/local/bin/perl
# refresh.cgi
# Reload the list of packages from all managed hosts

require './cluster-software-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'refresh_title'}, "");
$| = 1;

# Work out which hosts to refresh
@hosts = &list_software_hosts();
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

# Do the refresh
@results = &refresh_packages(\@hosts);

# Show the user
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = $s->{'desc'} || $s->{'realhost'} || $s->{'host'};
	local $rv = $results[$p];

	if ($rv && ref($rv)) {
		@added = @{$rv->[0]};
		@old = @{$rv->[1]};
		if (@added && @old) {
			print &text('refresh_1', $d,
				    join(" ", @added),join(" ", @old)),"<br>\n";
			}
		elsif (@added) {
			print &text('refresh_2', $d,
				    join(" ", @added)),"<br>\n";
			}
		elsif (@old) {
			print &text('refresh_3', $d, join(" ", @old)),"<br>\n";
			}
		else {
			print &text('refresh_4', $d),"<br>\n";
			}
		}
	elsif ($rv) {
		print &text('refresh_failed', $d, $rv),"<br>\n";
		}
	else {
		print &text('refresh_del', $h->{'id'}),"<br>\n";
		}

	$p++;
	}

print "<p><b>$text{'refresh_done'}</b><p>\n";

&remote_finished();
if (defined($in{'id'})) {
	&ui_print_footer("edit_host.cgi?id=$in{'id'}", $text{'host_return'},
			 "", $text{'index_return'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

