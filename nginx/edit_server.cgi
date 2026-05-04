#!/usr/local/bin/perl
# Show the config for one HTTP server

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();

my $server;
my $can_create = !defined($access{'create'}) || $access{'create'};
if ($in{'new'}) {
	$can_create || &error($text{'server_ecannotcreate'});
	&ui_print_header(undef, $text{'server_create'}, "");
	$server = { 'name' => 'server',
		    'members' => [ ] };
	}
else {
	$server = &find_server($in{'id'});
	$server || &error($text{'server_egone'});
	&can_edit_server($server) || &error($text{'server_ecannot'});
	&ui_print_header(&server_desc($server), $text{'server_edit'}, "");
	}

if ($in{'id'}) {
	# Show icons for server settings types
	print &ui_subheading($text{'server_settings'});
	my @spages = ( $access{'logs'} ? ( "slogs" ) : ( ),
		       "sdocs", "ssl", "fcgi", "sssi", "sgzip", "sproxy",
		       "saccess", "srewrite", );
	&icons_table(
		[ map { "edit_".$_.".cgi?id=".&urlize($in{'id'}) } @spages ],
		[ map { $text{$_."_title"} } @spages ],
		[ map { "images/".$_.".gif" } @spages ],
		);

	# Show table for locations
	print &ui_subheading($text{'server_locations'});
	my @locations = &find("location", $server);
	my @links = ( "<a href='edit_location.cgi?id=".&urlize($in{'id'}).
		      "&new=1'>$text{'server_addloc'}</a>" );
	if (@locations) {
		print &ui_links_row(\@links);
		print &ui_columns_start([ $text{'server_pathloc'},
					  $text{'server_matchtype'},
					  $text{'server_dirloc'},
					  $text{'server_indexloc'},
					  $text{'server_autoloc'} ]);
		foreach my $l (@locations) {
			my $rootdir = &find_value("root", $l);
			my $pp = &find_value("proxy_pass", $l);
			my @indexes = map { @{$_->{'words'}} }
					  &find("index", $l);
			my $auto = &find_value("autoindex", $l);
			my @w = @{$l->{'words'}};
			print &ui_columns_row([
				"<a href='edit_location.cgi?id=".
				  &urlize($in{'id'})."&path=".
				  &urlize($w[$#w])."'>".
				  &html_escape($w[$#w])."</a>",
				&match_desc(@w > 1 ? $w[0] : ""),
				$rootdir ? $rootdir :
				  $pp ? &text('server_pp', "<tt>$pp</tt>") :
				  "<i>$text{'index_noroot'}</i>",
				join(" ", @indexes) ||
				  "<i>$text{'server_noindex'}</i>",
				$auto =~ /on/i ? $text{'yes'} : $text{'no'},
				]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'server_noneloc'}</b><p>\n";
		}
	print &ui_links_row(\@links);
	}

if ($access{'edit'} || ($in{'new'} && $can_create)) {
	# Show form to edit name, IPs and root
	if (!$in{'new'}) {
		print &ui_hr();
		print &ui_subheading($text{'server_server'});
		}
	print &ui_form_start("save_server.cgi", "post");
	print &ui_hidden("id", $in{'id'});
	print &ui_hidden("new", $in{'new'});
	print &ui_table_start($text{'server_header'}, "width=100%", 2);

	# Server name
	print &nginx_text_input("server_name", $server, 70, undef, 1);

	# IP addresses / ports to listen on
	my @listen;
	if ($in{'new'}) {
		@listen = ( &value_to_struct('listen', '80') );
		}
	else {
		@listen = &find("listen", $server);
		}
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
		# XXX disable inputs when disabled
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

	# Root directory (for new hosts)
	if ($in{'new'}) {
		print &ui_table_row($text{'server_rootdir'},
			&ui_filebox("rootdir", undef, 50, 0, undef, undef, 1));
		}

	print &ui_table_end();
	if ($in{'new'}) {
		print &ui_form_end([ [ undef, $text{'create'} ] ]);
		}
	else {
		print &ui_form_end([ [ undef, $text{'save'} ],
				     [ 'delete', $text{'server_delete'} ] ]);
		}
	}

&ui_print_footer("", $text{'index_return'});
