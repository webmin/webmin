#!/usr/local/bin/perl
# add.cgi
# Add or update a server or group from the webmin servers module

require './cluster-usermin-lib.pl';
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

# Setup error handler for down hosts
sub add_error
{
$add_error_msg = join("", @_);
}
&remote_error_setup(\&add_error);

# Get the modules and themes for each host
foreach $s (@add) {
	$add_error_msg = undef;
	local $host = { 'id' => $s->{'id'} };
	local $usermin = &remote_foreign_check($s->{'host'}, "usermin");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$usermin) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s->{'host'}, "usermin", "usermin-lib.pl");
	$host->{'version'} = &remote_foreign_call($s->{'host'}, "usermin",
						  "get_usermin_version");
	if (!$host->{'version'}) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	local $gconfig = &remote_foreign_config($s->{'host'}, undef);
	foreach $g ('os_type', 'os_version',
		    'real_os_type', 'real_os_version') {
		$host->{$g} = $gconfig->{$g};
		}

	local @mods = &remote_foreign_call($s->{'host'}, "usermin",
					   "list_modules");
	@mods = grep { !$_->{'clone'} } @mods;
	$host->{'modules'} = \@mods;

	local @themes = &remote_foreign_call($s->{'host'}, "usermin",
					     "list_themes");
	$host->{'themes'} = \@themes;

	&save_usermin_host($host);
	print &text('add_ok', &server_name($s), scalar(@mods),
			      scalar(@themes)),"<p>\n";
	}
&remote_finished();

&ui_print_footer("", $text{'index_return'});


