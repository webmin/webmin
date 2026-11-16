#!/usr/bin/perl
# Exercise request-derived HTML without reading live logs or contacting hosts.
use strict;
use warnings;
no warnings qw(once redefine uninitialized);
use Test::More;
use FindBin;
use Encode qw(encode decode);
use JSON::PP qw(encode_json decode_json);
use IPC::Open3;
use Symbol qw(gensym);

my $root = "$FindBin::Bin/..";
my $source_root = $ENV{'WEBMIN_ESCAPING_SOURCE'} || $root;
require "$root/web-lib-funcs.pl";
require "$root/ui-lib.pl";
my $node = main::has_command('node');
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

subtest 'Actions Log subtitle' => sub {
	local *main::ui_print_header = sub {
		print main::ui_post_header($_[0]);
		die "HEADER_DONE\n";
		};
	foreach my $subtitle ('Domain example.test', q{O'Reilly & Partners},
		'<img src=x onerror="alert(1)">') {
		my ($html, $error) = render_cgi('webminlog/search.cgi',
			{ tall => 1, search_sub_title => $subtitle });
		is($error, "HEADER_DONE\n", 'request reaches the heading');
		like($html, qr/\Q@{[main::html_escape($subtitle)]}\E/,
			'subtitle appears as text');
		unlike($html, qr/<img\b/, 'subtitle cannot introduce an HTML tag');
		}
	};

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

subtest 'File Manager rename handler' => sub {
	plan skip_all => 'Node.js is required to execute rename handlers' if (!$node);
	open(my $lib, '<', "$source_root/filemin/filemin-lib.pl") or die $!;
	my $source = do { local $/; <$lib> };
	close($lib);
	my ($function) = $source =~ /^(sub print_interface\n\{.*?^\})/ms;
	die 'Missing print_interface' if (!$function);
	eval "no strict; $function";
	die $@ if ($@);
	local *main::get_bookmarks = sub { return []; };
	local *main::get_theme_info = sub { return (); };
	local *main::plain_interface_head = sub { '' };
	local *main::has_command = *main::get_selinux_status =
		*main::get_attr_status = *main::get_acls_status = sub { 0 };
	local $main::page = 1;
	local $main::pagelimit = 20;
	local $main::cwd = '/fixture';
	local $main::path = '/';
	local %main::userconfig = (columns => 'name');
	local %main::text = (rename => 'Rename');
	foreach my $name ('file.txt', '0', q{O'Reilly "quote" & literal &quot;},
		q{back\slash}, "line\nbreak\r.txt", "caf\x{e9}-\x{4e2d}.txt",
		q{");globalThis.review_marker=1;("}) {
		my $bytes = encode('UTF-8', $name);
		my @entry = ($bytes);
		@entry[3, 5, 6, 8, 10, 14, 15] = (0644, $<, 0, 0, 0,
			'application/octet-stream', 0);
		local @main::list = (\@entry);
		my $html = '';
		open(my $out, '>', \$html) or die $!;
		{
			local *STDOUT = $out;
			main::print_interface();
			}
		my ($handler) = $html =~ /onclick='(renameDialog[^']*)'/;
		ok(defined($handler), 'rename action is rendered');
		like($handler, qr/^renameDialog\(/,
			'Authentic context menu can find the rename action');
		# HTML decodes entities once before compiling the JavaScript attribute.
		my %entities = (amp => '&', lt => '<', gt => '>', quot => '"',
			'#39' => "'", '#61' => '=');
		$handler =~ s/&(amp|lt|gt|quot|#39|#61);/$entities{$1}/ge;
		my $js = <<'JAVASCRIPT';
const fs = require('fs'), vm = require('vm');
const handler = JSON.parse(fs.readFileSync(0, 'utf8'));
const calls = [], context = { renameDialog: (...args) => calls.push(args) };
vm.createContext(context);
let error;
try { vm.runInContext(handler, context, { timeout: 1000 }); }
catch (e) { error = e.message; }
process.stdout.write(JSON.stringify({ calls, error, marker: context.review_marker }));
JAVASCRIPT
		my $err = gensym();
		my $pid = open3(my $input, my $output, $err, $node, '-e', $js);
		print $input encode_json(decode('UTF-8', $handler));
		close($input);
		my $json = do { local $/; <$output> };
		my $stderr = do { local $/; <$err> };
		waitpid($pid, 0);
		is($?, 0, 'JavaScript runner succeeds');
		is($stderr, '', 'JavaScript runner emits no warnings');
		my $result = decode_json($json);
		ok(!$result->{'error'}, 'rename handler parses and executes');
		ok(!$result->{'marker'}, 'filename cannot execute JavaScript');
		is_deeply($result->{'calls'}, [ [ $name ] ],
			'rename dialog receives the original filename exactly once');
		}
	};

done_testing();
