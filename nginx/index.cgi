#!/usr/local/bin/perl
# Show Nginx server blocks and global config

use strict;
use warnings;
require './nginx-lib.pl';
my $ver = &get_nginx_version();
our (%text, %module_info, %config, $module_name, %access, %in);

my $action_links = -r $config{'nginx_config'} &&
		   &has_command($config{'nginx_cmd'}) ?
		   &nginx_action_links() : "";
&ui_print_header($ver ? &text('index_version', $ver) : undef,
		 $module_info{'desc'}, "", undef, 1, 1, undef,
		 $action_links);

# Check config
if (!-r $config{'nginx_config'}) {
	&ui_print_endpage(
		&text('index_econfig', "<tt>$config{'nginx_config'}</tt>",
		"../config.cgi?$module_name"));
	}
if (!&has_command($config{'nginx_cmd'})) {
	&ui_print_endpage(
		&text('index_ecmd', "<tt>$config{'nginx_cmd'}</tt>",
		"../config.cgi?$module_name"));
	}

my $conf = &get_config();
my $http = &find("http", $conf);
if (!$http) {
	&ui_print_endpage(
		&text('index_ehttp', "<tt>$config{'nginx_config'}</tt>"));
	}

my @tabs = ( );
my $can_create = !defined($access{'create'}) || $access{'create'};
push(@tabs, [ "global", $text{'index_tabglobal'}, "index.cgi?mode=global" ])
	if ($access{'global'});
push(@tabs, [ "list", $text{'index_tablist'}, "index.cgi?mode=list" ]);
push(@tabs, [ "create", $text{'index_tabcreate'}, "index.cgi?mode=create" ])
	if ($can_create);
my $mode = $in{'mode'} || "list";
my %tab = map { $_->[0], 1 } @tabs;
$mode = "list" if (!$tab{$mode});
print &ui_tabs_start(\@tabs, "mode", $mode, 1);

if ($access{'global'}) {
	# Show icons for global config types
	print &ui_tabs_start_tab("mode", "global");
	my @gpages = ( "net", "mime", "logs", "docs", "ssi", "misc", "manual" );
	&icons_table(
		[ map { "edit_".$_.".cgi" } @gpages ],
		[ map { $text{$_."_title"} } @gpages ],
		[ map { "images/".$_.".gif" } @gpages ],
		);
	print &ui_tabs_end_tab();
	}

# Show list of server blocks
print &ui_tabs_start_tab("mode", "list");
my @allservers = &find("server", $http);
my $can_files = &can_manage_server_files();
my @add_to_files = $can_files ? &get_add_to_files() : ( );
my %add_to_file = map { $_, 1 } @add_to_files;
my @rows = &get_server_list_rows($http);
if (@rows) {
	my $can_delete = $access{'edit'};
	my $has_proxy;
	foreach my $r (@rows) {
		my (undef, $proxy) = &server_root_proxy_state($r->{'server'});
		$has_proxy ||= $proxy;
		}
	my @heads = ( $can_delete ? ( "" ) : ( ),
		      $text{'index_name'},
		      $text{'index_ip'},
		      $text{'index_port'},
		      $text{'index_root'},
		      $has_proxy ? ( $text{'index_proxytarget'} ) : ( ),
		      $can_files ? ( $text{'index_status'} ) : ( ),
		      $text{'index_url'} );
	my @data;
	foreach my $r (@rows) {
		my $s = $r->{'server'};
		my $name = &find_value("server_name", $s);
		$name ||= "";
		my $default = &is_default_server_block($s);
		my $showname = !$default ?
			&html_escape($name) : $text{'default_server_block'};
		my $id = &server_id($s);
		my $name_sort = ($default ? "0 " : "1 ").
				lc($default ? $text{'default_server_block'} : $name);
		my $name_sort_attr = &quote_escape($name_sort);
		my $shownamelink = $r->{'active'} ?
			"<a href='edit_server.cgi?id=".
			  &urlize($id)."'>".$showname."</a>" :
			$showname;

		# Extract all IPs and ports from listen directives
		my (@ips, @ports);
		foreach my $l (&find_value("listen", $s)) {
			my ($ip, $port) = &split_ip_port($l);
			$ip ||= $text{'index_any'};
			$ip = $text{'index_any6'} if ($ip eq "::");
			push(@ips, $ip);
			push(@ports, $port);
			}

		my @cols;
		my $status = "";
		if ($can_files) {
			if ($add_to_file{$r->{'file'}}) {
				my $enabled = &server_file_enabled($r->{'file'});
				$status = $enabled ? $text{'index_enabled'} :
						     $text{'index_disabled'};
				}
			}
		push(@cols, { 'type' => 'string',
			      'value' => $shownamelink,
			      'td' => "data-sort=\"$name_sort_attr\" ".
				      "data-order=\"$name_sort_attr\"" });
		push(@cols,
			join("<br>", @ips),
			join("<br>", @ports),
			&server_root_summary($s) );
		push(@cols, &server_proxy_summary($s)) if ($has_proxy);
		push(@cols, $status) if ($can_files);
		my $url = $r->{'active'} ? &server_url($s) : undef;
		push(@cols, $url ? &ui_link(&quote_escape($url),
			$text{'index_view'}, undef,
			'target="_blank" rel="noopener noreferrer"') : "");
		if ($can_delete && $r->{'active'} && !$default) {
			unshift(@cols, { 'type' => 'checkbox',
					 'name' => 'd',
					 'value' => $id });
			}
		elsif ($can_delete && $can_files && !$r->{'active'} &&
		       !$default && $add_to_file{$r->{'file'}}) {
			unshift(@cols, { 'type' => 'checkbox',
					 'name' => 'd',
					 'value' => "file\t".$r->{'file'}.
						    "\t".$s->{'line'} });
			}
		elsif ($can_delete) {
			unshift(@cols, "");
			}
		push(@data, \@cols);
		}
	if ($can_delete) {
		my $list_form = "server_blocks_form";
		my $has_checkbox = grep {
			ref($_->[0]) && $_->[0]->{'type'} eq 'checkbox'
			} @data;
		my $links = $has_checkbox ?
			&ui_links_row([ &select_all_link("d", 0),
					&select_invert_link("d", 0) ]) : "";
		my @left_buttons = ( [ "delete", $text{'index_delete'} ] );
		my @right_buttons = $can_files ?
			( [ "toggle", $text{'index_toggle'}, undef, undef,
			    "form=\"$list_form\"" ] ) : ( );
		print &ui_form_start("delete_servers.cgi", "post", undef,
				     "id='$list_form'");
		print $links;
		print &ui_columns_table(\@heads, 100, \@data);
		print $links;
		print &ui_form_end_side_by_side($list_form,
						\@left_buttons,
						\@right_buttons);
		}
	else {
		print &ui_columns_table(\@heads, 100, \@data);
		}
	}
