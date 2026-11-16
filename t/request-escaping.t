#!/usr/bin/perl
# Exercise request-derived HTML without reading live logs or contacting hosts.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;

my $root = "$FindBin::Bin/..";
my $source_root = $ENV{'WEBMIN_ESCAPING_SOURCE'} || $root;
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
$INC{'./webminlog-lib.pl'} = $INC{'./cluster-webmin-lib.pl'} = 1;
*main::ReadParse = *main::foreign_require = *main::error_setup = sub { };
*main::get_module_variable = sub { return \%main::text };
*main::load_theme_library = sub { };
*main::error = sub { die "$_[0]\n" };
*main::get_webprefix = sub { '' };
*main::get_module_name = sub { 'fixture' };
*main::get_module_info = sub { return (); };

# render_cgi(file, &inputs) captures output until a fixture stops the request.
sub render_cgi
{
my ($file, $inputs) = @_;
local %main::in = %$inputs;
my $html = '';
open(my $out, '>', \$html) or die $!;
local *STDOUT = $out;
do "$source_root/$file";
return ($html, $@);
}

subtest 'Cluster ACL names' => sub {
	local *CORE::GLOBAL::pipe = sub { die "HOST_DONE\n" };
	local *main::remote_error_setup = sub { };
	local *main::ui_print_header = sub { };
	local *main::remote_finished = sub { };
	local *main::ui_print_footer = sub {
		main::footer(@_);
		die "REQUEST_DONE\n";
		};
	local *main::server_name = sub { 'fixture.test' };
	local *main::list_servers = sub { return { id => 1 }; };
	local %main::text = (acl_doing => 'Setting ACL for $1 on all hosts',
		acl_doing2 => 'Setting ACL for $1 on $2',
		acl_efound => 'Cannot edit $1 in $2');
	foreach my $name ('ordinary-user', q{user & "group"},
		'<img src=x onerror="alert(1)">') {
		# No matching hosts: render the all-hosts response without RPC calls.
		local *main::list_webmin_hosts = sub { return (); };
		local @main::hosts;
		foreach my $field ('_acl_user', '_acl_group') {
			my $host = q{1"><img src=x onerror="alert(1)">};
			my ($html, $error) = render_cgi('cluster-webmin/save_acl.cgi',
				{ all => 1, $field => $name, _acl_mod => 'fixture',
				  _acl_host => $host });
			is($error, "REQUEST_DONE\n", 'all-hosts response completes');
			like($html, qr/\Q@{[main::html_escape($name)]}\E/,
				'account name appears as text');
			is($main::who, $name, 'account identifier remains unchanged');
			my $kind = $field eq '_acl_user' ? 'user' : 'group';
			my $url = "edit_$kind.cgi?$kind=".main::urlize($name).
				'&host='.main::urlize($host);
			like($html, qr/\Q$url\E/, 'return link encodes its parameters');
			unlike($html, qr/<img[^>]*\bonerror=/,
				'account cannot inject HTML');
			}
		# Stop just after the single-host message, before any pipe or RPC call.
		local *main::list_webmin_hosts = sub {
			return { id => 1, users => [ { name => $name } ] };
			};
		my ($html, $error) = render_cgi('cluster-webmin/save_acl.cgi',
			{ _acl_user => $name, _acl_host => 1, _acl_mod => 'fixture' });
		is($error, "HOST_DONE\n", 'single-host output precedes remote work');
		like($html, qr/\Q@{[main::html_escape($name)]}\E/,
			'single-host account name appears as text');
		# The rejection message must escape both submitted placeholders too.
		local *main::list_webmin_hosts = sub { return { id => 1, users => [] }; };
		my $module = q{<img src=x onerror="alert(2)">};
		($html, $error) = render_cgi('cluster-webmin/save_acl.cgi',
			{ _acl_user => $name, _acl_host => 1, _acl_mod => $module });
		is($error, 'Cannot edit '.main::html_escape($name).' in '.
			main::html_escape($module)."\n",
			'rejected account and module names are escaped');
		}
	};

done_testing();
