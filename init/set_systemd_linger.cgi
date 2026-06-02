#!/usr/local/bin/perl
# Toggle linger for a systemd user manager

require './init-lib.pl';
&error_setup($text{'systemd_linger_err'});
$access{'bootup'} || &error($text{'edit_ecannot'});
&ReadParse();

# Validate the requested user and linger state before calling loginctl.
my $user = &clean_systemd_unit_value($in{'user'});
my $enabled = $in{'enabled'};
&get_systemd_user_details($user) || &error($text{'systemd_euser'});
if (!defined($enabled) || $enabled !~ /^[01]$/) {
	&error($text{'systemd_elinger'});
	}

my ($ok, $out) = &set_systemd_user_linger($user, $enabled);
$ok || &error_systemd_linger_command($user, $out);
if ($enabled) {
	($ok, $out) = &start_systemd_user_manager($user);
	$ok || &error_systemd_linger_command($user, $out);
	}

&webmin_log("linger", "systemd-user", $user,
	    { 'user' => $user, 'enabled' => $enabled });
&redirect(&systemd_index_url(undef, 1, $user));

# error_systemd_linger_command(user, output)
# Shows escaped loginctl or systemctl output from a failed operation.
sub error_systemd_linger_command
{
my ($user, $out) = @_;
$out ||= $text{'systemd_euser'};
&error(&text('systemd_eusercmd',
	     &ui_tag('tt', &html_escape($user)),
	     &ui_tag('pre', &html_escape($out))));
}
