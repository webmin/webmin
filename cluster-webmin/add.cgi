#!/usr/local/bin/perl
# add.cgi
# Add or update a server or group from the webmin servers module

require './cluster-webmin-lib.pl';
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
	local $webmin = &remote_foreign_check($s->{'host'}, "webmin");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$webmin) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	local $acl = &remote_foreign_check($s->{'host'}, "acl");
	if (!$acl) {
		print &text('add_echeck2', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s->{'host'}, "webmin", "webmin-lib.pl");
	&remote_foreign_require($s->{'host'}, "acl", "acl-lib.pl");
	$host->{'version'} = &remote_foreign_call($s->{'host'}, "webmin",
						  "get_webmin_version");
	if ($host->{'version'} < 0.985) {
		print &text('add_eversion', $s->{'host'}, 0.985),"<p>\n";
		next;
		}
	local $gconfig = &remote_foreign_config($s->{'host'}, undef);
	foreach $g ('os_type', 'os_version',
		    'real_os_type', 'real_os_version') {
		$host->{$g} = $gconfig->{$g};
		}

	local @mods = &remote_foreign_call($s->{'host'}, "webmin",
					   "get_all_module_infos", 1);
	@mods = grep { !$_->{'clone'} } @mods;
	$host->{'modules'} = \@mods;

	local @themes = &remote_foreign_call($s->{'host'}, "webmin",
					     "list_themes");
	$host->{'themes'} = \@themes;

	local @users = &remote_foreign_call($s->{'host'}, "acl", "list_users");
	$host->{'users'} = \@users;

	local @groups = &remote_foreign_call($s->{'host'}, "acl","list_groups");
	$host->{'groups'} = \@groups;

	&save_webmin_host($host);
	print &text('add_ok', &server_name($s), scalar(@mods), scalar(@themes),
		    scalar(@users), scalar(@groups)),"<p>\n";
	}
&remote_finished();

&ui_print_footer("", $text{'index_return'});


