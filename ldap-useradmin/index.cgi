#!/usr/local/bin/perl
# index.cgi
# List all LDAP users for editing

require './ldap-useradmin-lib.pl';
&ui_print_header(undef, $module_info{'desc'}, "", "intro", 1, 1);
&useradmin::load_theme_library();	# So that ui functions work
&ReadParse();

# Make sure the LDAP Perl module is installed, and if not offer to install
if (!$got_net_ldap) {
	local @needs;
	foreach $m ("Convert::ASN1", "Net::LDAP") {
		eval "use $m";
		push(@needs, $m) if ($@);
		}
	$missing = &html_escape(join(" ", @needs));
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

# Make sure we can get the schema
$schema = $ldap->schema();
if (!$schema) {
	print &text('index_eschema', '../ldap-server/'),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Make sure the LDAP bases are set or available
if (!&get_user_base() || !&get_group_base()) {
	print &text('index_ebase',
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
elsif ($config{'md5'} == 3 || $config{'md5'} == 4) {
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
		    filter => &user_filter(),
		    sizelimit => $mconfig{'display_max'}+1);
$ucount = $rv->count;
$base = &get_group_base();
$rv = $ldap->search(base => $base,
		    filter => &group_filter(),
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

# Start of tabs, based on what can be edited
@tabs = ( );
if ($ucount || $access{'ucreate'}) {
        push(@tabs, [ "users", $text{'index_users'},
                      "index.cgi?mode=users" ]);
        $can_users = 1;
	}
if ($gcount || $access{'gcreate'}) {
        push(@tabs, [ "groups", $text{'index_groups'},
                      "index.cgi?mode=groups" ]);
        $can_groups = 1;
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

# Start of users tab
if ($can_users) {
        print &ui_tabs_start_tab("mode", "users");
        }

# Build links for adding users
@links = ( );
if ($access{'ucreate'}) {
	push(@links,
	     &ui_link("edit_user.cgi?new=1",$text{'index_uadd'}));
	}
if ($access{'batch'}) {
	push(@links, 
	     "<a href=\"batch_form.cgi\">$text{'index_batch'}</a>");
	}

$form = 0;
if ($ucount > $mconfig{'display_max'}) {
	# Show user search form
        print "<b>$text{'index_toomany'}</b><p>\n";
        print &ui_form_start("search_user.cgi");
        print &ui_table_start($text{'index_usheader'}, undef, 2);

        # Field to search
        print &ui_table_row($text{'index_find'},
                &ui_select("field", "uid",
                           [ [ "uid", $text{'user'} ],
                             [ "cn", $text{'real'} ],
                             [ "loginShell", $text{'shell'} ],
                             [ "homeDirectory", $text{'home'} ],
                             [ "uidNumber", $text{'uid'} ],
                             [ "gidNumber", $text{'gid'} ] ])." ".
                &ui_select("match", 1, $match_modes));

        # Text
        print &ui_table_row($text{'index_ftext'},
                &ui_textbox("what", undef, 50));

        print &ui_table_end();
        print &ui_form_end([ [ undef, $text{'find'} ] ]);
	$formno++;
	print &ui_links_row(\@links);
	}
elsif (@ulist) {
	# Show table of all users
	@ulist = &useradmin::sort_users(\@ulist, $mconfig{'sort_mode'});
	@left = grep { !/batch_form|export_form/ } @links;
	@right = grep { /batch_form|export_form/ } @links;
	&useradmin::users_table(\@ulist, $form++, 1, 0, \@left, \@right);
	}
elsif ($access{'ucreate'}) {
	# No users
	$base = &get_user_base();
	print "<b>",&text('index_unone', "<tt>$base</tt>"),"</b><p>\n";
	print &ui_links_row(\@links);
	}

# End of users tab
if ($can_users) {
        print &ui_tabs_end_tab("mode", "users");
        }

# Start of groups tab
if ($can_groups) {
        print &ui_tabs_start_tab("mode", "groups");
        }

# Create group links
@links = ( );
if ($access{'gcreate'}) {
	push(@links, &ui_link("edit_group.cgi?new=1",$text{'index_gadd'}));
	}

if ($gcount > $mconfig{'display_max'}) {
	# Show group search form
        print "<b>$text{'index_gtoomany'}</b><p>\n";
        print &ui_form_start("search_group.cgi");
        print &ui_table_start($text{'index_gsheader'}, undef, 2);

        # Field to search
        print &ui_table_row($text{'index_gfind'},
                &ui_select("field", "cn",
                           [ [ "cn", $text{'gedit_group'} ],
                             [ "memberUid", $text{'gedit_members'} ],
                             [ "gidNumber", $text{'gedit_gid'} ] ])." ".
                &ui_select("match", 1, $match_modes));

        # Text
        print &ui_table_row($text{'index_ftext'},
                &ui_textbox("what", undef, 50));

        print &ui_table_end();
        print &ui_form_end([ [ undef, $text{'find'} ] ]);
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

# End of groups tab
if ($can_groups) {
        print &ui_tabs_end_tab("mode", "groups");
        }
print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

