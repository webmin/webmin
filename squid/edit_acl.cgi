#!/usr/local/bin/perl
# edit_acl.cgi
# Display a list of all ACLs and restrictions using them

require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ui_print_header(undef, $text{'eacl_header'}, "", "edit_acl", 0, 0, 0, &restart_button());

$conf = &get_config();
print "<table border cellpadding=5 width=100%><tr>\n";
print "<td rowspan=2 valign=top width=50%>\n";

# List all defined access control directives
@acl = &find_config("acl", $conf);
if (@acl) {
	print &ui_subheading($text{'eacl_acls'});
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
	print "<option value=$t>$acl_types{$t}\n";
	}
print "</select></form>\n";

print "</td><td valign=top width=50%>\n";

# List all HTTP restrictions, based on ACLs
@http = &find_config("http_access", $conf);
if (@http) {
	print &ui_subheading($text{'eacl_pr'});
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
		local $mover;
		if ($hc != @http-1) {
			$mover .= "<a href=\"move_http.cgi?$hc+1\">".
			          "<img src=images/down.gif border=0></a>";
			}
		else {
			$mover .= "<img src=images/gap.gif>";
			}
		if ($hc != 0) {
			$mover .= "<a href=\"move_http.cgi?$hc+-1\">".
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
	print "<a href=http_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
	print &ui_form_end([ [ "delete", $text{'eacl_hdelete'} ] ]);
	}
else {
	print "<b>$text{'eacl_nopr'}</b><p>\n";
	print "<a href=http_access.cgi?new=1>$text{'eacl_addpr'}</a><br>\n";
	}

print "</td></tr><tr><td valign=top width=50%>\n";

# List all ICP restrictions, based on ACLs
@icp = &find_config("icp_access", $conf);
if (@icp) {
	print &ui_subheading($text{'eacl_icpr'});
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
		local $mover;
		if ($hc != @icp-1) {
			$mover .= "<a href=\"move_icp.cgi?$hc+1\">".
			          "<img src=images/down.gif border=0></a>";
			}
		else {
			$mover .= "<img src=images/gap.gif>";
			}
		if ($hc != 0) {
			$mover .= "<a href=\"move_icp.cgi?$hc+-1\">".
			          "<img src=images/up.gif border=0></a>";
			}
		else {
			$mover .= "<img src=images/gap.gif>";
			}
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

print "</td></tr>\n";

if ($squid_version >= 2.5) {
	# Show table of external ACL types
	print "<tr> <td colspan=2>\n";
	print &ui_subheading($text{'eacl_ext'});
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
	print "</td> </tr>\n";
	}

print "</table><p>\n";

&ui_print_footer("", $text{'eacl_return'});

