#!/usr/local/bin/perl
# refresh.cgi
# Reload the list of modules from all managed hosts

require './cluster-usermin-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'refresh_title'}, "");
$| = 1;

# Setup error handler for down hosts
sub ref_error
{
$ref_error_msg = join("", @_);
}
&remote_error_setup(\&ref_error);

# Work out which hosts
@hosts = &list_usermin_hosts();
@servers = &list_servers();
if (defined($in{'id'})) {
        @hosts = grep { $_->{'id'} == $in{'id'} } @hosts;
	local ($s) = grep { $_->{'id'} == $hosts[0]->{'id'} } @servers;
        print "<b>",&text('refresh_header5', undef,
			  &server_name($s)),"</b><p>\n";
        }
else {
	@hosts = &create_on_parse("refresh_header");
        #print "<b>$text{'refresh_header'}</b><p>\n";
        }
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;

	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	if (!fork()) {
		close($rh);
		if ($s) {
			# Refresh the list
			&remote_foreign_require($s->{'host'}, "usermin",
						"usermin-lib.pl");
			if ($ref_error_msg) {
				# Host is down ..
				print $wh &serialise_variable($ref_error_msg);
				exit;
				}
			local $gconfig = &remote_foreign_config($s->{'host'},
								undef);
			foreach $g ('os_type', 'os_version',
				    'real_os_type', 'real_os_version') {
				$h->{$g} = $gconfig->{$g};
				}
			$h->{'version'} = &remote_foreign_call($s->{'host'},
					"usermin", "get_usermin_version");

			# Refresh modules and themes
			local @old = map { $_->{'dir'} } ( @{$h->{'modules'}},
							   @{$h->{'themes'}} );
			undef($h->{'modules'});
			local @mods = &remote_foreign_call($s->{'host'},
					"usermin", "list_modules");
			@mods = grep { !$_->{'clone'} } @mods;
			local @themes = &remote_foreign_call($s->{'host'},
					 "usermin", "list_themes");
			local @added;
			foreach $m (@mods, @themes) {
				$idx = &indexof($m->{'dir'}, @old);
				if ($idx < 0) {
					push(@added, $m->{'dir'});
					}
				else {
					splice(@old, $idx, 1);
					}
				}
			$h->{'modules'} = \@mods;
			$h->{'themes'} = \@themes;

			&save_usermin_host($h);
			$rv = [ \@added, \@old, $ud, $gd ];
			}
		else {
			# remove from managed list
			&delete_usermin_host($h);
			$rv = undef;
			}
		print $wh &serialise_variable($rv);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Read back results
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = &server_name($s);
	local $rh = "READ$p";
	local $line = <$rh>;
	local $rv = &unserialise_variable($line);
	close($rh);

	if ($rv && ref($rv)) {
		@added = @{$rv->[0]};
		@old = @{$rv->[1]};
		if (@added && @old) {
			print &text('refresh_1', $d,
				    join(" ", @added),join(" ", @old)),"\n";
			}
		elsif (@added) {
			print &text('refresh_2', $d,
				    join(" ", @added)),"\n";
			}
		elsif (@old) {
			print &text('refresh_3', $d, join(" ", @old)),"\n";
			}
		else {
			print &text('refresh_4', $d),"\n";
			}
		print "<br>\n";
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

