#!/usr/local/bin/perl
# add.cgi
# Add or update a server or group from the webmin servers module

require './cluster-software-lib.pl';
&ReadParse();
@servers = &list_servers();

if ($in{'add'}) {
	# Add a single host
	@add = grep { $_->{'id'} eq $in{'server'} } @servers;
	&error_setup($text{'add_err'});
	$msg = &text('add_msg', &server_name($add[0]));
	}
else {
	# Add all from a group
	($group) = grep { $_->{'name'} eq $in{'group'} }
			&servers::list_all_groups(\@servers);
	foreach $m (@{$group->{'members'}}) {
		push(@add, grep { $_->{'host'} eq $m } @servers);
		}
	&error_setup($text{'add_gerr'});
	$msg = &text('add_gmsg', $in{'group'});
	}
&ui_print_header(undef, $text{'add_title'}, "");
print "<b>$msg</b><p>\n";

# Get the packages for each host
foreach $s (@add) {
	($ok, $out) = &add_managed_host($s);
	print "$out<p>\n";
	}
&remote_finished();

&ui_print_footer("", $text{'index_return'});


