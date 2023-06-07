#!/usr/local/bin/perl
# index.cgi
# Display all existing databases

require './postgresql-lib.pl';
&ReadParse();

# Check for PostgreSQL program
if (!-x $config{'psql'} || -d $config{'psql'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("postgresql", "man", "doc", "google"));
	print &text('index_esql', "<tt>$config{'psql'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"postgresql", $text{'index_postgresql'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check for alternate config file, and use
if (!$hba_conf_file && -r $config{'alt_hba_conf'} && &is_postgresql_local()) {
	($hba_conf_file) = split(/\t+/, $config{'hba_conf'});
	my $hba_conf_dir = $hba_conf_file;
	$hba_conf_dir =~ s/\/([^\/]+)$//;
	if (!-d $hba_conf_dir) {
		&make_dir($hba_conf_dir, 0777);
		}
	&copy_source_dest($config{'alt_hba_conf'}, $hba_conf_file);
	}

# Check for the config file
if (!$hba_conf_file && &is_postgresql_local()) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		&help_search_link("postgresql", "man", "doc", "google"));
	($hba_conf_file) = split(/\t+/, $config{'hba_conf'});
	if ($config{'setup_cmd'}) {
		# Offer to setup DB for first time
		print &text('index_setup', "<tt>$hba_conf_file</tt>",
				  "<tt>$config{'setup_cmd'}</tt>"),"<p>\n";
		print "<form action=setup.cgi><center>\n";
		print "<input type=submit value='$text{'index_setupok'}'>\n";
		print "</center></form><p>\n";
		}
	else {
		# Config file wasn't found
		print &text('index_ehba', "<tt>$hba_conf_file</tt>",
		    "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
		}
	&ui_print_footer("/", $text{'index'});
	exit;
	}

($r, $rout) = &is_postgresql_running();
if ($r == 0) {
	# Not running .. need to start it
	&main_header(1);
	print &ui_alert_box($text{'index_notrun'}, 'danger');

	if (&is_postgresql_local()) {
		print &ui_hr();
		print &ui_buttons_start();
		if ($access{'stop'}) {
			# Show start button
			print &ui_buttons_row("start.cgi", $text{'index_start'},
			      		      $text{'index_startmsg2'});
			}
		if ($access{'users'}) {
			print &ui_buttons_row("list_hosts.cgi",
					      $text{'host_title'},
					      &text('index_hostdesc'));
			}
		print &ui_buttons_end();
		}
	$lerr++;
	}
elsif ($r == -1 && $access{'user'} && 0) {
	# Running, but the user's password is wrong
	&main_header(1);
	print &ui_alert_box(&text('index_nouser', "<tt>$access{'user'}</tt>"), 'danger');
	print &ui_alert_box(&text('index_emsg', "<tt>$rout</tt>"), 'info');
	$lerr++;
	}
elsif ($r == -1) {
	# Running, but webmin doesn't know the login/password
	&main_header(1);
	print &ui_alert_box($text{'index_nopass'}, 'danger');
	print &ui_alert_box(&text('index_emsg', "<tt>$rout</tt>"), 'info');

	print &ui_form_start("login.cgi", "post");
	print &ui_table_start($text{'index_ltitle'}, undef, 2);

	print &ui_table_row($text{'index_login'},
		&ui_textbox("login", $access{'user'} || $config{'login'}, 40));

	print &ui_table_row(" ",
		&ui_checkbox("sameunix", 1, $text{'index_sameunix'},
			     $config{'sameunix'}));

	print &ui_table_row($text{'index_pass'},
		&ui_password("pass", undef, 40));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'save'} ] ]);

	# Button to edit user permissions
	if ($access{'users'}) {
		print &ui_form_start("list_hosts.cgi");
		print &ui_form_end([ [ undef, $text{'index_edithosts'} ] ]);
		}
	$lerr++;
	}
