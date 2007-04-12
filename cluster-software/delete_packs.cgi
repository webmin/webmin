#!/usr/local/bin/perl
# Ask if the user wants to delete multiple packages, and if so do it

require './cluster-software-lib.pl';
&ReadParse();
&error_setup($text{'deletes_err'});

# Find the specified hosts
@servers = &list_servers();
@hosts = &list_software_hosts();
if ($in{'server'} >= 0) {
	@hosts = grep { $_->{'id'} eq $in{'server'} } @hosts;
	}
@got = map { &host_to_server($_) } @hosts;

# Find the packages for each host
@packs = split(/\0/, $in{'del'});
foreach $p (@packs) {
	foreach $h (@hosts) {
		($pkg) = grep { $_->{'name'} eq $p } @{$h->{'packages'}};
		if ($pkg) {
			push(@{$pkghosts{$h->{'id'}}}, $p);
			$pkgmap{$h->{'id'},$p} = 1;
			$found++;
			}
		}
	}
$found || &error($text{'deletes_enone'});

&ui_print_header(undef, $text{'deletes_title'}, "", "delete");

if ($in{'sure'}) {
	# do the deletion
	print "<b>",&text('deletes_desc', "<tt>".join(" ", @packs)."</tt>"),
	      "</b><p>\n";
	&remote_multi_callback(\@got, $parallel_max, \&deletes_callback, undef,
			       \@rvs, \@errs, "software", "software-lib.pl");

	# Show the results
	$p = 0;
	foreach $h (@hosts) {
		$g = &host_to_server($h);
		local $d = $g->{'desc'} ? $g->{'desc'} : $g->{'host'};
		if ($errs[$p] || $rvs[$p]) {
			print &text('delete_error', $d, $errs[$p] || $rvs[$p]),"<br>\n";
			}
		else {
			print &text('delete_success', $d),"<br>\n";
			local @newpacks = grep { !$pkgmap{$h->{'id'},$_->{'name'}} } @{$h->{'packages'}};
			$h->{'packages'} = \@newpacks;
			&save_software_host($h);
			}
		$p++;
		}
	print "<p><b>$text{'delete_done'}</b><p>\n";
	&webmin_log("deletes", "package", undef, { 'packs' => \@packs });
	}
else {
	# Ask if the user is sure..
	print "<center>\n";
	print &text('deletes_rusure', "<tt>".join(" ", @packs)."</tt>"),
	      "<p>\n";
	print "<form action=delete_packs.cgi>\n";
	foreach $d (@packs) {
		print "<input type=hidden name=del value='$d'>\n";
		}
	print "<input type=hidden name=sure value=1>\n";
	print "<input type=hidden name=server value=$in{'server'}>\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<input type=submit value=\"$text{'deletes_ok'}\"><p>\n";
	if (defined(&software::delete_options) &&
	    &same_package_system($hosts[0])) {
		&software::delete_options($packs[0]);
		}
	print "</center></form>\n";

	}

&ui_print_footer("search.cgi?search=$in{'search'}", $text{'search_return'});

# deletes_callback(&server)
sub deletes_callback
{
local ($serv) = @_;
local @pkgs = @{$pkghosts{$serv->{'id'}}};
if (defined(&software::delete_packages)) {
	# Use single delete function
	$error = &remote_foreign_call($serv->{'host'}, "software", "delete_packages", \@pkgs, \%in);
	}
else {
	# Call delete function once per package
	local @errors;
	foreach my $p (@pkgs) {
		local $oneerror = &remote_foreign_call($serv->{'host'}, "software", "delete_package", $p, \%in);
		push(@errors, $oneerror) if ($oneerror);
		}
	$error = join(" ", @errors);
	}
return $error;
}
