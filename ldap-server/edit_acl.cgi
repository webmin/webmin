#!/usr/local/bin/perl
# List all access control settings from ldap server config

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'acl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'acl_title'}, "", "acl");

# Get ACLs
if (&get_config_type() == 1) {
	$conf = &get_config();
	@access = &find("access", $conf);
	$hasorder = 0;
	}
else {
	$defdb = &get_default_db();
	$conf = &get_ldif_config();
	@access = &find_ldif("olcAccess", $conf, $defdb);
	@access = sort { 
		$pa = &parse_ldap_access($a);
		$pb = &parse_ldap_access($b);
		$pa->{'order'} <=> $pb->{'order'} } @access;
	$hasorder = 1;
	}

@crlinks = ( &ui_link("acl_form.cgi?new=1",$text{'acl_add'}) );
if (@access) {
	# Show table of ACLs
	print &ui_form_start("delete_acls.cgi", "post");
	@links = ( &select_all_link("d"), &select_invert_link("d"), @crlinks );
	print &ui_links_row(\@links);
	@tds = ( "width=5", "width=30%", "width=65%", "width=5%" );
	print &ui_columns_start([ "",
				  $text{'acl_what'},
				  $text{'acl_who'},
				  $hasorder ? ( $text{'acl_order'} ) : ( ),
				  $text{'acl_move'} ],
				100, 0, \@tds);
	$i = 0;
	foreach $a (@access) {
		$mover = &ui_up_down_arrows(
			"up_acl.cgi?idx=$i",
			"down_acl.cgi?idx=$i",
			$i > 0,
			$i < @access-1);
		$p = &parse_ldap_access($a);
		print &ui_checked_columns_row([
			&ui_link("acl_form.cgi?idx=$i",$p->{'whatdesc'}),
			$p->{'bydesc'},
			$hasorder ? ( $p->{'order'} ) : ( ),
			$mover,
			], \@tds, "d", $i);
		$i++;
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'acl_delete'} ] ]);
	}
else {
	# None yet, meaning defaults
	print "<b>$text{'acl_none'}</b><p>\n";
	print &ui_links_row(\@crlinks);
	}

&ui_print_footer("", $text{'index_return'});

