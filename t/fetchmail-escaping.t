#!/usr/bin/perl
# Render Fetchmail pages without reading mail config or invoking Fetchmail.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$INC{'./fetchmail-lib.pl'} = 1;
*main::ReadParse = sub { };
*main::error = sub { die join(' ', @_)."\n" };
*main::get_module_variable = sub { return \%main::text };
*main::load_theme_library = sub { };
*main::ui_print_header = sub { print main::ui_post_header($_[0]) };
*main::get_module_name = sub { 'fetchmail' };
*main::get_module_info = sub { return () };
*main::get_webprefix = sub { '' };

# Isolate configuration reads, logging and user switching. The check command
# prints fixed text and ignores its arguments; it never opens a mail config.
*main::parse_config_file = sub {
	return { defaults => 1, poll => 'mail.example.test', users => [] };
	};
*main::webmin_log = *main::additional_log = sub { };
*main::command_as_user = sub { $_[2] };
my $client = main::quote_path($^X).q{ -e 'print "Fixture fetchmail output\n";' --};

# Load the real translation strings and ACL check without module initialization.
open(my $lang, '<', "$root/fetchmail/lang/en") or die $!;
while (<$lang>) {
	$main::text{$1} = $2 if /^(\S+)=(.*)$/;
	}
close($lang);
$main::text{'main_return'} = 'Return to $1';
open(my $lib, '<', "$root/fetchmail/fetchmail-lib.pl") or die $!;
my $source = do { local $/; <$lib> };
close($lib);
$source =~ /(^sub can_edit_user\n\{.*?^\})/ms or die 'Missing can_edit_user';
eval 'no strict; no warnings; '.$1;
die $@ if $@;

# render_cgi(script, new, user, config, access) captures an isolated CGI response.
sub render_cgi
{
my ($script, $new, $user, $config, $access) = @_;
local %main::in = (user => $user, new => $new);
local %main::config = (view_mode => 1, fetchmail_path => $client, %$config);
local %main::access = %$access;
local $main::fetchmail_config = $main::config{'config_file'};
local $main::uheader;
local $main::file;
local $main::poll;
local $main::cmd;
local @main::uinfo;
local @main::conf;
local @main::buts;
local @main::tds;
local $main::theme_no_table;
my ($html, $error) = ('', '');
open(my $out, '>', \$html) or die $!;
{
	local *STDOUT = $out;
	do "$root/fetchmail/$script";
	$error = $@;
	}
close($out);
is($main::in{'user'}, $user, 'escaping does not change the request username');
return ($html, $error);
}

for my $page (['edit_global.cgi', 0], ['edit_poll.cgi', 0],
	     ['edit_poll.cgi', 1], ['check.cgi', 0]) {
	subtest "$page->[0] new=$page->[1]" => sub {
		# Nonexistent names still reach the header under an unrestricted ACL.
		for my $user ('root', q{user'" & name}, q{user&lt;name&gt;},
			q{</tt><img src=x onerror="alert(1)">},
			q{<svg onload="alert(1)"></svg>},
			q{x" autofocus onfocus="alert(1)}) {
			my ($html, $error) = render_cgi(@$page, $user, {}, { mode => 0 });
			is($error, '', 'the CGI renders successfully');
			my $subtitle = main::text('poll_foruser',
				'<tt>'.main::html_escape($user).'</tt>');
			like($html, qr/\Q@{[main::ui_post_header($subtitle)]}\E/,
				'escape the username once and preserve trusted subtitle markup');
			like($html, qr/\Qhref="edit_user.cgi?user=@{[main::urlize($user)]}"\E/,
				'the return link encodes the original username');
			my $bare = $html;
			$bare =~ s/"[^"]*"|'[^']*'//g;
			unlike($bare, qr/<svg\b|\bon(?:error|load|focus)\s*=/i,
				'the username cannot introduce active elements or event attributes');
			}

		# Shared-config mode has no user subtitle, even with a hostile parameter.
		my ($html, $error) = render_cgi(@$page, '<svg onload="alert(1)">',
			{ config_file => '/fixture/fetchmailrc' }, { mode => 0 });
		is($error, '', 'shared config renders successfully');
		unlike($html, qr/class='ui_post_header'/, 'shared-config subtitle stays absent');
		unlike($html, qr/href="edit_user\.cgi\?/, 'shared config has no user return link');

		# Restricted users must still be rejected before any header is printed.
		($html, $error) = render_cgi(@$page, 'not-allowed', {},
			{ mode => 1, users => 'root' });
		is($error, $main::text{'poll_ecannot'}."\n", 'the ACL error is unchanged');
		is($html, '', 'denied requests print no header');
		};
	}

done_testing();
