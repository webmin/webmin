#!/usr/bin/perl
# Exercise the dashboard with the ACL values saved by Webmin Users.
use strict;
use warnings;
use Test::More;
use FindBin;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);

my $root = abs_path("$FindBin::Bin/../..");
my $dir = tempdir(TMPDIR => 1, CLEANUP => 1);
make_path("$dir/status/services", "$dir/var/locks");

# fixture(path, content) writes a file under the temporary config directory
sub fixture {
	my ($file, $content) = @_;
	open(my $fh, '>', "$dir/$file") or die $!;
	print $fh $content;
	close($fh) or die $!;
}
# Use local, remote, action-capable and unchecked monitor fixtures
fixture('config', "os_type=generic-linux\nos_version=0\nlang=en\n");
fixture('miniserv.conf', "root=$root\n");
fixture('webmin.acl', "viewer: status fail2ban\n");
fixture('status/config', "sysinfo=2\nsysinfo_users=1\n");
fixture('status/oldstatus', "first=1\nsecond=example=0\nthird=1\n");
fixture('status/services/first.serv', "id=first\ntype=exec\ndesc=Local check\n");
fixture('status/services/second.serv',
	"id=second\ntype=exec\ndesc=Remote check\nremote=example\n");
fixture('status/services/third.serv',
	"id=third\ntype=fail2ban\ndesc=Ban check\n");
fixture('status/services/fourth.serv', "id=fourth\ntype=exec\ndesc=New check\n");

# Load the real status code using only the temporary configuration
@ENV{qw(WEBMIN_CONFIG WEBMIN_VAR SERVER_ROOT LIBROOT MINISERV_CONFIG
	REMOTE_USER BASE_REMOTE_USER SCRIPT_NAME REQUEST_METHOD)} =
	($dir, "$dir/var", $root, $root, "$dir/miniserv.conf",
	 'viewer', 'viewer', '/status/index.cgi', 'GET');
chdir("$root/status") or die $!;
unshift(@INC, $root, "$root/status");
local $0 = "$root/status/index.cgi";
do './acl_security.pl' or die $@ || $!;
do './system_info.pl' or die $@ || $!;
our (%access, %config, $ui_page_assets_done);

# panel() returns the rendered dashboard HTML, or empty if hidden
sub panel {
	my ($info) = list_system_info({}, {});
	return $info ? $info->{'html'} : '';
}
like(panel(), qr/Remote check/, 'existing accounts see all configured monitors');
like(panel(), qr/>example<\/td>/, 'a remote monitor names its host as plain text');
like(panel(), qr/<thead>.*Service name.*On host.*Status.*Actions/s,
     'list mode uses the standard table with column headings');
like(panel(), qr/text-danger[^>]*>Down</, 'a failed check has colored status text');
like(panel(), qr/text-success[^>]*>Up</, 'a running check has explicit status text');
unlike(panel(), qr/ui_list_item|ui_badge|ui_icon_(?:check-circle|x-circle|minus)/,
       'list mode has no status icons or badges');
like(panel(), qr/New check.*Unknown/s,
     'a monitor that was never checked is marked as unknown');

