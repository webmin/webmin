use strict;
use warnings;
no warnings 'redefine';

require 'systemd-lib.pl'; ## no critic

our (%in, %text);

# acl_security_form(options)
# Outputs ACL controls for granting access to systemd unit management.
sub acl_security_form
{
my ($o) = @_;
my $m = $o->{'mode'} || 0;

# User scope controls limit which Unix users' units this Webmin user can touch.
print ui_table_span(ui_tag('b', html_escape($text{'acl_section_users'})));
print ui_table_row($text{'acl_users'},
	ui_radio("mode", $m,
	 [ [ 0, "$text{'acl_all'}<br>" ],
	   [ 3, "$text{'acl_this'}<br>" ],
	   [ 1, $text{'acl_only'}." ".
		ui_textbox("userscan",
			$m == 1 ? $o->{'users'} : "", 40)." ".
		user_chooser_button("userscan", 1)."<br>" ],
	   [ 2, $text{'acl_except'}." ".
		ui_textbox("userscannot",
			$m == 2 ? $o->{'users'} : "", 40)." ".
		user_chooser_button("userscannot", 1)."<br>" ],
	   [ 5, $text{'acl_gid'}." ".
		ui_textbox("gid",
		    $m == 5 ? scalar(getgrgid($o->{'users'})) : "", 13)." ".
		group_chooser_button("gid", 0)."<br>" ],
	   [ 4, $text{'acl_uid'}." ".
		ui_textbox("uidmin", $o->{'uidmin'}, 6)." - ".
		ui_textbox("uidmax", $o->{'uidmax'}, 6)."<br>" ],
	 ]), 3, undef, undef, 1);
print ui_table_hr();

# View controls cover listing units and reading status or journal output.
print ui_table_span(ui_tag('b', html_escape($text{'acl_section_view'})));
foreach my $a (qw(view view_user status status_user logs logs_user)) {
	print ui_table_row($text{'acl_'.$a},
			   ui_yesno_radio($a, $o->{$a}), 3);
	}
print ui_table_hr();

# Runtime controls cover actions that change active state or manager state.
print ui_table_span(ui_tag('b', html_escape($text{'acl_section_runtime'})));
foreach my $a (qw(start start_user stop stop_user restart restart_user
		  boot boot_user mask mask_user reload linger)) {
	print ui_table_row($text{'acl_'.$a},
			   ui_yesno_radio($a, $o->{$a}), 3);
	}
print ui_table_hr();

# Change controls cover writing, deleting, drop-ins, manual edits and backup.
print ui_table_span(ui_tag('b', html_escape($text{'acl_section_change'})));
foreach my $a (qw(create create_user edit edit_user delete delete_user
		  dropin dropin_user manual manual_user backup)) {
	print ui_table_row($text{'acl_'.$a},
			   ui_yesno_radio($a, $o->{$a}), 3);
	}
}

# acl_security_save(options)
# Saves systemd ACL settings from the submitted form.
sub acl_security_save
{
my ($o) = @_;

my $mode = defined($in{'mode'}) && $in{'mode'} =~ /^[0-5]$/ ?
	$in{'mode'} : 0;
$o->{'mode'} = $mode;
$o->{'users'} = $mode == 0 || $mode == 3 || $mode == 4 ? "" :
		$mode == 5 ? scalar(getgrnam($in{'gid'} || "")) || "" :
		$mode == 1 ? $in{'userscan'} || "" : $in{'userscannot'} || "";
$o->{'uidmin'} = $mode == 4 ? $in{'uidmin'} || "" : "";
$o->{'uidmax'} = $mode == 4 ? $in{'uidmax'} || "" : "";
foreach my $a (systemd_acl_keys()) {
	$o->{$a} = $in{$a} || 0;
	}
}

1;
