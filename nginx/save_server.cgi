#!/usr/local/bin/perl
# Create, update or delete a server block

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %config, %access);
&ReadParse();
&error_setup($text{'server_err'});
if ($in{'new'}) {
	(!defined($access{'create'}) || $access{'create'}) ||
		&error($text{'server_ecannotcreate'});
	}
else {
	$access{'edit'} || &error($text{'server_ecannotedit'});
	}

# Get the current server
&lock_all_config_files();
my $conf = &get_config();
my $http = &find("http", $conf);
my @servers = &find("server", $http);
my $server;
my $old_name;
if ($in{'new'}) {
	$server = { 'name' => 'server',
		    'type' => 1,
		    'words' => [ ],
		    'members' => [ ] };
	$server->{'file'} = &get_add_to_file($in{'server_name'});
	}
else {
	$server = &find_server($in{'id'});
        $server || &error($text{'server_egone'});
	&can_edit_server($server) || &error($text{'server_ecannot'});
	$old_name = &find_value("server_name", $server);
        }

# Check for clash
if ($in{'new'} || $in{'server_name'} ne $old_name) {
	foreach my $c (@servers) {
		my $cname = &find_value("server_name", $c);
		$cname eq $in{'server_name'} &&
			&error($text{'server_eclash'});
		}
	}

my $action;
my $name;
if ($in{'delete'}) {
	$name = &find_value("server_name", $server);
	if ($in{'confirm'}) {
		# Got confirmation, delete it
		&save_directive($http, [ $server ], [ ]);
		$action = 'delete';
		}
	else {
		# Ask for confirmation first
		&ui_print_header(&server_desc($server),
				 $text{'server_edit'}, "");

		print &ui_confirmation_form("save_server.cgi",
			&text('server_rusure',
			      "<tt>".&html_escape($name)."</tt>"),
			[ [ 'id', $in{'id'} ],
			  [ 'delete', 1 ] ],
			[ [ 'confirm', $text{'server_confirm'} ] ],
			);

		&ui_print_footer("edit_server.cgi?id=".&urlize($in{'id'}),
				 $text{'server_return'});
		}
	}
else {
	if ($in{'new'}) {
		# Create a new server object
		&save_directive($http, [ ], [ $server ]);
		$action = 'create';
		}
	else {
		$action = 'modify';
		}

	# Validate and update existing directives, starting with hostname
	# or regexp
	&nginx_text_parse("server_name", $server, undef, '^\S+$', undef, 1);
	$name = $in{'server_name'};

	# Addresses to accept connections on
	# XXX preserve existing args
	my $i = 0;
	my @listen;
	while(defined($in{"ip_def_$i"})) {
		my $def = $in{"ip_def_$i"};
		if ($def == 3) {
			$i++;
			next;
			}
		my $ip;
		if ($def == 0) {
			$ip = $in{"ip_$i"};
			$ip || &error(&text('server_eipmissing', $i+1));
			&to_ipaddress($ip) || &to_ip6address($ip) ||
				&error(&text('server_eip', $i+1, $ip));
			if (&check_ip6address($ip)) {
				$ip = "[$ip]";
				}
			}
		elsif ($def == 2) {
			$ip = "[::]";
			}
	
		# Port number
		$in{"port_$i"} =~ /^\d+$/ ||
			&error(&text('server_eport', $i+1));
		if ($ip && $in{"port_$i"} != 80) {
			$ip .= ":".$in{"port_$i"};
			}
		elsif (!$ip) {
			$ip = $in{"port_$i"};
			}

		# Other random options
		my @words = ( $ip );
		if ($in{"default_$i"}) {
			push(@words, &get_default_server_param());
			}
		if ($in{"ssl_$i"}) {
			push(@words, "ssl");
			}
		if ($in{"http2_$i"}) {
			push(@words, "http2");
			}
		if ($in{"ipv6_$i"}) {
			push(@words, "ipv6only=".$in{"ipv6_$i"});
			}
		push(@listen, { 'name' => 'listen',
				'value' => $words[0],
				'words' => \@words });
		$i++;
		}
	@listen || &error($text{'server_elisten'});
	&save_directive($server, "listen", \@listen);

	if ($in{'new'}) {
		# Add root directory block
		$in{'rootdir'} =~ /^\// || &error($text{'server_erootdir'});
		-d $in{'rootdir'} || &error(&text('server_erootdir2',
						  $in{'rootdir'}));
		&can_directory($in{'rootdir'}) ||
			&error(&text('location_ecannot',
			     "<tt>".&html_escape($in{'rootdir'})."</tt>",
			     "<tt>".&html_escape($access{'root'})."</tt>"));
		&save_directive($server, [ ],
			[ { 'name' => 'location',
			    'words' => [ '/' ],
			    'type' => 1,
			    'members' => [
				{ 'name' => 'root',
				  'words' => [ $in{'rootdir'} ] },
				],
			  } ]);
		&save_directive($server, "root", [ $in{'rootdir'} ]);
		my @extra = &extra_dirs_to_directives($config{'extra_dirs'});
		&save_directive($server, [ ], \@extra) if (@extra);
		}
	}

&flush_config_file_lines();
&unlock_all_config_files();
if ($action eq 'create') {
	&create_server_link($server);
	}
elsif ($action eq 'delete') {
	&delete_server_link($server);
	&delete_server_file_if_empty($server);
	}
if ($action) {
	&webmin_log($action, 'server', $name);
	&redirect("");
	}
