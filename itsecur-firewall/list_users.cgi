#!/usr/bin/perl
# list_users.cgi
# Show all Webmin users with access to this module only

require './itsecur-lib.pl';
&foreign_require("acl", "acl-lib.pl");
&can_use_error("users");
&header($text{'users_title'}, "",
	undef, undef, undef, undef, &apply_button());

print &ui_hr();

# Work out which users have access to this module
my @users = &acl::list_users();
foreach $u (@users) {
	my @m = @{$u->{'modules'}};
	if ($u->{'name'} ne "root" &&
	    &indexof($module_name, @m) >= 0) {
		push(@musers, $u);
		}
	}

#print "$text{'users_desc'}<p>\n";
my $edit = &can_edit("users");
my $link = ( $edit ? &ui_link("edit_user.cgi?new=1", $text{'users_add'}) : "" );
if (@musers) {
	print $link;
    my @cols;
    print &ui_columns_start([$text{'users_name'}, $text{'users_ips'}, $text{'users_enabled'}]);
	foreach $u (@musers) {
        push(@cols, &ui_link("edit_user.cgi?name=".$u->{'name'},$u->{'name'}) );
        my $tx = "";
		if ($u->{'allow'}) {
			$tx = &text('users_allow', $u->{'allow'});
			}
		elsif ($u->{'deny'}) {
			$tx = &text('users_deny', $u->{'deny'});
			}
		else {
			$tx = $text{'users_all'};
			}
		push(@cols, $tx);
        push(@cols, ($u->{'pass'} =~ /^\*LK\*/ ? $text{'rule_no'} : $text{'rule_yes'}) );
		#%uaccess = &get_module_acl($u->{'name'});
		}
	print &ui_columns_row(\@cols);
    print &ui_columns_end();
	}
else {
	print "<b>$text{'users_none'}</b><p>\n";
	}


print $link;

print &ui_hr();
&footer("", $text{'index_return'});
