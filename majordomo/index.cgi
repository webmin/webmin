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
# top links
local $otherbut, $bcss=' style="display: box; float: left; padding: 10px;"';
if ($access{'create'}) {
        print "<div $bcss><form action=\"create_form.cgi\">".&ui_submit($text{'index_add'})."</form></div>\n";
        print "<div $bcss><form action=\"digest_form.cgi\">".&ui_submit($text{'index_digest'})."</form></div>\n";
	print "<style>hr {display: none;></style>"
	}
if (@lists) {
    # table header
    local @hcols, @tds;
    push(@hcols,  "", "");
    push(@hcols, $text{'index_name'}, $text{'index_info'}, $text{'index_mail'}, $text{'index_moderated'}, $text{'index_count'});
    push(@tds, "width=5" ,"width=100" );
    push(@tds, "", "", "width=100", "", "");
    print &ui_columns_start(\@hcols, 100, 0, \@tds);
    # mailing lists
    foreach $l (grep { $lcan{$_} || $lcan{"*"} } @lists) {
	local @cols,@list,@conf;
	$list = &get_list( $l , &get_config());
	$conf = &get_list_config($list->{'config'});
	push(@cols, "","<a href=edit_list.cgi?name=$l><img src=images/smallicon.gif></a>");
	push(@cols, "<a href=edit_list.cgi?name=$l>". &html_escape($l) ."</a>" );
	open(INFO, $list->{'info'});
	push(@cols, "<em>".<INFO>."</em>" ."&nbsp;&nbsp;<em><a href=edit_info.cgi?name=$l><span>edit</span></a></em>");
	close(INFO);
	#push(@cols, $l . "-owner");
	push(@cols, "<em>". &find_value('reply_to', $conf) ."</em>");
	push(@cols, "<center><em>". $text{&find_value('moderate', $conf)} .
		"</em>" ."&nbsp;&nbsp;<em><a href=edit_subs.cgi?name=$l><span>edit</span></a></em><center>");
	push(@cols, "<center>".`cat $list->{'members'} | wc -l` .
		"&nbsp;&nbsp;<em><a href=edit_members.cgi?name=$l><span>edit</span></a></em></center>");
	print&ui_columns_row(\@cols, \@tds);
	}
} else {
	print "<b>$text{'index_none'}</b>.<p>\n";
    }

if ($access{'global'}) {
	print "<div $bcss><form action=\"edit_global.cgi\" method=\"post\">",
        	&ui_submit($text{'index_global'})."</form></div>\n";
	print "<div style=\"padding-top: 10px;\">$text{'index_globaldesc'}</div>\n";
	}

&ui_print_footer("/", $text{'index'});
print 	"<script>",
       	"f__lnk_t_btn(['/majordomo/', '/majordomo/index.cgi'], 'table tbody td',",
       	" 'a[href*=\"edit_info.cgi?\"], a[href*=\"edit_members.cgi?\"], a[href*=\"edit_subs.cgi?\"]',",
       	" 'btn btn-transparent btn-xs vertical-align-top margined-top-2', 'fa-edit');",
	"document.querySelectorAll('tbody td .btn.btn-transparent').forEach(function(button) {",
		" button.innerHTML=button.innerHTML.replace(/<\\/i>.*edit/,'');});",
	"</script>",
	"<style>.btn.btn-transparent { padding: 0 !important; color: grey;}</style>";

