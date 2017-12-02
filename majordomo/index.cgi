#!/usr/local/bin/perl
# index.cgi
# Display all mailing lists and majordomo options

require './majordomo-lib.pl';
%access = &get_module_acl();
$conf = &get_config();

eval { require "$config{'program_dir'}/majordomo_version.pl"; };
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
        &mdom_help(),
        undef, undef, &text('index_version', $majordomo_version));

&check_mdom_config($conf);

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
	print ui_alert_box($text{'index_setupdesc'}, "warn");
	print ui_form_start("alias_setup.cgi", "post");
	if (!$majordomo_owner) {
		print "<b>$text{'index_owner'}</b>\n";
		print ui_textbox("owner", "", 25);
		print ui_hidden("owner_a", $owner);
		}
	print ui_hidden("email_a", $email);
	print ui_submit($text{'index_setup'});
	print ui_form_end();
	print &ui_hr();
	}

# Display active lists
@lists = &list_lists($conf);
@lists = sort { $a cmp $b } @lists if ($config{'sort_mode'});
map { $lcan{$_}++ } split(/\s+/, $access{'lists'});
# top links
local $otherbut, $bcss=' style="display: box; float: left; padding: 10px;"';
if ($access{'create'}) {
        print "<div $bcss>".ui_form_start("create_form.cgi", "post").&ui_submit($text{'index_add'}).ui_form_end()."</div>";
        print "<div $bcss>".ui_form_start("digest_form.cgi", "post").&ui_submit($text{'index_digest'}).ui_form_end()."</div>";
	}

if ($access{'global'}) {
	print  "<div $bcss>".ui_form_start("edit_global.cgi", "post").&ui_submit($text{'index_global'}).ui_form_end()."</div>";
	#print "$text{'index_globaldesc'}\n";
	}
	
    # table header
    local @hcols, @tds;
    push(@hcols, $text{'index_name'}, $text{'index_info'}, $text{'index_mail'}, $text{'index_moderated'}, $text{'index_count'});
    push(@tds, "width=5" ,"width=100" );
    push(@tds, "", "", "width=100", "", "");
    print &ui_columns_start(\@hcols, 100, 0, \@tds);

# mailing lists
if (@lists) {
        foreach $l (grep { $lcan{$_} || $lcan{"*"} } @lists) {
	local @cols,@list,@conf;
	$list = &get_list( $l , &get_config());
	$conf = &get_list_config($list->{'config'});
	push(@cols, "&nbsp;&nbsp; <a href=edit_list.cgi?name=$l><img src=images/smallicon.gif> &nbsp;&nbsp;".
			&html_escape(ucfirst($l)) ."</a>" );
	open(INFO, $list->{'info'});
	local $info=<INFO>;
	$info=<INFO> if ( $info =~ !/^\[Last updated on:/);
	push(@cols, "<em>".$info."</em>" ."&nbsp;&nbsp;<em><a href=edit_info.cgi?name=$l><span>edit</span></a></em>");
	close(INFO);
	local $m=&find_value('reply_to', $conf);
	push(@cols, "<em><a href=\"mailto:%22". ucfirst($l) ."%22%3c$m%3e\">$m</a>".
		"&nbsp;&nbsp;<em><a href=edit_mesg.cgi?name=$l><span>edit</span></a></em>");
	push(@cols, "<center><em>". $text{&find_value('moderate', $conf)} .
		"</em>" ."&nbsp;&nbsp;<em><a href=edit_subs.cgi?name=$l><span>edit</span></a></em><center>");
	push(@cols, "<center>".`cat $list->{'members'} | wc -l` .
		"&nbsp;&nbsp;<em><a href=edit_members.cgi?name=$l><span>edit</span></a></em></center>");
	print&ui_columns_row(\@cols, \@tds);
	}
	print &ui_columns_end();
} else {
	print &ui_columns_end();
	print  ui_alert_box($text{'index_none'}, "info");#"<b>$text{'index_none'}</b>.<p>\n";
    }

&ui_print_footer("/", $text{'index'});