elsif ($r == -2) {
	# Looks like a shared library problem
	&main_header(1);
	print &text('index_elibrary', "<tt>$config{'psql'}</tt>",
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	print &text('index_ldpath', "<tt>$ENV{$gconfig{'ld_env'}}</tt>",
		  "<tt>$config{'psql'}</tt>"),"<br>\n";
	print "<pre>",&html_escape($out),"</pre><p>\n";
	print &ui_alert_box(&text('index_emsg', "<tt>$rout</tt>"), 'info');
	$lerr++;
	}
else {
	# Running .. check version
	$postgresql_version = &get_postgresql_version();
	if (!$postgresql_version) {
		&main_header(1);
	        print &text('index_superuser',"@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	if ($postgresql_version < 6.5) {
		&main_header(1);
		print &text('index_eversion', $postgresql_version, 6.5),
		      "<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}

	# Check if we can re-direct to a single DB's page
	@alldbs = &list_databases();
	@titles = grep { &can_edit_db($_) } @alldbs;
	$can_all = (@alldbs == @titles);
	if (@titles == 1 && $access{'dbs'} ne '*' && !$access{'users'} &&
	    !$access{'create'} && !$access{'stop'}) {
		# Only one DB, so go direct to it!
		&redirect("edit_dbase.cgi?db=$titles[0]");
		exit;
		}

	&main_header();
	print &ui_subheading($text{'index_dbs'}) if ($access{'users'});
	if ($in{'search'}) {
		# Limit to those matching search
		@titles = grep { /\Q$in{'search'}\E/i } @titles;
		print "<table width=100%><tr>\n";
		print "<td> <b>",&text('index_showing',
		    "<tt>".&html_escape($in{'search'})."</tt>"),"</b></td>\n";
		print "<td align=right><a href='index.cgi'>",
			"$text{'view_searchreset'}</a></td>\n";
		print "</tr></table>\n";
		}
	elsif ($in{'show'}) {
		# Limit to specific databases
		%show = map { $_, 1 } split(/\0/, $in{'show'});
		@titles = grep { $show{$_} } @titles;
		}

	# List the databases
	@icons = map { "images/db.gif" } @titles;
	@links = map { "edit_dbase.cgi?db=$_" } @titles;
	$can_create = $access{'create'} == 1 ||
		      $access{'create'} == 2 && @titles < $access{'max'};

	@rowlinks = ( );
	push(@rowlinks, "<a href=newdb_form.cgi>$text{'index_add'}</a>")
		if ($can_create);
	if (!@icons) {
                if ($in{'search'}) {
                        print "<b>$text{'index_nodbs3'}</b> <p>\n";
                        }
		else {
			print "<b>$text{'index_nodbs'}</b> <p>\n";
			}
		}
	elsif (@icons > $max_dbs && !$in{'search'}) {
		# Too many databases to show .. display search and jump forms
		print &ui_form_start("index.cgi");
		print $text{'index_toomany'},"\n";
		print &ui_textbox("search", undef, 20),"\n";
		print &ui_submit($text{'index_search'}),"<br>\n";
		print &ui_form_end();

		print &ui_form_start("edit_dbase.cgi");
		print $text{'index_jump'},"\n";
		print &ui_select("db", undef, [ map { [ $_ ] } @titles ],
				 1, 0, 0, 0, "onChange='form.submit()'"),"\n";
		print &ui_submit($text{'index_jumpok'}),"<br>\n";
		print &ui_form_end();
		@icons = ( );
		}
	else {
		# Show databases as table
		if ($access{'delete'}) {
			print &ui_form_start("drop_dbases.cgi");
			unshift(@rowlinks, &select_all_link("d", 0),
					   &select_invert_link("d", 0) );
			}
		print &ui_links_row(\@rowlinks);
		@checks = @titles;
		if ($config{'style'} == 1) {
			# Show as DB names and table counts
			@tables = map { if (&accepting_connections($_)) {
						my @t = &list_tables($_);
						scalar(@t);
						}
					else {
						"-";
						}
					} @titles;
			@titles = map { &html_escape($_) } @titles;
			&split_table([ "", $text{'index_db'},
				       $text{'index_tables'} ],
				     \@checks, \@links, \@titles, \@tables)
				if (@titles);
			}
		elsif ($config{'style'} == 2) {
                        # Show just DB names
                        @grid = ( );
                        for(my $i=0; $i<@links; $i++) {
                                push(@grid, &ui_checkbox("d", $titles[$i]).
                                  " <a href='$links[$i]'>".
                                  &html_escape($titles[$i])."</a>");
                                }
                        print &ui_grid_table(\@grid, 4, 100, undef, undef, "");
			}
		else {
			# Show databases as icons
			@checks = map { &ui_checkbox("d", $_) } @checks;
			@titles = map { &html_escape($_) } @titles;
			&icons_table(\@links, \@titles, \@icons, 5,
				     undef, undef, undef, \@checks);
			}
		}
	print &ui_links_row(\@rowlinks);
	if (@icons && $access{'delete'}) {
		print &ui_form_end([ [ "delete", $text{'index_drops'} ] ]);
		}

	if ($access{'users'}) {
		print &ui_hr();
		print &ui_subheading($text{'index_users'});
		@links = ( 'list_users.cgi', 'list_groups.cgi',
			   'list_hosts.cgi', 'list_grants.cgi' );
		@titles = ( $text{'user_title'}, $text{'group_title'},
			    $text{'host_title'}, $text{'grant_title'} );
		@images = ( 'images/users.gif', 'images/groups.gif',
			    'images/hosts.gif', 'images/grants.gif' );
		&icons_table(\@links, \@titles, \@images);
		}
	}

if (!$lerr) {
	print &ui_hr();
	print &ui_buttons_start();
	}

# Show stop server button
if ($access{'stop'} && &is_postgresql_local() && $r != 0) {
	print &ui_buttons_row("stop.cgi", $text{'index_stop'},
			      $text{'index_stopmsg'});
	}

if ($r > 0) {
	# Show backup all button
	if ($can_all && $access{'backup'}) {
		print &ui_buttons_row("backup_form.cgi", $text{'index_backup'},
				      $text{'index_backupmsg'},
				      &ui_hidden("all", 1));
		}
	}

print &ui_buttons_end();

# Check if the optional perl modules are installed
if (&foreign_available("cpan")) {
	eval "use DBI";
	push(@needs, "DBI") if ($@);
	$nodbi++ if ($@);
	eval "use DBD::Pg";
	push(@needs, "DBD::Pg") if ($@);
	if (@needs) {
		$needs = &urlize(join(" ", @needs));
		print &ui_alert_box(&text(@needs == 2 ? 'index_nomods' : 'index_nomod', @needs,
			"../cpan/download.cgi?source=3&cpan=$needs&mode=2&return=/$module_name/&returndesc=".
			    &urlize($text{'index_return'})), 'warn');
		}
	}

&ui_print_footer("/", "index");

sub main_header
{
my ($noschemas) = @_;
my $smsg = "";
if (!$noschemas) {
	eval {
		local $main::error_must_die = 1;
		$smsg = supports_schemas($config{'basedb'}) ?
				" ".$text{'index_sch'} : "";
		};
	}
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("postgresql", "man", "doc", "google"),
	undef, undef, $postgresql_version ?
	   &text('index_version', $postgresql_version).$smsg :
	   undef);
}