elsif (@allservers) {
	print "<b>$text{'index_noneaccess'}</b><p>\n";
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}
print &ui_tabs_end_tab();

if ($can_create) {
	print &ui_tabs_start_tab("mode", "create");
	print &ui_form_start("save_server.cgi", "post");
	print &ui_hidden("new", 1);
	print &ui_table_start($text{'server_create'}, "width=100%", 2);

	# Server name
	my $server = { 'name' => 'server',
		       'members' => [ ] };
	print &nginx_text_input("server_name", $server, 70, undef, 1);

	# IP addresses / ports to listen on
	my @listen = ( &value_to_struct('listen', '80') );
	my $table = &ui_columns_start([ $text{'server_ip'},
					$text{'server_port'},
					$text{'server_default'},
					$text{'server_ssl'},
					$text{'server_http2'},
					$text{'server_ipv6'} ], 100);
	my $i = 0;
	my @tds = ( "valign=top", "valign=top", "valign=top",
		    "valign=top", "valign=top" );
	foreach my $l (@listen, { 'words' => [ ] }) {
		my @w = @{$l->{'words'}};
		my ($ip, $port) = @w ? &split_ip_port(shift(@w)) : ( );
		my ($default, $ssl, $http2, $ipv6) = (0, 0, 0, "");
		foreach my $w (@w) {
			if ($w eq "default" || $w eq "default_server") {
				$default = 1;
				}
			elsif ($w eq "ssl") {
				$ssl = 1;
				}
			elsif ($w eq "http2") {
				$http2 = 1;
				}
			elsif ($w =~ /^ipv6only=(\S+)/) {
				$ipv6 = lc($1);
				}
			}
		my $ipmode = !$ip && !$port ? 3 :
			     !$ip ? 1 : $ip eq "::" ? 2 : 0;
		$table .= &ui_columns_row([
			&ui_radio("ip_def_$i", $ipmode,
				  [ [ 3, $text{'server_none'}."<br>" ],
				    [ 1, $text{'server_ipany'}."<br>" ],
				    [ 2, $text{'server_ip6any'}."<br>" ],
				    [ 0, $text{'server_ipaddr'} ] ])." ".
			  &ui_textbox("ip_$i", $ipmode == 0 ? $ip : "", 30),
			&ui_textbox("port_$i", $port, 6),
			&ui_select("default_$i", $default,
			   [ [ 0, $text{'no'} ], [ 1, $text{'yes'} ] ]),
			&ui_select("ssl_$i", $ssl,
			   [ [ 0, $text{'no'} ], [ 1, $text{'yes'} ] ]),
			&ui_select("http2_$i", $http2,
			   [ [ 0, $text{'no'} ], [ 1, $text{'yes'} ] ]),
			&ui_select("ipv6_$i", $ipv6,
			   [ [ "", $text{'server_auto'} ],
			     [ "off", $text{'no'} ], [ "on", $text{'yes'} ] ]),
			], \@tds);
		$i++;
		}
	$table .= &ui_columns_end();
	print &ui_table_row($text{'server_listen'}, $table);

	# Root directory
	print &ui_table_row($text{'server_rootdir'},
		&ui_filebox("rootdir", undef, 50, 0, undef, undef, 1));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});
