#!/usr/bin/perl
# edit_user.cgi
# Show one Webmin user

require './itsecur-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&can_use_error("users");
@users = &acl::list_users();
&ReadParse();

if ($in{'new'}) {
	&header($text{'user_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	%gotmods = ( $module_name, 1 );
	}
else {
	&header($text{'user_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	($user) = grep { $_->{'name'} eq $in{'name'} } @users;
	%gotmods = map { $_, 1 } @{$user->{'modules'}};
	}

my @vmiddle = ["valign=middle","valign=middle"];

print &ui_hr();

print &ui_form_start("save_user.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("old", $in{'new'});
print &ui_table_start($text{'user_header'}, undef, 2);

# Show username
print &ui_table_row($text{'user_name'}, &ui_textbox("name", $user->{'name'}, 20), undef, @vmiddle );

# Show password
print &ui_table_row($text{'user_pass'},
                    ( !$in{'new'} ? &ui_radio("same", 1, [
                                [1, $text{'user_same'}],
                                [0, $text{'user_change'}],
                              ]) : "").
                    &ui_password("pass", "", 20), undef, @vmiddle  );

# Show enabled flag
print &ui_table_row($text{'user_enabled'},
                    &ui_yesno_radio("enabled", ($user->{'pass'} =~ /^\*LK\*/ ? 1 : 0 ), 1, 0) );

# Show allowed IPS
print &ui_table_row($acl::text{'edit_ips'},
                    &ui_oneradio("ipmode", 0, $acl::text{'edit_all'}, ( $user->{'allow'} || $user->{'deny'} ? 0 : 1) )."<br>".
                    &ui_oneradio("ipmode", 1, $acl::text{'edit_allow'}, ( $user->{'allow'} ? 1 : 0) )."<br>".
                    &ui_oneradio("ipmode", 2, $acl::text{'edit_deny'}, ( $acl::text{'edit_deny'} ? 1 : 0) )."<br>".
                    &ui_textarea("ips", ( join("\n", split(/\s+/, $user->{'allow'} ? $user->{'allow'} : $user->{'deny'})) ), 4, 30)
                    , ["valign=top","valign=top"]);

# Show allowed modules (from list for *this* user)
&read_acl(\%acl);
my @mymods = grep { $acl{$base_remote_user,$_->{'dir'}} } &get_all_module_infos();
my @sel;
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} } @mymods) {
    push(@sel, [$m->{'dir'}, $m->{'desc'}, ($gotmods{$m->{'dir'}} ? "selected" : "") ] );
	}
print &ui_table_row($text{'user_mods'}, &ui_select("mods", undef, \@sel, 5, 1) );

# Show access control
print &ui_table_hr();

require "./acl_security.pl";
if ($in{'new'}) {
	%uaccess = ( 'features' => 'rules services groups nat pat spoof logs apply',
		     'rfeatures' => 'rules services groups nat pat spoof logs apply',
		     'edit' => 1 );
	}
else {
	%uaccess = &get_module_acl($user->{'name'});
	}
&acl_security_form(\%uaccess);

print &ui_table_end();
print "<p>";

if ($in{'new'}) {
    print &ui_submit($text{'create'});
	}
else {
    print &ui_submit($text{'save'});
    print &ui_submit($text{'delete'}, "delete");
	}
print &ui_form_end(undef,undef,1);
&can_edit_disable("users");

print &ui_hr();
&footer("list_users.cgi", $text{'users_return'});

