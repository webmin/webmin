#!/usr/local/bin/perl
# Do an actual comparison

require './cluster-software-lib.pl';
&error_setup($text{'compare_err'});
&ReadParse();

# Work out which servers to use
if ($in{'all'}) {
	@hosts = &list_software_hosts();
	}
else {
	@allhosts = &list_software_hosts();
	@servers = &list_servers();
	@groups = &servers::list_all_groups(\@servers);
	foreach $s (split(/\0/, $in{'hosts'})) {
		if ($s =~ /^group_(.*)$/) {
			# Add all group members
			($group) = grep { $_->{'name'} eq $1 } @groups;
			foreach $m (@{$group->{'members'}}) {
				($server) =grep { $_->{'host'} eq $m } @servers;
				($host) = grep { $_->{'id'} eq $server->{'id'} } @allhosts;
				push(@hosts, $host) if ($host);
				}
			}
		else {
			# Add one host
			($host) = grep { $_->{'id'} eq $s } @allhosts;
			push(@hosts, $host) if ($host);
			}
		}
	}
@hosts >= 2 || &error($text{'compare_etwo'});

&ui_print_header(undef, $text{'compare_title'}, "");

# Find union of all packages
foreach $h (@hosts) {
	foreach $p (@{$h->{'packages'}}) {
		$p->{'host'} = $h;
		push(@{$packs{$p->{'name'}}}, $p);
		}
	}

# Show results by package
%smap = map { $_->{'id'}, $_ } &list_servers();
print &ui_columns_start([ $text{'compare_pack'},
			  map { &server_name($smap{$_->{'id'}}) } @hosts ]);
foreach $pn (sort { $a cmp $b } (keys %packs)) {
	local @row = ( &ui_link("edit_pack.cgi?package=$pn",$pn) );
	local $ok = 1;
	foreach $h (@hosts) {
		local ($ph) = grep { $_->{'host'} eq $h } @{$packs{$pn}};
		if (!$ph) {
			push(@row, $text{'compare_miss'});
			$ok = 0;
			}
		else {
			push(@row, $ph->{'version'} || $text{'compare_got'});
			if ($ph->{'version'} &&
			    $ph->{'version'} != $packs{$pn}->[0]->{'version'}) {
				$ok = 0;
				}
			}
		}
	if (!$ok || $in{'showall'}) {
		print &ui_columns_row(\@row);
		}
	}
print &ui_columns_end();

&ui_print_footer("", $text{'index_return'});
