#!/usr/local/bin/perl
# list_hosts.cgi
# Display host access records

require './postgresql-lib.pl';
$access{'users'} || &error($text{'host_ecannot'});
&ui_print_header(undef, $text{'host_title'}, "", "list_hosts");

print "$text{'host_desc'}<p>\n";

$v = &get_postgresql_version();
@hosts = &get_hba_config($v);
print &ui_form_start("delete_hosts.cgi", "post");
@rowlinks = ( &select_all_link("d", 0),
	      &select_invert_link("d", 0),
	      &ui_link("edit_host.cgi?new=1",$text{'host_add'}) );
print &ui_links_row(\@rowlinks);
if ($v >= 7.3) {
	@tds = ( "width=5", "width=25%", "width=25%", "width=25%",
		 "width=25%", "width=16" );
	}
else {
	@tds = ( "width=5", "width=33%", "width=33%", "width=33%", "width=16" );
	}
print &ui_columns_start([ "",
			  $text{'host_address'},
			  $text{'host_db'},
			  $v >= 7.3 ? ( $text{'host_user'} ) : ( ),
			  $text{'host_auth'},
			  $text{'host_move'} ], 100, 0, \@tds);
foreach $h (@hosts) {
	local @cols;
	local $ssl = $h->{'type'} eq 'hostssl' ? " ($text{'host_viassl'})" : "";
	push(@cols, "<a href='edit_host.cgi?idx=$h->{'index'}'>".
	   &html_escape(
	      $h->{'type'} eq 'local' ? $text{'host_local'} :
	      $h->{'netmask'} eq '255.255.255.255' ? $h->{'address'}.$ssl :
	      $h->{'netmask'} eq '0.0.0.0' ? $text{'host_any'}.$ssl :
	      $h->{'cidr'} ne "" ? $h->{'address'}.'/'.$h->{'cidr'}.$ssl :
	      $h->{'address'}.'/'.$h->{'netmask'}.$ssl)."</a>");
	push(@cols, $h->{'db'} eq 'all' ? $text{'host_all'} :
		    $h->{'db'} eq 'sameuser' ? $text{'host_same'} :
					       $h->{'db'});
	if ($v >= 7.3) {
		push(@cols, $h->{'user'} eq 'all' ? $text{'host_uall'}
						   : $h->{'user'});
		}
	push(@cols, $text{"host_$h->{'auth'}"} || $h->{'auth'});
	local $mover;
	if ($h eq $hosts[@hosts-1]) {
		$mover .= "<img src=images/gap.gif>";
		}
	else {
		$mover .= "<a href='down.cgi?idx=$h->{'index'}'>".
		          "<img src=images/down.gif border=0></a>";
		}
	if ($h eq $hosts[0]) {
		$mover .= "<img src=images/gap.gif>";
		}
	else {
		$mover .= "<a href='up.cgi?idx=$h->{'index'}'>".
		          "<img src=images/up.gif border=0></a>";
		}
	push(@cols, $mover);
	print &ui_checked_columns_row(\@cols, \@tds, "d", $h->{'index'});
	}
print &ui_columns_end();
print &ui_links_row(\@rowlinks);
print &ui_form_end([ [ "delete", $text{'user_delete'} ] ]);

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("edit_manual.cgi", $text{'host_manual'},
		      $text{'host_manualdesc'});
print &ui_buttons_end();

&ui_print_footer("", $text{'index_return'});

