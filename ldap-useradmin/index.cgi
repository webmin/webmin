#!/usr/local/bin/perl
# index.cgi
# List all LDAP users for editing

require './ldap-useradmin-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", "intro", 1, 1);
&useradmin::load_theme_library();	# So that ui functions work

# Make sure the LDAP NSS client config file exists, or the needed information
# has been provided
if ($config{'auth_ldap'}) {
	if (!-r $config{'auth_ldap'}) {
		print &text('index_econfig',
		    "<tt>$config{'auth_ldap'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	$nss = &get_nss_config();
	if ($nss->{'pidfile'} || $nss->{'directory'}) {
		print &text('index_econfig2',
		    "<tt>$config{'auth_ldap'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}
else {
	if (!$config{'ldap_host'} || !$config{'login'} || !$config{'pass'} ||
	    !$config{'user_base'} || !$config{'group_base'}) {
		print &text('index_ehost',
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# Make sure the LDAP Perl module is installed, and if not offer to install
if (!$got_net_ldap) {
	local @needs;
	foreach $m ("Convert::ASN1", "Net::LDAP") {
		eval "use $m";
		push(@needs, $m) if ($@);
		}
	$missing = &urlize(join(" ", @needs));
	print &text('index_eperl', "<tt>$missing</tt>",
		    "/cpan/download.cgi?source=3&cpan=$missing&mode=2&".
		    "return=/$module_name/&returndesc=".
		    &urlize($text{'index_return'})),"<p>\n";
	print "$text{'index_eperl2'}\n";
	print "<pre>$net_ldap_error</pre>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Try to login .. may fail
$ldap = &ldap_connect(1);
if (!ref($ldap)) {
	print &text('index_eldap', $ldap,
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

if ($config{'imap_host'}) {
	# Make sure the IMAP Perl module is installed, and if not offer
	# to install
	if (!$got_net_imap) {
		print &text('index_eperl', "<tt>Net::IMAP</tt>",
			  "/cpan/download.cgi?source=3&cpan=Net::IMAP&mode=2&".
			  "return=/$module_name/&returndesc=".
			  &urlize($text{'index_return'})),"<p>\n";
		print "$text{'index_eperl2'}\n";
		print "<pre>$net_imap_error</pre>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}

	# Try to connect to the IMAP server
	$imap = &imap_connect(1);
	if (!ref($imap)) {
		print &text('index_eimap', $imap,
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# If using MD5, make sure needed perl modules or programs are installed
if ($config{'md5'} == 1) {
	# Check if MD5 perl module is installed, and offer to install
	&foreign_require("useradmin", "user-lib.pl");
	if ($err = &useradmin::check_md5()) {
		print &text('index_emd5',
			    "../config.cgi?$module_name",
			    "<tt>$err</tt>",
			    "../cpan/download.cgi?source=3&cpan=Digest::MD5&mode=2&return=/$module_name/&returndesc=".&urlize($text{'index_return'})),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}
elsif ($config{'md5'} == 3) {
	# Check if slappasswd is installed
	if (!&has_command($config{'slappasswd'})) {
		print &text('index_eslappasswd',
			    "../config.cgi?$module_name",
			    "<tt>$config{'slappasswd'}</tt>"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}

# Count the number of users and groups
$base = &get_user_base();
$rv = $ldap->search(base => $base,
		    filter => '(objectClass=posixAccount)',
		    sizelimit => $mconfig{'display_max'}+1);
$ucount = $rv->count;
$base = &get_group_base();
$rv = $ldap->search(base => $base,
		    filter => '(objectClass=posixGroup)',
		    sizelimit => $mconfig{'display_max'}+1);
$gcount = $rv->count;

# Get the list of users and groups
if ($ucount <= $mconfig{'display_max'}) {
	@allulist = &list_users();
	@ulist = &useradmin::list_allowed_users(\%access, \@allulist);
	}
if ($gcount <= $mconfig{'display_max'}) {
	@allglist = &list_groups();
	@glist = &useradmin::list_allowed_groups(\%access, \@allglist);
	}

# Build links for adding users
@links = ( );
if ($access{'ucreate'}) {
	push(@links,
	     "<a href='edit_user.cgi?new=1'>$text{'index_uadd'}</a>");
	}
if ($access{'batch'}) {
	push(@links, 
	     "<a href=\"batch_form.cgi\">$text{'index_batch'}</a>");
	}

# Show users list header
if ($ucount || $access{'ucreate'}) {
	print "<a name=users></a>\n";
	print "<table width=100% cellpadding=0 cellspacing=0><tr>\n";
	print "<td>".&ui_subheading($text{'index_users'})."</td>\n";
	if ($gcount || $access{'gcreate'}) {
		print "<td align=right valign=top>",
		      "<a href=#groups>$text{'index_gjump'}</a></td>\n";
		}
	print "</tr></table>\n";
	}

$form = 0;
if ($ucount > $mconfig{'display_max'}) {
	# Show user search form
	print "<b>$text{'index_toomany'}</b><p>\n";
	print "<form action=search_user.cgi>\n";
	print "<b>$text{'index_find'}</b> <select name=field>\n";
	print "<option value=uid selected>$text{'user'}\n";
	print "<option value=cn>$text{'real'}\n";
	print "<option value=loginShell>$text{'shell'}\n";
	print "<option value=homeDirectory>$text{'home'}\n";
	print "<option value=uidNumber>$text{'uid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=1>$text{'index_contains'}\n";
	print "<option value=2>$text{'index_nequals'}\n";
	print "<option value=3>$text{'index_ncontains'}\n";
	print "<option value=6>$text{'index_lower'}\n";
	print "<option value=7>$text{'index_higher'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form>\n";
	print &ui_links_row(\@links);
	}
elsif (@ulist) {
	# Show table of all users
	@ulist = &useradmin::sort_users(\@ulist, $mconfig{'sort_mode'});
	@left = grep { !/batch_form|export_form/ } @links;
	@right = grep { /batch_form|export_form/ } @links;
	&useradmin::users_table(\@ulist, $form++, 1, 0, \@left, \@right);
	}
else {
	# No users
	$base = &get_user_base();
	print "<b>",&text('index_unone', "<tt>$base</tt>"),"</b><p>\n";
	print &ui_links_row(\@links);
	}

# Show groups header
if ($gcount || $access{'gcreate'}) {
	print "<hr>\n";
	print "<a name=groups></a>\n";
	print "<table width=100% cellpadding=0 cellspacing=0><tr>\n";
	print "<td>".&ui_subheading($text{'index_groups'})."</td>\n";
	if ($ucount || $access{'ucreate'}) {
		print "<td align=right valign=top>",
		      "<a href=#users>$text{'index_ujump'}</a></td>\n";
		}
	print "</tr></table>\n";
	}

# Get the list of groups
@links = ( );
if ($access{'gcreate'}) {
	push(@links, "<a href='edit_group.cgi?new=1'>$text{'index_gadd'}</a>");
	}
if ($gcount > $mconfig{'display_max'}) {
	# Show group search form
	print "<b>$text{'index_gtoomany'}</b><br>\n";
	print "<form action=search_group.cgi>\n";
	print "<b>$text{'index_gfind'}</b> <select name=field>\n";
	print "<option value=cn selected>$text{'gedit_group'}\n";
	print "<option value=memberUid>$text{'gedit_members'}\n";
	print "<option value=gidNumber>$text{'gedit_gid'}\n";
	print "</select> <select name=match>\n";
	print "<option value=0 checked>$text{'index_equals'}\n";
	print "<option value=1>$text{'index_contains'}\n";
	print "<option value=2>$text{'index_nequals'}\n";
	print "<option value=3>$text{'index_ncontains'}\n";
	print "<option value=6>$text{'index_lower'}\n";
	print "<option value=7>$text{'index_higher'}\n";
	print "</select> <input name=what size=15>&nbsp;&nbsp;\n";
	print "<input type=submit value=\"$text{'find'}\"></form>\n";
	print "<br>\n";
	print &ui_links_row(\@links);
	}
elsif (@glist) {
	# Show table of all groups
	@glist = &useradmin::sort_groups(\@glist, $mconfig{'sort_mode'});
	&useradmin::groups_table(\@glist, $form++, 0, \@links);
	}
elsif ($access{'gcreate'} || !@allglist) {
	# Show none message
	$base = &get_group_base();
	print "<b>",&text('index_gnone', "<tt>$base</tt>"),"</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("/", $text{'index'});

