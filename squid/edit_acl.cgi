#!/usr/local/bin/perl
# edit_acl.cgi
# Display a list of all ACLs and restrictions using them

require './squid-lib.pl';
&ReadParse();
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ui_print_header(undef, $text{'eacl_header'}, "", "edit_acl", 0, 0, 0, &restart_button());
$conf = &get_config();

# Start tabs for various ACL settings
$prog = "edit_acl.cgi";
@tabs = ( [ "acls", $text{'eacl_acls'}, $prog."?mode=acls" ],
	  [ "http", $text{'eacl_pr'}, $prog."?mode=http" ],
	  [ "icp", $text{'eacl_icpr'}, $prog."?mode=icp" ] );
if ($squid_version >= 2.5) {
	push(@tabs, [ "external", $text{'eacl_ext'}, $prog."?mode=external" ],
		    [ "reply", $text{'eacl_replypr'}, $prog."?mode=reply" ] );
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || "acls", 1);

# List all defined access control directives
print &ui_tabs_start_tab("mode", "acls");
@acl = &find_config("acl", $conf);
if (@acl) {
	print &ui_columns_start([ $text{'eacl_name'},
				  $text{'eacl_type'},
				  $text{'eacl_match'} ], 100);
	foreach $a (@acl) {
		@v = @{$a->{'values'}};
		local @cols;
		push(@cols, "<a href=\"acl.cgi?index=$a->{'index'}\">".
			    &html_escape($v[0])."</a>");
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
print "<form action=acl.cgi>\n";
print "<input type=submit value=\"$text{'eacl_buttcreate'}\">\n";
print "<select name=type>\n";
foreach $t (sort { $acl_types{$a} cmp $acl_types{$b} } keys %acl_types) {
	print "<option value=$t>$acl_types{$t}</option>\n";
	}
print "</select></form>\n";
print &ui_tabs_end_tab();

# List all HTTP restrictions, based on ACLs
print &ui_tabs_start_tab("mode", "http");
@http = &find_config("http_access", $conf);
if (@http) {
	@tds = ( "width=5", "width=10%", undef, "width=32" );
	print &ui_form_start("delete_http_accesses.cgi", "post");
	print "<a href=http_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
	print &ui_columns_start([ "",
				  $text{'eacl_act'},
				  $text{'eacl_acls1'},
				  $text{'eacl_move'} ], 100, 0, \@tds);
	$hc = 0;
	foreach $h (@http) {
		@v = @{$h->{'values'}};
		if ($v[0] eq "allow") {
			$v[0] = $text{'eacl_allow'};
			}
		else {
			$v[0] = $text{'eacl_deny'};
			}
		local @cols;
		push(@cols, "<a href=\"http_access.cgi?index=$h->{'index'}\">".
			    "$v[0]</a>");
		push(@cols, &html_escape(join(' ', @v[1..$#v])));
		local $mover = &ui_up_down_arrows(
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
	print "<a href=http_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
	print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
	}
else {
	print "<b>$text{'eacl_nopr'}</b><p>\n";
	print "<a href=http_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
	}
print &ui_tabs_end_tab();

# List all ICP restrictions, based on ACLs
print &ui_tabs_start_tab("mode", "icp");
@icp = &find_config("icp_access", $conf);
if (@icp) {
	print &ui_form_start("delete_icp_accesses.cgi", "post");
	@tds = ( "width=5", "width=10%", undef, "width=32" );
	print "<a href=icp_access.cgi?new=1>$text{'eacl_addicpr'}</a><br>\n";
	print &ui_columns_start([ "",
				  $text{'eacl_act'},
				  $text{'eacl_acls1'},
				  $text{'eacl_move'} ], 100, 0, \@tds);
	$ic = 0;
	foreach $i (@icp) {
		@v = @{$i->{'values'}};
		if ($v[0] eq "allow") {
			$v[0] = $text{'eacl_allow'};
			}
		else {
			$v[0] = $text{'eacl_deny'};
			}
		local @cols;
		push(@cols, "<a href=\"icp_access.cgi?index=$i->{'index'}\">".
			    "$v[0]</a>");
		push(@cols, &html_escape(join(' ', @v[1..$#v])));
		local $mover = &ui_up_down_arrows(
			"move_icp.cgi?$ic+-1",
			"move_icp.cgi?$ic+1",
			$ic != 0,
			$ic != @icp-1);
		push(@cols, $mover);
		print &ui_checked_columns_row(\@cols, \@tds, "d",$i->{'index'});
		$ic++;
		}
	print &ui_columns_end();
	print "<a href=icp_access.cgi?new=1>$text{'eacl_addicpr'}</a><br>\n";
	print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
	}
else {
	print "<b>$text{'eacl_noicpr'}</b><p>\n";
	print "<a href=icp_access.cgi?new=1>$text{'eacl_addicpr'}</a><br>\n";
	}
print &ui_tabs_end_tab();

# List all HTTP REPLY restrictions, based on ACLs
if ($squid_version >= 2.5) {
	print &ui_tabs_start_tab("mode", "reply");
	@http_reply = &find_config("http_reply_access", $conf);
	if (@http_reply) {
		@tds = ( "width=5", "width=10%", undef, "width=32" );
		print &ui_form_start("delete_http_reply_accesses.cgi", "post");
		print "<a href=http_reply_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
		print &ui_columns_start([ "",
					  $text{'eacl_act'},
					  $text{'eacl_acls1'},
					  $text{'eacl_move'} ], 100, 0, \@tds);
		$hc = 0;
		foreach $h (@http_reply) {
			@v = @{$h->{'values'}};
			if ($v[0] eq "allow") {
				$v[0] = $text{'eacl_allow'};
				}
			else {
				$v[0] = $text{'eacl_deny'};
				}
			local @cols;
			push(@cols, "<a href=\"http_reply_access.cgi?index=$h->{'index'}\">".
				    "$v[0]</a>");
			push(@cols, &html_escape(join(' ', @v[1..$#v])));
			local $mover;
			if ($hc != @http_reply-1) {
				$mover .= "<a href=\"move_http_reply.cgi?$hc+1\">".
					  "<img src=images/down.gif border=0></a>";
				}
			else {
				$mover .= "<img src=images/gap.gif>";
				}
			if ($hc != 0) {
				$mover .= "<a href=\"move_http_reply.cgi?$hc+-1\">".
					  "<img src=images/up.gif border=0></a>";
				}
			else {
				$mover .= "<img src=images/gap.gif>";
				}
			push(@cols, $mover);
			print &ui_checked_columns_row(\@cols, \@tds, "d",$h->{'index'});
			$hc++;
			}
		print &ui_columns_end();
		print "<a href=http_reply_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
		print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
		}
	else {
		print "<b>$text{'eacl_noprr'}</b><p>\n";
		print "<a href=http_reply_access.cgi?new=1>$text{'eacl_addprr'}</a><br>\n";
		}
	print &ui_tabs_end_tab();
	}

if ($squid_version >= 2.5) {
	# Show table of external ACL types
	print &ui_tabs_start_tab("mode", "external");
	@ext = &find_config("external_acl_type", $conf);
	if (@ext) {
		print &ui_columns_start([ $text{'eacl_cname'},
					  $text{'eacl_format'},
					  $text{'eacl_program'} ], 100);
		foreach $e (@ext) {
			$ea = &parse_external($e);
			print &ui_columns_row([
				"<a href='edit_ext.cgi?index=$e->{'index'}'>".
			         "$ea->{'name'}</a>",
				$ea->{'format'},
				join(" ", $ea->{'program'}, @{$ea->{'args'}})
				]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'eacl_noext'}</b><p>\n";
		}
	print "<a href=edit_ext.cgi?new=1>$text{'eacl_addext'}</a>\n";
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("", $text{'eacl_return'});

