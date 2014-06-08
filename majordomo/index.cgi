#!/usr/local/bin/perl
# index.cgi
# Display all mailing lists and majordomo options

require './majordomo-lib.pl';
%access = &get_module_acl();

# Check for the majordomo config file
if (!-r $config{'majordomo_cf'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("majordomo", "man", "doc", "google"));
	print &text('index_econfig', "<tt>$config{'majordomo_cf'}</tt>",
		 "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check for the programs dir
if (!-d $config{'program_dir'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("majordomo", "man", "doc", "google"));
	print &text('index_eprograms', "<tt>$config{'program_dir'}</tt>",
		  "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check majordomo version
if (!-r "$config{'program_dir'}/majordomo_version.pl") {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		&help_search_link("majordomo", "man", "doc", "google"));
	print &text('index_eversion2', "majordomo_version.pl",
			  $config{'program_dir'},
		 	  "$gconfig{'webprefix'}/config.cgi?$module_name"),
	      "<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
require "$config{'program_dir'}/majordomo_version.pl";
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("majordomo", "man", "doc", "google"),
	undef, undef, &text('index_version', $majordomo_version));
if ($majordomo_version < 1.94 || $majordomo_version >= 2) {
	print "$text{'index_eversion'}<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check $homedir in majordomo.cf
$conf = &get_config();
if (!&homedir_valid($conf)) {
	print &text('index_ehomedir', "<tt>$homedir</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check $listdir in majordomo.cf
$listdir = &perl_var_replace(&find_value("listdir", $conf), $conf);
if (!-d $listdir) {
	print &text('index_elistdir', "<tt>$listdir</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Check if module needed for aliases is OK
if ($config{'aliases_file'} eq 'postfix') {
	# Postfix has to be installed
	&foreign_installed("postfix", 1) ||
		&ui_print_endpage(&text('index_epostfix', '../postfix/'));
	}
elsif ($config{'aliases_file'} eq '') {
	# Sendmail has to be installed
	&foreign_installed("sendmail", 1) ||
		&ui_print_endpage(&text('index_esendmail2', '','../sendmail/'));
	}
else {
	# Only the sendmail module has to be installed
	&foreign_check("sendmail") ||
		&ui_print_endpage(&text('index_esendmail3'));
	}

# Check for the majordomo aliases
$aliases_files = &get_aliases_file();
$email = &find_value("whoami", $conf); $email =~ s/\@.*$//g;
$owner = &find_value("whoami_owner", $conf); $owner =~ s/\@.*$//g;
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	if ($a->{'enabled'} && lc($a->{'name'}) eq lc($email)) {
		$majordomo_alias = 1;
		}
	if ($a->{'enabled'} && lc($a->{'name'}) eq lc($owner)) {
		$majordomo_owner = 1;
		}
	}

# Offer to setup aliases
if (!$majordomo_alias) {
	print "<p>$text{'index_setupdesc'}\n";
	print "<center><form action=alias_setup.cgi>\n";
	if (!$majordomo_owner) {
		print "<b>$text{'index_owner'}</b>\n";
		print "<input name=owner size=25>\n";
		print "<input type=hidden name=owner_a value='$owner'>\n";
		}
	print "<input type=hidden name=email_a value='$email'>\n";
	print "<input type=submit value=\"$text{'index_setup'}\">\n";
	print "</form></center>\n";
	print &ui_hr();
	}

# Display active lists
@lists = &list_lists($conf);
@lists = sort { $a cmp $b } @lists if ($config{'sort_mode'});
map { $lcan{$_}++ } split(/\s+/, $access{'lists'});
foreach $l (grep { $lcan{$_} || $lcan{"*"} } @lists) {
	push(@links, "edit_list.cgi?name=$l");
	push(@titles, &html_escape($l));
	push(@icons, "images/list.gif");
	}
if (@links) {
	@crlinks = ( &ui_link("create_form.cgi",$text{'index_add'}) );
	if (@links) {
		push(@crlinks, &ui_link("digest_form.cgi",$text{'index_digest'}));
		}
	if ($access{'create'}) {
		print &ui_links_row(\@crlinks);
		}
	&icons_table(\@links, \@titles, \@icons, 5);
	}
else {
	print "<b>$text{'index_none'}</b>.<p>\n";
	}
if ($access{'create'}) {
	print &ui_links_row(\@crlinks);
	}

if ($access{'global'}) {
	print &ui_hr();
	print "<table> <tr>\n";
	print "<form action=edit_global.cgi>\n";
	print "<td><input type=submit value='$text{'index_global'}'></td>\n";
	print "<td>$text{'index_globaldesc'}</td> </tr> </form>\n";
	print "</table>\n";
	}

&ui_print_footer("/", $text{'index'});

