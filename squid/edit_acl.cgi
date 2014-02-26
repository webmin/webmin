#!/usr/local/bin/perl
# edit_acl.cgi
# Display a list of all ACLs and restrictions using them

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config, %acl_types);
require './squid-lib.pl';
&ReadParse();
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ui_print_header(undef, $text{'eacl_header'}, "", "edit_acl", 0, 0, 0, &restart_button());

my $conf = &get_config();

# Start tabs for various ACL settings
my $prog = "edit_acl.cgi";
my @tabs = ( [ "acls", $text{'eacl_acls'}, $prog."?mode=acls" ],
	     [ "http", $text{'eacl_pr'}, $prog."?mode=http" ],
	     [ "icp", $text{'eacl_icpr'}, $prog."?mode=icp" ] );
if ($squid_version >= 2.5) {
	push(@tabs, [ "external", $text{'eacl_ext'}, $prog."?mode=external" ],
		    [ "reply", $text{'eacl_replypr'}, $prog."?mode=reply" ] );
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "acls", 1);

# List all defined access control directives
print &ui_tabs_start_tab("mode", "acls");
my @acl = &find_config("acl", $conf);
if (@acl) {
	print &ui_columns_start([ $text{'eacl_name'},
				  $text{'eacl_type'},
				  $text{'eacl_match'} ], 100);
	foreach my $a (@acl) {
		my @v = @{$a->{'values'}};
		my @cols;
		push(@cols, &ui_link("acl.cgi?index=$a->{'index'}",
				     &html_escape($v[0])));
		push(@cols, $acl_types{$v[1]});
		if ($v[2] =~ /^"(.*)"$/ || $v[3] =~ /^"(.*)"$/) {
			push(@cols, &text('eacl_file', "<tt>$1</tt>"));
			}
		else {
			push(@cols, &html_escape(join(' ', @v[2..$#v])));
			}
		print &ui_columns_row(\@cols, [ "", "nowrap", "" ]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'eacl_noacls'}</b><p>\n";
	}

# Form to add a new ACL
print &ui_form_start("acl.cgi");
print &ui_submit($text{'eacl_buttcreate'});
print &ui_select("type", undef,
	[ map { [ $_, $acl_types{$_} ] }
	      (sort { $acl_types{$a} cmp $acl_types{$b} } keys %acl_types) ]);
print &ui_form_end();

print &ui_tabs_end_tab();

# List all HTTP restrictions, based on ACLs
print &ui_tabs_start_tab("mode", "http");
my @http = &find_config("http_access", $conf);
if (@http) {
	my @tds = ( "width=5", "width=10%", undef, "width=32" );
	print &ui_form_start("delete_http_accesses.cgi", "post");
	print &ui_links_row([ &ui_link("http_access.cgi?new=1",
				       $text{'eacl_addpr'}) ]);
	print &ui_columns_start([ "",
				  $text{'eacl_act'},
				  $text{'eacl_acls1'},
				  $text{'eacl_move'} ], 100, 0, \@tds);
	my $hc = 0;
	foreach my $h (@http) {
		my @v = @{$h->{'values'}};
		if ($v[0] eq "allow") {
			$v[0] = $text{'eacl_allow'};
			}
		else {
			$v[0] = $text{'eacl_deny'};
			}
		my @cols;
		push(@cols, &ui_link("http_access.cgi?index=$h->{'index'}",
				     $v[0]));
		push(@cols, &html_escape(join(' ', @v[1..$#v])));
		my $mover = &ui_up_down_arrows(
			"move_http.cgi?$hc+-1",
			"move_http.cgi?$hc+1",
			$hc != 0,
			$hc != @http-1
			);
		push(@cols, $mover);
		print &ui_checked_columns_row(\@cols, \@tds, "d",$h->{'index'});
		$hc++;
		}
	print &ui_columns_end();
	print &ui_links_row([ &ui_link("http_access.cgi?new=1",
				       $text{'eacl_addpr'}) ]);
	print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
	}
else {
	print "<b>$text{'eacl_nopr'}</b><p>\n";
	print &ui_links_row([ &ui_link("http_access.cgi?new=1",
				       $text{'eacl_addpr'}) ]);
	}
print &ui_tabs_end_tab();

# List all ICP restrictions, based on ACLs
print &ui_tabs_start_tab("mode", "icp");
my @icp = &find_config("icp_access", $conf);
if (@icp) {
	print &ui_form_start("delete_icp_accesses.cgi", "post");
	my @tds = ( "width=5", "width=10%", undef, "width=32" );
	print &ui_links_row([ &ui_link("icp_access.cgi?new=1",
				       $text{'eacl_addicpr'}) ]);
	print &ui_columns_start([ "",
				  $text{'eacl_act'},
				  $text{'eacl_acls1'},
				  $text{'eacl_move'} ], 100, 0, \@tds);
	my $ic = 0;
	foreach my $i (@icp) {
		my @v = @{$i->{'values'}};
		if ($v[0] eq "allow") {
			$v[0] = $text{'eacl_allow'};
			}
		else {
			$v[0] = $text{'eacl_deny'};
			}
		my @cols;
		push(@cols, &ui_link("icp_access.cgi?index=$i->{'index'}",
				     $v[0]));
		push(@cols, &html_escape(join(' ', @v[1..$#v])));
		my $mover = &ui_up_down_arrows(
			"move_icp.cgi?$ic+-1",
			"move_icp.cgi?$ic+1",
			$ic != 0,
			$ic != @icp-1);
		push(@cols, $mover);
		print &ui_checked_columns_row(\@cols, \@tds, "d",$i->{'index'});
		$ic++;
		}
	print &ui_columns_end();
	print &ui_links_row([ &ui_link("icp_access.cgi?new=1",
				       $text{'eacl_addicpr'}) ]);
	print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
	}
else {
	print "<b>$text{'eacl_noicpr'}</b><p>\n";
	print &ui_links_row([ &ui_link("icp_access.cgi?new=1",
				       $text{'eacl_addicpr'}) ]);
	}
print &ui_tabs_end_tab();

# List all HTTP REPLY restrictions, based on ACLs
if ($squid_version >= 2.5) {
	print &ui_tabs_start_tab("mode", "reply");
	my @http_reply = &find_config("http_reply_access", $conf);
	if (@http_reply) {
		my @tds = ( "width=5", "width=10%", undef, "width=32" );
		print &ui_form_start("delete_http_reply_accesses.cgi", "post");
		print &ui_links_row([ &ui_link("http_reply_access.cgi?new=1",
					       $text{'eacl_addpr'}) ]);
		print &ui_columns_start([ "",
					  $text{'eacl_act'},
					  $text{'eacl_acls1'},
					  $text{'eacl_move'} ], 100, 0, \@tds);
		my $hc = 0;
		foreach my $h (@http_reply) {
			my @v = @{$h->{'values'}};
			if ($v[0] eq "allow") {
				$v[0] = $text{'eacl_allow'};
				}
			else {
				$v[0] = $text{'eacl_deny'};
				}
			my @cols;
			push(@cols, &ui_link("http_reply_access.cgi?index=$h->{'index'}", $v[0]));
			push(@cols, &html_escape(join(' ', @v[1..$#v])));
			my $mover = &ui_up_down_arrows(
				"move_http_reply.cgi?$hc+-1",
				"move_http_reply.cgi?$hc+1",
				$hc != 0,
				$hc != @http_reply-1
				);
			push(@cols, $mover);
			print &ui_checked_columns_row(\@cols, \@tds, "d",
						      $h->{'index'});
			$hc++;
			}
		print &ui_columns_end();
		print &ui_links_row([ &ui_link("http_reply_access.cgi?new=1",
					       $text{'eacl_addpr'}) ]);
		print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
		}
	else {
		print "<b>$text{'eacl_noprr'}</b><p>\n";
		print &ui_links_row([ &ui_link("http_reply_access.cgi?new=1",
					       $text{'eacl_addpr'}) ]);
		}
	print &ui_tabs_end_tab();
	}

if ($squid_version >= 2.5) {
	# Show table of external ACL types
	print &ui_tabs_start_tab("mode", "external");
	my @ext = &find_config("external_acl_type", $conf);
	if (@ext) {
		print &ui_links_row([ &ui_link("edit_ext.cgi?new=1", $text{'eacl_addext'}) ]);
		print &ui_columns_start([ $text{'eacl_cname'},
					  $text{'eacl_format'},
					  $text{'eacl_program'} ], 100);
		foreach my $e (@ext) {
			my $ea = &parse_external($e);
			print &ui_columns_row([
				&ui_link("edit_ext.cgi?index=$e->{'index'}",
					 $ea->{'name'}),
				$ea->{'format'},
				join(" ", $ea->{'program'}, @{$ea->{'args'}})
				]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'eacl_noext'}</b><p>\n";
		}
	print &ui_links_row([ &ui_link("edit_ext.cgi?new=1", $text{'eacl_addext'}) ]);
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("", $text{'eacl_return'});

