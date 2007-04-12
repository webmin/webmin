#!/usr/local/bin/perl
# delete_pack.cgi
# Ask if the user wants to delete a package, and if so do it

require './cluster-software-lib.pl';
&foreign_require("software", "software-lib.pl");
&ReadParse();

@servers = &list_servers();
@hosts = &list_software_hosts();
if ($in{'server'} < 0) {
	# Find servers that have the package
	foreach $h (@hosts) {
		foreach $p (@{$h->{'packages'}}) {
			if ($p->{'name'} eq $in{'package'}) {
				local ($s) = grep { $_->{'id'} == $h->{'id'} }
						  @servers;
				push(@got, $s);
				$gotmap{$s} = $h;
				$best = $s if (!$s->{'id'});
				last;
				}
			}
		}
	$s = $best ? $best : $got[0];
	}
else {
	($s) = grep { $_->{'id'} == $in{'server'} } @servers;
	($h) = grep { $_->{'id'} == $in{'server'} } @hosts;
	@got = ( $s );
	$gotmap{$s} = $h;
	}

&ui_print_header(undef, $text{'delete_title'}, "", "delete_pack");
if ($in{'sure'}) {
	# Do the deletion
	print "<b>",&text('delete_header', "<tt>$in{'package'}</tt>"),"</b><p>\n";
	&remote_multi_callback(\@got, $parallel_max, \&delete_callback, undef,
			       \@rvs, \@errs, "software", "software-lib.pl");

	# Show the results
	$p = 0;
	foreach $g (@got) {
		local $d = $g->{'desc'} ? $g->{'desc'} : $g->{'host'};

		if ($errs[$p] || $rvs[$p]) {
			print &text('delete_error', $d, $errs[$p] || $rvs[$p]),"<br>\n";
			}
		else {
			print &text('delete_success', $d),"<br>\n";
			local $h = $gotmap{$g};
			local @newpacks = grep { $_->{'name'} ne $in{'package'} } @{$h->{'packages'}};
			$h->{'packages'} = \@newpacks;
			&save_software_host($h);
			}
		$p++;
		}
	print "<p><b>$text{'delete_done'}</b><p>\n";
	}
else {
	# Sum up file sizes on best host
	&remote_foreign_require($s->{'host'}, "software", "software-lib.pl");
	if (!$gotmap{$s}->{'nofiles'}) {
		$n = &remote_foreign_call($s->{'host'}, "software",
					  "check_files", $in{'package'});
		$files = &remote_eval($s->{'host'}, "software", "\\%files");
		$sz = 0;
		for($i=0; $i<$n; $i++) {
			if ($files->{$i,'type'} == 0) {
				$sz += $files->{$i,'size'};
				}
			}
		}

	# Ask if the user is sure..
	print "<center>\n";
	if ($in{'server'} < 0) {
		print &text($n ? 'delete_rusure' : 'delete_rusurenone',
			   "<tt>$in{'package'}</tt>", $n, $sz),"<br>\n";
		}
	else {
		print &text($n ? 'delete_rusure2' : 'delete_rusure2none',
			   "<tt>$in{'package'}</tt>", $n, $sz,
			   $s->{'desc'} ? $s->{'desc'} : $s->{'host'}),"<br>\n";
		}
	print "<form action=delete_pack.cgi>\n";
	print "<input type=hidden name=package value=\"$in{'package'}\">\n";
	print "<input type=hidden name=server value=\"$in{'server'}\">\n";
	print "<input type=hidden name=sure value=1>\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<input type=submit value=\"$text{'delete_ok'}\"><p>\n";

	# Show deletion options - but only if remote package system matches
	if (defined(&software::delete_options) &&
	    &same_package_system($gotmap{$s})) {
		&foreign_call("software", "delete_options", $p);
		}
	print "</center></form>\n";
	}

&remote_finished();
&ui_print_footer("", $text{'index_return'});

# delete_callback(&host)
sub delete_callback
{
local $error = &remote_foreign_call($_[0]->{'host'},
   "software", "delete_package", $in{'package'}, \%in);
return $error;
}