# The Fail2Ban module supplies the actions for its built-in monitor type.
like(panel(), qr{action=['"]/fail2ban/stop\.cgi['"] method=['"]post['"]},
     'existing accounts that can edit monitors get action buttons');
like(panel(), qr{/fail2ban/restart\.cgi}, 'a running service can be restarted');
like(panel(), qr/<button[^>]*title="Stop Fail2Ban Server"/,
     'an action button carries the label of its module');
unlike(panel(), qr{<input[^>]*name="redir"},
       'an action form leaves the return page to the submitting request');
unlike(panel(), qr/<input[^>]*\bid=/, 'repeated hidden fields carry no ID');
unlike(panel(), qr{/fail2ban/start\.cgi}, 'a running service cannot be started');
is(scalar(() = panel() =~ /<form\b/g), 2, 'only the local service has actions');
# Embedded panels include CSS without consuming the page asset flag
is(scalar(() = panel() =~ /ui-lib\.css/g), 1,
   'the panel loads the widget stylesheet once');
is($ui_page_assets_done, 0, 'the page can still load its own copy');
my @buttons = monitor_action_buttons(get_service('third'), -1);
is(scalar(@buttons), 0, 'an unknown status offers no actions');

# Exercise saved ACL values, including omitted and multiple selections
acl_security_save(\%access, { all_monitors => 0, monitors => 'first', actions => 0 });
like(panel(), qr/Local check/, 'selected legacy local monitor is rendered');
unlike(panel(), qr/Remote check|example/, 'hidden remote monitor is not listed');
is(scalar(list_services()), 4, 'dashboard selection preserves the full module list');
acl_security_save(\%access, { all_monitors => 1, actions => 0 });
unlike(panel(), qr/<form\b/, 'a user without the action right gets no buttons');
acl_security_save(\%access, { all_monitors => 0, actions => 1 });
is(panel(), '', 'omitted multiple-select field means no dashboard monitors');
acl_security_save(\%access, { all_monitors => 0, monitors => "first\0second" });
like(panel(), qr/Remote check/, 'multiple selected IDs survive the ACL save');
acl_security_save(\%access, { all_monitors => 1 });
like(panel(), qr/Remote check/, 'all mode also includes unselected IDs');

# form(&acl) captures the permission fields inside a Webmin Users table
sub form {
	my ($acl) = @_;
	my $out = '';
	open(my $fh, '>', \$out) or die $!;
	my $old = select($fh);
	# Webmin Users opens a table before it asks the module for its rows
	print ui_table_start(undef, undef, 2);
	acl_security_form($acl);
	print ui_table_end();
	select($old);
	close($fh);
	return $out;
}
# Individual selection is available only when all mode is off
like(form({ edit => 1 }), qr/<select[^>]*name="monitors"[^>]*disabled/,
     'the monitor list is disabled while all monitors are allowed');
unlike(form({ edit => 1, dashboard_monitors => 'first' }),
       qr/<select[^>]*name="monitors"[^>]*disabled/,
       'the monitor list can be used for selected monitors');
like(form({ edit => 1 }), qr/controlName = 'all_monitors'.*fieldNames = \['monitors'\]/s,
     'the choice between all and selected monitors switches the list');

# A monitor and the service of another module that it checks are one item.
{
	no warnings qw(redefine once);
	# module_dashboard_monitors() supplies one paired and one extra service
	local *main::module_dashboard_monitors = sub {
		return ( { id => 'example::ban', desc => 'Ban service', up => 1,
			   type => 'fail2ban', provider => 'example',
			   remote => '*' },
			 { id => 'example::other', desc => 'Other service',
			   up => 1, provider => 'example', remote => '*' } );
		};
	acl_security_save(\%access, { all_monitors => 1, actions => 1 });
	like(panel(), qr/Ban check/, 'a monitor stands in for the service it checks');
	unlike(panel(), qr/Ban service/, 'that service is not shown a second time');
	like(panel(), qr/Other service/, 'a service without a monitor is shown itself');
	# A saved provider ID still selects its paired monitor
	my $form = form({ edit => 1, dashboard_monitors => 'example::ban' });
	unlike($form, qr/Ban service/, 'the access control form lists the pair once');
	like($form, qr/Other service/, 'and still lists a service without a monitor');
	like($form, qr/<option[^>]*value="third"[^>]*selected/,
	     'a saved service selects the monitor that checks it');
	# Disabling monitors keeps provider services subject to ACLs
	$config{'sysinfo'} = 0;
	like(panel(), qr/Ban service/, 'with monitors off the service is shown itself');
	acl_security_save(\%access, { all_monitors => 0, monitors => 'third' });
	like(panel(), qr/Ban service/, 'allowing the monitor allows its service');
	unlike(panel(), qr/Other service/, 'but no other service');
	acl_security_save(\%access, { all_monitors => 0, monitors => 'first' });
	unlike(panel(), qr/Ban service/, 'without its monitor the service is hidden');
	$config{'sysinfo'} = 2;
}

# Existing sysinfo=1 settings select blocks and retain action buttons
acl_security_save(\%access, { all_monitors => 1, actions => 1 });
$config{'sysinfo'} = 1;
unlike(panel(), qr/ui_columns/, 'the block layout replaces the table');
is(scalar(() = panel() =~ /class="[^"]*\bui_card\b/g), 4, 'each monitor gets a block');
like(panel(), qr/ui_stat_value[^>]*ui_fg_success.*\bUp\b.*Ban check/s,
     'a block shows the status above the name');
is(scalar(() = panel() =~ /<form\b/g), 2, 'blocks keep the action buttons');
$config{'sysinfo'} = 0;
is(panel(), '', 'monitors that are switched off are not shown');
$config{'sysinfo'} = 2;

# Only an explicit ID can distinguish services that share a monitor type
my @provided = ( { id => 'example::web', type => 'apache' },
		 { id => 'example::php-8.3', type => 'fpm' },
		 { id => 'example::php-8.4', type => 'fpm' } );
my @checks = ( { id => 'web', type => 'apache', remote => '*' },
	       { id => 'remote', type => 'apache', remote => 'elsewhere' },
	       { id => 'clone', type => 'apache', remote => '*', clone => 'other' },
	       { id => 'group', type => 'apache', remote => '*', groups => 'dns' },
	       { id => 'ambiguous', type => 'fpm', remote => '*' },
	       { id => 'instance', type => 'fpm', remote => '*',
		 dashboard_service => 'example::php-8.4' } );
my %matches = match_dashboard_services(\@checks, \@provided);
is_deeply([ sort keys %matches ], [ 'instance', 'web' ],
	  'only unambiguous local services receive provider controls');
is($matches{'instance'}->{'id'}, 'example::php-8.4',
   'the explicit service ID picks the correct PHP version');
# A translated configuration form must retain an existing list preference.
{
	require "$root/config-lib.pl";
	our (@lang_order_list, %in);
	foreach my $lang (qw(de fr ca)) {
		local @lang_order_list = ($lang);
		my $fields = read_config_fields("$root/status/config.info");
		my %settings = ( sysinfo => 2 );
		my $html = '';
		open(my $fh, '>', \$html) or die $!;
		my $old = select($fh);
		print ui_table_start(undef, undef, 2);
		generate_config(\%settings, $fields, undef, { sysinfo => 1 });
		print ui_table_end();
		select($old);
		close($fh);
		# Save the selected radio value as an unchanged form would
		my ($selected) = $html =~ /<input(?=[^>]*\bname=['"]sysinfo['"])(?=[^>]*\bchecked\b)[^>]*\bvalue=['"]([^'"]+)/;
		is($selected, 2, "$lang form selects the saved list layout");
		local %in = ( sysinfo => $selected );
		parse_config(\%settings, $fields, undef, { sysinfo => 1 });
		is($settings{'sysinfo'}, 2, "$lang save preserves the list layout");
	}
}
# Sort saved monitor results and provider services through both renderers
{
	no warnings qw(redefine once);
	fixture('status/services/multi.serv',
		"id=multi\ntype=exec\ndesc=Multi check\nremote=zeta alpha\n");
	fixture('status/oldstatus',
		"first=1\nsecond=example=0\nthird=1\nmulti=zeta=1 alpha=-3\n");
	local *main::module_dashboard_monitors = sub {
		return ( { id => 'example::ban', desc => 'Paired service',
			   up => 0, type => 'fail2ban', provider => 'example',
			   remote => '*' },
			 { id => 'example::extra', desc => 'Provider check',
			   up => 1, provider => 'example', remote => '*' } );
		};
	my @original = ( (map { $_->{'desc'} } list_services()),
			'Provider check' );
	my @local = grep { $_ ne 'Remote check' && $_ ne 'Multi check' }
			@original;
	my @down = grep { $_ eq 'Remote check' || $_ eq 'Ban check' }
			@original;
	my @up = grep { $_ eq 'Local check' || $_ eq 'Provider check' }
			@original;
	my @expected = ( \@original, [ sort @original ],
		[ @local, 'Remote check', 'Multi check' ],
		[ 'Multi check', @down, @up, 'New check' ] );
	foreach my $layout (1, 2) {
		local $config{'sysinfo'} = $layout;
		foreach my $mode (0 .. 3) {
			local $config{'sort_mode'} = $mode;
			my $html = panel();
			my @names = $html =~ /((?:Local|Remote|Ban|New|Multi|Provider) check)/g;
			is_deeply(\@names, $expected[$mode],
				  "layout $layout follows monitor sort mode $mode");
			}
		}
	like(panel(), qr/>zeta<br>\s*alpha<\/td>/,
	     'list mode puts each remote host on its own line');
}
done_testing();
