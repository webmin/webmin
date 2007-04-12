#!/usr/local/bin/perl
# add.cgi
# Add or update a server or group from the webmin servers module

require './cfengine-lib.pl';
&foreign_require("servers", "servers-lib.pl");
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

# Get the details of each host
foreach $s (@add) {
	$add_error_msg = undef;
	local $host = { 'id' => $s->{'id'} };
	local $cfe = &remote_foreign_check($s->{'host'}, "cfengine");
	if ($add_error_msg) {
		print "$add_error_msg<p>\n";
		next;
		}
	if (!$cfe) {
		print &text('add_echeck', $s->{'host'}),"<p>\n";
		next;
		}
	&remote_foreign_require($s->{'host'}, "cfengine", "cfengine-lib.pl");
	local $rconfig = &remote_foreign_config($s->{'host'}, "cfengine");
	local $has = &remote_foreign_call($s->{'host'}, "cfengine",
			"has_command", $rconfig->{'cfengine'});
	local $ver;
	if (!$has || !($ver = &cfengine_host_version($s))) {
		print &text('add_ecfengine', $s->{'host'}),"<p>\n";
		next;
		}
	if ($ver !~ /^1\./) {
		print &text('add_eversion', $s->{'host'}, $ver, "1.x"),"<p>\n";
		next;
		}
	local $gconfig = &remote_foreign_config($s->{'host'}, undef);
	foreach $g ('os_type', 'os_version',
		    'real_os_type', 'real_os_version') {
		$host->{$g} = $gconfig->{$g};
		}
	&save_cfengine_host($host);
	print &text('add_ok', &server_name($s), $host->{'real_os_type'},
			      $host->{'real_os_version'}),"<p>\n";
	}
&remote_finished();

&ui_print_footer("list_hosts.cgi", $text{'hosts_return'});


