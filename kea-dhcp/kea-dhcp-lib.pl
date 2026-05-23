# kea-dhcp-lib.pl
# Helpers for the ISC Kea DHCP Webmin module.

BEGIN { push(@INC, ".."); };    ## no critic
use strict;
use warnings;
use WebminCore;

our (%config, %in, %text);
our $module_root_directory;

&init_config();
&load_kea_defaults();

# kea_acl_keys()
# Returns the supported Kea DHCP ACL capabilities.
sub kea_acl_keys
{
return qw(dhcp4 dhcp6 ddns services runtime edit4 edit6 editddns manual apply install);
}

# kea_effective_acl([&raw-acl])
# Returns normalized ACL settings for the current Webmin user.
sub kea_effective_acl
{
my ($rawacl) = @_;
my %raw = $rawacl ? %$rawacl : &get_module_acl();
return map { $_ => $raw{$_} ? 1 : 0 } &kea_acl_keys();
}

# kea_check_acl(action, [&raw-acl])
# Returns true when an effective ACL permits the requested action.
sub kea_check_acl
{
my ($action, $rawacl) = @_;
my %acl = &kea_effective_acl($rawacl);
return $acl{$action} ? 1 : 0;
}

# kea_assert_acl(action)
# Fails if the current Webmin user cannot perform an action.
sub kea_assert_acl
{
my ($action) = @_;
&kea_check_acl($action) ||
	&error("$text{'eacl_np'} $text{'eacl_p'.$action}");
}

# kea_can_enter_module(&acl)
# Returns true if a user has at least one useful module capability.
sub kea_can_enter_module
{
my ($acl) = @_;
foreach my $a (&kea_acl_keys()) {
	return 1 if ($acl->{$a});
	}
return 0;
}

# kea_can_view_dhcp(&acl, version)
# Structured edit access implies read access to that DHCP version.
sub kea_can_view_dhcp
{
my ($acl, $ver) = @_;
return $acl->{'dhcp'.$ver} || $acl->{'edit'.$ver} ? 1 : 0;
}

# kea_can_edit_dhcp(&acl, version)
# Returns true if the user may change structured DHCPv4 or DHCPv6 settings.
sub kea_can_edit_dhcp
{
my ($acl, $ver) = @_;
return $acl->{'edit'.$ver} ? 1 : 0;
}

# kea_can_view_ddns(&acl)
# DHCP-DDNS edit access implies read access to the D2 daemon settings.
sub kea_can_view_ddns
{
my ($acl) = @_;
return $acl->{'ddns'} || $acl->{'editddns'} ? 1 : 0;
}

# kea_can_edit_ddns(&acl)
# Returns true if the user may change structured DHCP-DDNS settings.
sub kea_can_edit_ddns
{
my ($acl) = @_;
return $acl->{'editddns'} ? 1 : 0;
}

# kea_can_view_services(&acl)
# Service control implies enough service visibility to choose the right action.
sub kea_can_view_services
{
my ($acl) = @_;
return $acl->{'services'} || $acl->{'apply'} ? 1 : 0;
}

# kea_can_view_runtime(&acl)
# Returns true if the user may view lease, pool, statistics, and log data.
sub kea_can_view_runtime
{
my ($acl) = @_;
return $acl->{'runtime'} ? 1 : 0;
}

# load_kea_defaults()
# When a new module is copied into an existing Webmin install, its runtime
# config file may not exist yet even though config.cgi can still display
# defaults from config.info. Fill missing runtime values from the module's
# bundled config so the module works before the first Save on the config page.
sub load_kea_defaults
{
my %defaults;
&read_file($module_root_directory."/config", \%defaults)
	if ($module_root_directory && -r $module_root_directory."/config");
foreach my $k (keys %defaults) {
	if (!defined($config{$k}) || $config{$k} eq '') {
		$config{$k} = $defaults{$k};
		}
	}
}

# kea_config_value(key)
# Returns a module configuration value after defaults have been loaded.
sub kea_config_value
{
my ($key) = @_;
return $config{$key};
}

# kea_components()
# Returns descriptors for the Kea services this module knows how to inspect.
sub kea_components
{
return (
	{ 'id' => 'dhcp4', 'root' => 'Dhcp4',
	  'conf' => 'dhcp4_conf', 'path' => 'dhcp4_path',
	  'pid' => 'dhcp4_pid_file', 'proc' => 'kea-dhcp4',
	  'unit' => &kea_config_value('dhcp4_unit'),
	  'label' => $text{'comp_dhcp4'} || 'DHCPv4' },
	{ 'id' => 'dhcp6', 'root' => 'Dhcp6',
	  'conf' => 'dhcp6_conf', 'path' => 'dhcp6_path',
	  'pid' => 'dhcp6_pid_file', 'proc' => 'kea-dhcp6',
	  'unit' => &kea_config_value('dhcp6_unit'),
	  'label' => $text{'comp_dhcp6'} || 'DHCPv6' },
	{ 'id' => 'ddns', 'root' => 'DhcpDdns',
	  'conf' => 'ddns_conf', 'path' => 'ddns_path',
	  'pid' => 'ddns_pid_file', 'proc' => 'kea-dhcp-ddns',
	  'unit' => &kea_config_value('ddns_unit'),
	  'label' => $text{'comp_ddns'} || 'DHCP-DDNS' },
	{ 'id' => 'ctrl', 'root' => 'Control-agent',
	  'conf' => 'ctrl_agent_conf', 'path' => 'ctrl_agent_path',
	  'pid' => 'ctrl_agent_pid_file', 'proc' => 'kea-ctrl-agent',
	  'unit' => &kea_config_value('ctrl_agent_unit'),
	  'label' => $text{'comp_ctrl'} || 'Control Agent' },
	);
}

# kea_component(id)
# Looks up one Kea component descriptor by its internal module id.
sub kea_component
{
my ($id) = @_;
foreach my $c (&kea_components()) {
	return $c if ($c->{'id'} eq $id);
	}
return;
}

# kea_dhcp_component(version)
# Returns the DHCPv4 or DHCPv6 component descriptor for a numeric version.
sub kea_dhcp_component
{
my ($ver) = @_;
return &kea_component($ver == 6 ? 'dhcp6' : 'dhcp4');
}

# kea_component_systemd_unit(&component)
# Returns the configured systemd unit for this component. Distro-specific unit
# names belong in config-* defaults rather than guessed at runtime.
sub kea_component_systemd_unit
{
my ($c) = @_;
return $c->{'unit'} || "";
}

# kea_subnet_key(version)
# Returns the Kea JSON subnet array key for DHCPv4 or DHCPv6.
sub kea_subnet_key
{
my ($ver) = @_;
return $ver == 6 ? 'subnet6' : 'subnet4';
}

# kea_config_file(&component)
# Returns the configured JSON file path for a component descriptor.
sub kea_config_file
{
my ($c) = @_;
return &kea_config_value($c->{'conf'});
}

# kea_editable_components()
# Returns components that have a configured file path for manual editing.
sub kea_editable_components
{
my @rv;
foreach my $c (&kea_components()) {
	push(@rv, $c) if (&kea_config_file($c));
	}
return @rv;
}

# kea_control_agent_password_files()
# Returns password files referenced by the Kea Control Agent authentication
# section, plus the packaged default derived from the Control Agent config dir.
sub kea_control_agent_password_files
{
my @rv;
my $c = &kea_component('ctrl');
my $file = &kea_config_file($c);
return @rv if (!$file);

# Debian-style packages gate the Control Agent with this file even when the
# config only refers to it by a relative name.
my $dir = &kea_dirname($file);
my $default = "$dir/kea-api-password";
$default = &simplify_path($default) if ($default =~ /^\//);
push(@rv, $default);
if (-r $file) {
	my ($root, $err) = &kea_read_component_config($c);
	if (!$err && ref($root->{'authentication'}) eq 'HASH') {
		my $auth = $root->{'authentication'};
		my $base = $auth->{'directory'} || $dir;
		my $clients = $auth->{'clients'};
		if (ref($clients) eq 'ARRAY') {
			foreach my $client (@$clients) {
				next if (ref($client) ne 'HASH');
				my $pfile = $client->{'password-file'};
				next if (!defined($pfile) || $pfile eq '');

				# Kea resolves relative password-file values below
				# authentication/directory.
				my $path = $pfile =~ /^\// ? $pfile : "$base/$pfile";
				$path = &simplify_path($path) if ($path =~ /^\//);
				push(@rv, $path) if ($path);
				}
			}
		}
	}
return grep { $_ } &unique(@rv);
}

# kea_manual_edit_files()
# Returns descriptors for files the raw editor may manage.
sub kea_manual_edit_files
{
my (@rv, %seen);

# Manual editing is deliberately limited to configured Kea files. This prevents
# the raw editor from becoming a general-purpose filesystem editor.
foreach my $c (&kea_editable_components()) {
	my $file = &kea_config_file($c);
	next if (!$file || $seen{$file}++);
	push(@rv, { 'file' => $file, 'type' => 'config',
		    'component' => $c });
	}

# Include Control Agent password files because a missing password can make the
# unit look inactive without any broken JSON to edit.
foreach my $file (&kea_control_agent_password_files()) {
	next if (!$file || $seen{$file}++);
	push(@rv, { 'file' => $file, 'type' => 'password' });
	}
return @rv;
}

# kea_manual_edit_file(file)
# Returns the manual-edit descriptor for an allowed file path.
sub kea_manual_edit_file
{
my ($file) = @_;
foreach my $f (&kea_manual_edit_files()) {
	return $f if ($f->{'file'} eq $file);
	}
return;
}

# kea_any_installed()
# Returns true when at least one configured Kea executable exists.
sub kea_any_installed
{
return 1 if (&has_command(&kea_config_value('keactrl_path')));
foreach my $c (&kea_components()) {
	return 1 if (&has_command(&kea_config_value($c->{'path'})));
	}
return 0;
}

# kea_any_configured()
# Returns true when at least one configured Kea config file is readable.
sub kea_any_configured
{
foreach my $c (&kea_components()) {
	my $file = &kea_config_file($c);
	return 1 if ($file && -r $file);
	}
return 0;
}

# kea_component_pid(&component)
# Finds the running process ID for a Kea component.
sub kea_component_pid
{
my ($c) = @_;

# Prefer distro PID files when configured, then fall back to process lookup for
# systems that run Kea without the expected pidfile names.
foreach my $pidfile (split(/\s+/, &kea_config_value($c->{'pid'}) || "")) {
	my $pid = &check_pid_file($pidfile);
	return $pid if ($pid);
	}
my ($pid) = &find_byname($c->{'proc'});
return $pid;
}

# kea_component_status(&component)
# Returns normalized runtime status for a Kea component.
sub kea_component_status
{
my ($c) = @_;
our %kea_component_status_cache;
return $kea_component_status_cache{$c->{'id'}}
	if (exists($kea_component_status_cache{$c->{'id'}}));

my $pid = &kea_component_pid($c);
my $status = {
	'state' => $pid ? 'running' : 'stopped',
	'pid' => $pid,
	'manager' => 'process',
	'details' => [ ],
	'logs' => [ ],
	};

# systemd is the source of truth for failed/skipped services; PID checks alone
# cannot distinguish a clean stop from a failed start or unmet condition.
my $systemctl = &has_command('systemctl');
my $unit = &kea_component_systemd_unit($c);
if ($systemctl && $unit) {
	my $props = &kea_systemd_unit_properties($unit);
	if (%$props) {
		$status->{'manager'} = 'systemd';
		$status->{'unit'} = $unit;
		$status->{'active'} = $props->{'ActiveState'};
		$status->{'sub'} = $props->{'SubState'};
		$status->{'result'} = $props->{'Result'};
		$status->{'condition_result'} = $props->{'ConditionResult'};
		$status->{'unit_file_state'} = $props->{'UnitFileState'};
		if ($props->{'MainPID'} =~ /^\d+$/ && $props->{'MainPID'} > 0) {
			$status->{'pid'} = $props->{'MainPID'};
			}
		if ($props->{'LoadState'} && $props->{'LoadState'} eq 'not-found') {
			$status->{'state'} = $status->{'pid'} ? 'running' : 'unknown';
			push(@{$status->{'details'}}, $text{'status_unit_missing'});
			}
		elsif ($props->{'ActiveState'} eq 'active') {
			$status->{'state'} = 'running';
			}
		elsif ($props->{'ActiveState'} eq 'failed') {
			$status->{'state'} = 'failed';
			}
		elsif ($props->{'ActiveState'} eq 'activating') {
			$status->{'state'} = 'starting';
			}
		elsif ($props->{'ActiveState'} eq 'deactivating') {
			$status->{'state'} = 'stopping';
			}
		elsif ($props->{'Result'} eq 'condition' ||
		       defined($props->{'ConditionResult'}) &&
		       $props->{'ConditionResult'} eq 'no') {
			$status->{'state'} = 'skipped';
			}
		elsif ($props->{'ActiveState'} eq 'inactive') {
			$status->{'state'} = 'stopped';
			}
		else {
			$status->{'state'} = $status->{'pid'} ? 'running' : 'unknown';
			}

		# Only attach detailed logs to abnormal states so the services
		# table stays compact when everything is healthy.
		if ($status->{'state'} eq 'failed' ||
		    $status->{'state'} eq 'skipped') {
			push(@{$status->{'details'}},
			     &text('status_result', $props->{'Result'}))
				if ($props->{'Result'} && $props->{'Result'} ne 'success');
			push(@{$status->{'details'}}, $text{'status_condition_unmet'})
				if ($status->{'state'} eq 'skipped');
			push(@{$status->{'details'}},
			     &text('status_exit', $props->{'ExecMainStatus'}))
				if ($props->{'ExecMainStatus'} =~ /^\d+$/ &&
				    $props->{'ExecMainStatus'} != 0);
			$status->{'logs'} = &kea_systemd_unit_logs(
				$unit, $status->{'state'});
			}
		}
	}
return $kea_component_status_cache{$c->{'id'}} = $status;
}

# kea_systemd_unit_properties(unit)
# Reads selected systemd properties for a configured unit.
sub kea_systemd_unit_properties
{
my ($unit) = @_;
my $systemctl = &has_command('systemctl');
return { } if (!$systemctl);

# Query explicit properties instead of parsing localized systemctl status text.
my $cmd = &quote_path($systemctl).
	  " show --no-pager --property=LoadState,ActiveState,SubState,".
	  "Result,MainPID,ExecMainStatus,ExecMainCode,UnitFileState,".
	  "ConditionResult ".
	  quotemeta($unit)." 2>/dev/null";
my $out = &backquote_command($cmd);
return { } if ($? || $out !~ /\S/);
my %props;
foreach my $line (split(/\r?\n/, $out)) {
	my ($name, $value) = split(/=/, $line, 2);
	$props{$name} = $value if ($name ne '');
	}
return \%props;
}

# kea_systemd_unit_logs(unit, state)
# Returns recent systemd journal lines relevant to a component state.
sub kea_systemd_unit_logs
{
my ($unit, $state) = @_;
my $journalctl = &has_command('journalctl');
return [ ] if (!$journalctl);
if ($state eq 'skipped') {
	# Skipped units usually need the unmet condition rather than ordinary
	# warnings.
	my @condition = &kea_recent_unique_lines(grep {
		/\b(condition|skipped|unmet)\b/i
		} &kea_journal_lines($journalctl, $unit, "", 12));
	return [ @condition > 3 ?
		 @condition[$#condition-2 .. $#condition] : @condition ]
		if (@condition);
	}
if ($state eq 'failed') {
	# Kea emits the real config/parser error in its daemon log line; prefer
	# that over generic systemd process-exit messages.
	my @errors = &kea_recent_unique_lines(grep {
			&kea_is_relevant_error_line($_)
		} &kea_journal_lines($journalctl, $unit, "", 20));
	return [ @errors > 3 ? @errors[$#errors-2 .. $#errors] : @errors ]
		if (@errors);
	}

# For non-failure states, keep the newest useful log lines as optional context.
my @logs = &kea_recent_unique_lines(grep { !&kea_is_low_value_unit_line($_) }
	&kea_journal_lines($journalctl, $unit, "--priority warning"));
@logs = &kea_recent_unique_lines(&kea_journal_lines($journalctl, $unit, ""))
	if (!@logs);
return [ @logs > 3 ? @logs[$#logs-2 .. $#logs] : @logs ];
}

# kea_is_relevant_error_line(line)
# Returns true for journal lines likely to contain actionable Kea errors.
sub kea_is_relevant_error_line
{
my ($line) = @_;
return 0 if (&kea_is_low_value_unit_line($line));
return $line =~ /\b(ERROR|_FAIL|failed to initialize|configuration error|parser|unexpected keyword|invalid)\b/i;
}

# kea_is_low_value_unit_line(line)
# Filters generic systemd noise from service diagnostics.
sub kea_is_low_value_unit_line
{
my ($line) = @_;
return $line =~ /ConfigurationDirectory .* mode is different/i ||
       $line =~ /Main process exited/i ||
       $line =~ /Failed with result/i;
}

# kea_recent_unique_lines(lines...)
# Keeps the newest copy of repeated journal messages.
sub kea_recent_unique_lines
{
my @lines = @_;
my (%seen, @rv);
for(my $i=$#lines; $i>=0; $i--) {
	my $key = $lines[$i];

	# De-duplicate retries of the same failure while preserving the newest
	# text.
	$key =~ s/\d{4}-\d\d-\d\d\s+\d\d:\d\d:\d\d(?:\.\d+)?/<time>/g;
	$key =~ s/\bpid:\s*\d+/pid:<pid>/ig;
	$key =~ s#/(\d+)\.#/<pid>.#g;
	next if ($seen{$key}++);
	unshift(@rv, $lines[$i]);
	}
return @rv;
}

# kea_journal_lines(journalctl, unit, extra-args, [lines])
# Reads normalized recent journal lines for one systemd unit.
sub kea_journal_lines
{
my ($journalctl, $unit, $extra, $lines) = @_;
$lines ||= 6;
my $cmd = &quote_path($journalctl)." --unit ".quotemeta($unit).
	  " --lines ".int($lines)." --no-pager --output cat ".
	  ($extra ? $extra." " : "")."2>/dev/null";
my $out = &backquote_command($cmd);
return ( ) if ($?);
my @lines;
foreach my $line (split(/\r?\n/, $out)) {
	$line =~ s/^\s+|\s+$//g;
	next if ($line eq '');
	push(@lines, &kea_short_text($line, 180));
	}
return @lines;
}

# kea_short_text(text, max-length)
# Truncates long service messages for compact table display.
sub kea_short_text
{
my ($text, $max) = @_;
$max ||= 180;
return length($text) > $max ? substr($text, 0, $max - 3)."..." : $text;
}

# kea_running_pids()
# Returns process IDs for Kea components currently considered running.
sub kea_running_pids
{
my @rv;
foreach my $c (&kea_components()) {
	my $status = &kea_component_status($c);
	push(@rv, $status->{'pid'} || 1) if ($status->{'state'} eq 'running');
	}
return @rv;
}

# kea_parse_config_file(file)
# Reads and parses a Kea config file into a Perl data structure.
sub kea_parse_config_file
{
my ($file) = @_;
my $text = &read_file_contents($file);
die &text('file_eread', $file) if (!defined($text));
return &kea_parse_config_text($text, $file);
}

# kea_parse_config_text(text, file)
# Parses Kea JSON text after expanding include directives.
sub kea_parse_config_text
{
my ($text, $file) = @_;
my $dir = &kea_dirname($file);

# Kea supports <?include "..."> fragments; expand them before handing the
# result to Webmin's relaxed JSON reader.
$text = &kea_expand_includes($text, $dir, 0);
my $data = eval { &convert_from_json($text, undef, 1) };
die &text('parse_ejson', $@) if ($@);
return $data;
}

# kea_encode_config(&data)
# Serializes a Kea config object as stable, pretty JSON for structured saves.
sub kea_encode_config
{
my ($data) = @_;

# Structured edits intentionally save clean, pretty JSON. Comments from distro
# sample configs are not preserved after the first structured save.
return &convert_to_json($data, 1);
}

# kea_config_has_comments(file)
# Detects comment syntax that will be removed by structured JSON saves.
sub kea_config_has_comments
{
my ($file) = @_;
return 0 if (!$file || !-r $file);
my $text = &read_file_contents($file);
return 0 if (!defined($text));

# Kea package examples commonly use whole-line JSONC comments. Detecting those
# is enough to warn before a structured save normalizes the file to plain JSON.
return $text =~ m{^\s*(?://|#|/\*)}m ? 1 : 0;
}

# kea_comment_loss_warning(&component, ...)
# Builds the warning shown before saving comment-bearing config files.
sub kea_comment_loss_warning
{
my @components = @_;
my @files;
foreach my $c (@components) {
	next if (!$c);
	my $file = &kea_config_file($c);
	push(@files, $file) if (&kea_config_has_comments($file));
	}
return "" if (!@files);

# Name the exact config file so users know which Kea daemon will be rewritten
# when a settings page is saved.
my $list = join(", ", map { &ui_tag('tt', &html_escape($_)) } @files);
my $msg = @files == 1 ? &text('comments_loss_warning', $list) :
			&text('comments_loss_warning_multi', $list);
return &ui_alert_box($msg, "success", undef, undef, "");
}

# kea_expand_includes(text, base-dir, depth)
# Expands Kea <?include "..."> directives recursively.
sub kea_expand_includes
{
my ($text, $base, $depth) = @_;
die $text{'include_edepth'} if ($depth > 10);

# The substitution calls back into kea_include_file so nested includes inherit
# their own base directory.
$text =~ s/<\?include\s+"([^"]+)"\s*\?>/&kea_include_file($1, $base, $depth)/ge;
return $text;
}

# kea_include_file(path, base-dir, depth)
# Reads and expands one Kea include target.
sub kea_include_file
{
my ($inc, $base, $depth) = @_;
my $file = $inc =~ /^\// ? $inc :
	   -r "$base/$inc" ? "$base/$inc" : $inc;
my $text = &read_file_contents($file);
die &text('include_eread', $file) if (!defined($text));
$text = &kea_expand_includes($text, &kea_dirname($file), $depth + 1);

# Kea commonly includes a JSON object inside another object and merges its
# members. Stripping the outer braces lets normal JSON parsers read that shape.
my $trim = $text;
$trim =~ s/^\s+//;
$trim =~ s/\s+$//;
if ($trim =~ /^\{(.*)\}$/s) {
	return $1;
	}
return $text;
}

# kea_dirname(file)
# Returns the containing directory for a path.
sub kea_dirname
{
my ($file) = @_;
$file =~ s/\/[^\/]*$//;
return $file || ".";
}

# kea_read_component_config(&component)
# Reads one component config and returns its root object.
sub kea_read_component_config
{
my ($c) = @_;
my $file = &kea_config_file($c);
return (undef, &text('config_missing', '')) if (!$file);
return (undef, &text('config_missing', $file)) if (!-e $file);
return (undef, &text('config_unreadable', $file)) if (!-r $file);
my $data = eval { &kea_parse_config_file($file) };
return (undef, $@) if ($@);
if (ref($data->{$c->{'root'}}) ne 'HASH') {
	return (undef, &text('parse_eroot', $c->{'root'}));
	}
return ($data->{$c->{'root'}}, undef, $data);
}

# kea_read_dhcp_config(version)
# Reads the DHCPv4 or DHCPv6 component config.
sub kea_read_dhcp_config
{
my ($ver) = @_;
my $c = &kea_dhcp_component($ver);
my ($root, $err, $data) = &kea_read_component_config($c);
return ($c, $root, $data, $err);
}

# kea_save_component_config(&component, &data)
# Validates and writes a component config file.
sub kea_save_component_config
{
my ($c, $data) = @_;
my $file = &kea_config_file($c);
return $text{'save_efile'} if (!$file);
my $json = eval { &kea_encode_config($data) };
return $@ if ($@);
my $verr = &kea_validate_component_json($c, $json);
return $verr if ($verr);

# Use Webmin's lock/tempfile path so concurrent UI edits and backups see a
# normal module-managed config write.
&lock_file($file);
my $fh;
&open_tempfile($fh, ">$file");
&print_tempfile($fh, $json);
&close_tempfile($fh);
&unlock_file($file);
return;
}

# kea_validate_component_json(&component, json)
# Runs Kea's native config test before replacing a live daemon file. Test
# fixtures often point component paths at perl itself, so only execute real Kea
# binaries whose basename matches the component descriptor.
sub kea_validate_component_json
{
my ($c, $json) = @_;
my $cmd = &kea_config_value($c->{'path'});
return if (!$cmd || !-x $cmd);
my $base = $cmd;
$base =~ s/^.*\///;
return if ($base ne $c->{'proc'});

# Debian's Kea AppArmor profile permits reading /etc/kea/** but denies
# Webmin's normal /tmp/.webmin candidates. Validate from the same directory as
# the live config so Kea sees the file through its packaged security policy.
my $file = &kea_config_file($c);
my $dir = &kea_dirname($file);
my $tmp = $dir."/".$c->{'proc'}."-test-".
	  &substitute_pattern('[a-f0-9]{6}').".conf";
push(@main::temporary_files, $tmp);
my $fh;
if (!&open_tempfile($fh, ">$tmp", 1)) {
	return &text('save_etemp', $tmp, $!);
	}
&print_tempfile($fh, $json);
if (!&close_tempfile($fh)) {
	return &text('save_etemp', $tmp, $!);
	}

my @st = $file ? stat($file) : ( );
my $mode = @st ? $st[2] & 07777 : 0644;
if (!chmod($mode, $tmp)) {
	my $cerr = $!;
	&unlink_file($tmp);
	return &text('save_etemp', $tmp, $cerr);
	}
if (@st && $> == 0 && !chown($st[4], $st[5], $tmp)) {
	my $cerr = $!;
	&unlink_file($tmp);
	return &text('save_etemp', $tmp, $cerr);
	}

my ($out, $err);
my $rv = &execute_command(quotemeta($cmd)." -t ".quotemeta($tmp),
			  undef, \$out, \$err, 0, 1);
&unlink_file($tmp);
return if (!$rv);

my $msg = $err || $out || &text('save_evalidate_empty');
$msg =~ s/\r//g;
$msg =~ s/^\s+//;
$msg =~ s/\s+$//;
return &text('save_evalidate', $c->{'label'}, $msg);
}

# kea_shared_networks(&root)
# Returns the shared-networks array, creating an empty one if needed.
sub kea_shared_networks
{
my ($root) = @_;

# Normalize missing shared-networks to an array so callers can safely mutate it.
$root->{'shared-networks'} = [ ] if (ref($root->{'shared-networks'}) ne 'ARRAY');
return $root->{'shared-networks'};
}

# kea_subnet_list(&root, version, [shared-index])
# Returns top-level or shared-network subnet arrays.
sub kea_subnet_list
{
my ($root, $ver, $sidx) = @_;
my $key = &kea_subnet_key($ver);
my $parent = $sidx ne '' ? &kea_shared_networks($root)->[$sidx] : $root;
return [ ] if (ref($parent) ne 'HASH');

# Top-level and shared-network subnets use the same key, only with different
# parents.
$parent->{$key} = [ ] if (ref($parent->{$key}) ne 'ARRAY');
return $parent->{$key};
}

# kea_valid_subnet_parent(&root, [shared-index])
# Returns true when a subnet parent index is top-level or an existing shared network.
sub kea_valid_subnet_parent
{
my ($root, $sidx) = @_;
return 1 if (!defined($sidx) || $sidx eq '');
return 0 if ($sidx !~ /^\d+$/);

# Reject negative and out-of-range parent indexes before Perl can treat them as
# reverse array indexes.
return ref(&kea_shared_networks($root)->[$sidx]) eq 'HASH';
}

# kea_get_subnet(&root, version, [shared-index], subnet-index)
# Returns one subnet object from its stored location.
sub kea_get_subnet
{
my ($root, $ver, $sidx, $idx) = @_;
return &kea_subnet_list($root, $ver, $sidx)->[$idx];
}

# kea_all_subnets(&root, version)
# Returns every subnet with location metadata for editing and deletion.
sub kea_all_subnets
{
my ($root, $ver) = @_;
my @rv;

# Return both top-level subnets and subnets nested below shared networks with
# enough location metadata for edit/delete links.
my $top = &kea_subnet_list($root, $ver, "");
for(my $i=0; $i<@$top; $i++) {
	push(@rv, { 'sidx' => '', 'idx' => $i, 'subnet' => $top->[$i] });
	}
my $shareds = &kea_shared_networks($root);
for(my $s=0; $s<@$shareds; $s++) {
	my $subs = &kea_subnet_list($root, $ver, $s);
	for(my $i=0; $i<@$subs; $i++) {
		push(@rv, { 'sidx' => $s, 'idx' => $i,
			    'shared' => $shareds->[$s], 'subnet' => $subs->[$i] });
		}
	}
return @rv;
}

# kea_next_subnet_id(&root, version)
# Finds the next unused numeric subnet id.
sub kea_next_subnet_id
{
my ($root, $ver) = @_;
my $max = 0;
foreach my $s (&kea_all_subnets($root, $ver)) {
	my $id = $s->{'subnet'}->{'id'};
	$max = $id if ($id =~ /^\d+$/ && $id > $max);
	}
return $max + 1;
}

# kea_lease_file(version, [&root])
# Resolves the memfile lease CSV path for a DHCP version.
sub kea_lease_file
{
my ($ver, $root) = @_;
if (!$root) {
	my (undef, $read_root, undef, $err) = &kea_read_dhcp_config($ver);
	return ("", $err) if ($err);
	$root = $read_root;
	}
my $db = ref($root->{'lease-database'}) eq 'HASH' ?
	 $root->{'lease-database'} : { };
my $type = lc($db->{'type'} || 'memfile');
return ("", &text('leases_backend_unsupported', $type))
	if ($type ne 'memfile');
my $default = &kea_config_value('dhcp'.$ver.'_lease_file') || "";
my $name = $db->{'name'} || "";
return ($name, undef) if ($name =~ /^\//);
return (&kea_dirname($default)."/".$name, undef) if ($name && $default =~ /^\//);
return ($default, undef);
}

# kea_read_leases(version)
# Reads Kea memfile CSV leases and returns parsed rows, error text, and path.
sub kea_read_leases
{
my ($ver) = @_;
my (undef, $root, undef, $err) = &kea_read_dhcp_config($ver);
return ([ ], $err, "") if ($err);
my ($file, $ferr) = &kea_lease_file($ver, $root);
return ([ ], $ferr, $file) if ($ferr);
return ([ ], $text{'leases_enofile'}, $file) if (!$file);
return ([ ], &text('leases_missing', $file), $file) if (!-e $file);
return ([ ], &text('leases_unreadable', $file), $file) if (!-r $file);
my $text = &read_file_contents($file);
my @lines = split(/\r?\n/, $text);
my @heads;
my @leases;
foreach my $line (@lines) {
	$line =~ s/^\s+|\s+$//g;
	next if ($line eq '' || $line =~ /^#/);
	my @cols = &kea_csv_fields($line);
	if (!@heads) {
		@heads = map { &kea_normalize_lease_field($_) } @cols;
		next;
		}
	my %lease;
	for(my $i=0; $i<@heads; $i++) {
		$lease{$heads[$i]} = defined($cols[$i]) ? $cols[$i] : "";
		}
	push(@leases, \%lease);
	}
return (\@leases, undef, $file);
}

# kea_csv_fields(line)
# Parses one Kea memfile CSV row using Perl's standard quoted-field parser.
sub kea_csv_fields
{
my ($line) = @_;
eval "use Text::ParseWords ();";
return split(/,/, $line, -1) if ($@);
my @cols = Text::ParseWords::parse_line(',', 0, $line);
return @cols;
}

# kea_normalize_lease_field(field)
# Converts CSV header names to hash keys that are easy to read in the UI.
sub kea_normalize_lease_field
{
my ($field) = @_;
$field = lc($field || "");
$field =~ s/^\s+|\s+$//g;
$field =~ s/[-\s]+/_/g;
return $field;
}

# kea_active_leases(version)
# Returns active leases for a DHCP version, preserving file/error context.
sub kea_active_leases
{
my ($ver) = @_;
my ($leases, $err, $file) = &kea_read_leases($ver);
return ([ grep { &kea_lease_is_active($_) } @$leases ], $err, $file);
}

# kea_lease_is_active(&lease)
# Returns true for leases Kea still considers usable by clients.
sub kea_lease_is_active
{
my ($lease) = @_;
my $state = $lease->{'state'};
return 0 if (defined($state) && $state ne '' && $state ne '0');
my $expire = $lease->{'expire'};
return 1 if (!defined($expire) || $expire eq '' || $expire !~ /^\d+$/);
return $expire == 0 || $expire > time() ? 1 : 0;
}

# kea_lease_address(&lease)
# Returns the address or delegated prefix shown for one lease.
sub kea_lease_address
{
my ($lease) = @_;
return $lease->{'address'} || $lease->{'ip_address'} ||
       $lease->{'prefix'} || "";
}

# kea_lease_identifier(&lease)
# Returns the most useful client identity from one DHCP lease row.
sub kea_lease_identifier
{
my ($lease) = @_;
return $lease->{'hwaddr'} || $lease->{'hw_address'} ||
       $lease->{'client_id'} || $lease->{'duid'} ||
       $lease->{'iaid'} || "";
}

# kea_lease_expires(&lease)
# Returns human-readable lease expiration text.
sub kea_lease_expires
{
my ($lease) = @_;
my $expire = $lease->{'expire'};
return $text{'leases_never'} if (defined($expire) && $expire eq '0');
return "" if (!defined($expire) || $expire eq '' || $expire !~ /^\d+$/);
return scalar(localtime($expire));
}

# kea_lease_state(&lease)
# Returns a compact state label for a lease CSV row.
sub kea_lease_state
{
my ($lease) = @_;
my $state = $lease->{'state'};
return $text{'leases_state_active'} if (!defined($state) || $state eq '' ||
					  $state eq '0');
return &text('leases_state_number', $state);
}

# kea_lease_summary(version)
# Counts total, active, and inactive leases for dashboard statistics.
sub kea_lease_summary
{
my ($ver) = @_;
my ($leases, $err, $file) = &kea_read_leases($ver);
my $active = 0;
foreach my $lease (@$leases) {
	$active++ if (&kea_lease_is_active($lease));
	}
return {
	'version' => $ver,
	'file' => $file,
	'error' => $err,
	'total' => scalar(@$leases),
	'active' => $active,
	'inactive' => scalar(@$leases) - $active,
	};
}

# kea_pool_usage_rows(version)
# Builds per-subnet active-lease counts for the pool usage view.
sub kea_pool_usage_rows
{
my ($ver) = @_;
my (undef, $root, undef, $err) = &kea_read_dhcp_config($ver);
return ([ ], $err) if ($err);
my ($leases, $lerr) = &kea_active_leases($ver);
return ([ ], $lerr) if ($lerr && !@$leases);
my %count;
foreach my $lease (@$leases) {
	my $id = $lease->{'subnet_id'} || $lease->{'subnet'};
	$count{$id}++ if (defined($id) && $id ne '');
	}
my @rows;
foreach my $entry (&kea_all_subnets($root, $ver)) {
	my $subnet = $entry->{'subnet'};
	my $id = $subnet->{'id'} || "";
	push(@rows, {
		'id' => $id,
		'subnet' => $subnet->{'subnet'} || "",
		'pools' => ref($subnet->{'pools'}) eq 'ARRAY' ?
			   scalar(@{$subnet->{'pools'}}) : 0,
		'pd_pools' => ref($subnet->{'pd-pools'}) eq 'ARRAY' ?
			      scalar(@{$subnet->{'pd-pools'}}) : 0,
		'reservations' => ref($subnet->{'reservations'}) eq 'ARRAY' ?
				  scalar(@{$subnet->{'reservations'}}) : 0,
		'active' => $count{$id} || 0,
		});
	}
return (\@rows, undef);
}

# kea_recent_component_log_lines(&component, [lines])
# Returns recent journal lines for a component when systemd logs are available.
sub kea_recent_component_log_lines
{
my ($c, $lines) = @_;
my $journalctl = &has_command('journalctl');
my $unit = &kea_component_systemd_unit($c);
return [ ] if (!$journalctl || !$unit);
my @logs = &kea_recent_unique_lines(&kea_journal_lines(
	$journalctl, $unit, "", $lines || 20));
return \@logs;
}

# kea_scope_name(&scope, fallback)
# Returns a display name for a shared network or subnet-like object.
sub kea_scope_name
{
my ($scope, $fallback) = @_;
return $scope->{'name'} || $scope->{'subnet'} || $fallback || "";
}

# kea_get_comment(&scope)
# Reads the Webmin-managed comment from Kea user-context.
sub kea_get_comment
{
my ($scope) = @_;
return ref($scope->{'user-context'}) eq 'HASH' ?
	$scope->{'user-context'}->{'comment'} : undef;
}

# kea_set_comment(&scope, comment)
# Stores or removes the Webmin-managed comment in Kea user-context.
sub kea_set_comment
{
my ($scope, $comment) = @_;
$comment =~ s/^\s+|\s+$//g if (defined($comment));

# Kea stores human comments in user-context; clean up the wrapper when our
# comment is the last value left.
if (!defined($comment) || $comment eq '') {
	delete($scope->{'user-context'}->{'comment'})
		if (ref($scope->{'user-context'}) eq 'HASH');
	delete($scope->{'user-context'})
		if (ref($scope->{'user-context'}) eq 'HASH' &&
		    !keys(%{$scope->{'user-context'}}));
	}
else {
	$scope->{'user-context'} = { }
		if (ref($scope->{'user-context'}) ne 'HASH');
	$scope->{'user-context'}->{'comment'} = $comment;
	}
}

# kea_count_array(&scope, key)
# Safely counts an array field on a Kea config object.
sub kea_count_array
{
my ($scope, $key) = @_;
return ref($scope->{$key}) eq 'ARRAY' ? scalar(@{$scope->{$key}}) : 0;
}

# kea_set_optional(&hash, key, value)
# Stores a form value as a scalar, deleting empty/default values.
sub kea_set_optional
{
my ($hash, $key, $value) = @_;
$value = &kea_trim_form_value($value);

# Empty form fields mean "inherit/default/unset" in Kea, so remove the key.
if ($value eq '') {
	delete($hash->{$key});
	}
elsif ($value =~ /^\d+$/) {
	$hash->{$key} = int($value);
	}
else {
	$hash->{$key} = $value;
	}
}

# kea_set_optional_string(&hash, key, value)
# Stores a form value as a JSON string, even when it looks numeric.
sub kea_set_optional_string
{
my ($hash, $key, $value) = @_;
$value = &kea_trim_form_value($value);
if ($value eq '') {
	delete($hash->{$key});
	}
else {
	$hash->{$key} = $value;
	}
}

# kea_trim_form_value(value)
# Normalizes a submitted scalar form value.
sub kea_trim_form_value
{
my ($value) = @_;
return "" if (!defined($value));
$value =~ s/^\s+|\s+$//g;
return $value;
}

# kea_form_has_prefix(prefix)
# Returns true when a submitted form includes fields for an optional section.
sub kea_form_has_prefix
{
my ($prefix) = @_;
foreach my $k (keys %in) {
	return 1 if (index($k, $prefix) == 0);
	}
return 0;
}

# kea_set_optional_integer(&hash, key, value)
# Stores an optional integer form value after validation.
sub kea_set_optional_integer
{
my ($hash, $key, $value) = @_;
$value = &kea_trim_form_value($value);
if ($value eq '') {
	delete($hash->{$key});
	}
elsif ($value =~ /^\d+$/) {
	$hash->{$key} = int($value);
	}
else {
	&error(&text('field_enumber', $text{'field_'.$key} || $key));
	}
}

# kea_validate_lifetimes(&hash)
# Validates timer ordering for lease lifetime fields.
sub kea_validate_lifetimes
{
my ($hash) = @_;

# Kea accepts these timers independently, but the UI should prevent impossible
# lease timing relationships before saving.
foreach my $pair ([ 'renew-timer', 'rebind-timer' ],
		  [ 'rebind-timer', 'valid-lifetime' ],
		  [ 'min-valid-lifetime', 'valid-lifetime' ],
		  [ 'valid-lifetime', 'max-valid-lifetime' ]) {
	my ($low, $high) = @$pair;
	next if (!defined($hash->{$low}) || !defined($hash->{$high}));
	&error(&text('field_eorder',
		     $text{'field_'.$low} || $low,
		     $text{'field_'.$high} || $high))
		if ($hash->{$low} >= $hash->{$high});
	}
}

# kea_json_bool(value)
# Returns a JSON boolean object compatible with Webmin's JSON encoder.
sub kea_json_bool
{
my ($value) = @_;
eval { require JSON::PP };
return $value ? JSON::PP::true() : JSON::PP::false();
}

# kea_set_optional_bool(&hash, key, value)
# Stores an optional boolean form value after validation.
sub kea_set_optional_bool
{
my ($hash, $key, $value) = @_;
$value = &kea_trim_form_value($value);
if ($value eq '') {
	delete($hash->{$key});
	}
elsif ($value eq 'true' || $value eq '1') {
	$hash->{$key} = &kea_json_bool(1);
	}
elsif ($value eq 'false' || $value eq '0') {
	$hash->{$key} = &kea_json_bool(0);
	}
else {
	&error(&text('field_ebool', $text{'field_'.$key} || $key));
	}
}

# kea_bool_value(value)
# Converts a JSON boolean-ish value back to the UI select value.
sub kea_bool_value
{
my ($value) = @_;
return '' if (!defined($value));
return $value ? 'true' : 'false';
}

# kea_relay_addresses(&hash)
# Returns relay addresses from either old or current Kea relay syntax.
sub kea_relay_addresses
{
my ($hash) = @_;
my $relay = ref($hash->{'relay'}) eq 'HASH' ? $hash->{'relay'} : { };
return @{$relay->{'ip-addresses'}}
	if (ref($relay->{'ip-addresses'}) eq 'ARRAY');
return ($relay->{'ip-address'}) if ($relay->{'ip-address'});
return ( );
}

# kea_set_relay_addresses(&hash, text)
# Stores relay IP addresses using Kea's ip-addresses list form.
sub kea_set_relay_addresses
{
my ($hash, $text) = @_;
my @addrs = grep { $_ ne '' } split(/[,\s]+/, $text || "");
if (@addrs) {

# Always write the modern ip-addresses list form even if older configs used the
# singular ip-address field.
	$hash->{'relay'} = { 'ip-addresses' => \@addrs };
	}
else {
	delete($hash->{'relay'});
	}
}

# kea_ipv4_canonical_subnet(cidr)
# Canonicalizes an IPv4 subnet CIDR by clearing host bits.
sub kea_ipv4_canonical_subnet
{
my ($cidr) = @_;
return if ($cidr !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/);
my @o = ($1, $2, $3, $4);
my $prefix = $5;
return if (grep { $_ > 255 } @o);
return if ($prefix > 32);
my $ip = ($o[0] << 24) | ($o[1] << 16) | ($o[2] << 8) | $o[3];
my $mask = $prefix == 0 ? 0 : (0xffffffff << (32 - $prefix)) & 0xffffffff;
my $net = $ip & $mask;

# Normalize 192.0.2.1/24 to 192.0.2.0/24 to avoid ambiguous subnet selection.
return join(".", (($net >> 24) & 255, ($net >> 16) & 255,
		  ($net >> 8) & 255, $net & 255))."/".$prefix;
}

# kea_ipv4_mask_from_subnet(cidr)
# Calculates the dotted IPv4 subnet mask for a CIDR prefix.
sub kea_ipv4_mask_from_subnet
{
my ($cidr) = @_;
return "" if ($cidr !~ /\/(\d+)$/ || $1 > 32);
my $prefix = $1;
my $mask = $prefix == 0 ? 0 : (0xffffffff << (32 - $prefix)) & 0xffffffff;
return join(".", (($mask >> 24) & 255, ($mask >> 16) & 255,
		  ($mask >> 8) & 255, $mask & 255));
}

# kea_canonical_subnet(cidr, version)
# Applies protocol-specific subnet canonicalization.
sub kea_canonical_subnet
{
my ($cidr, $ver) = @_;
return $ver == 4 ? &kea_ipv4_canonical_subnet($cidr) : $cidr;
}

# kea_common_options(version)
# Returns the curated common DHCP option-data fields for a protocol.
sub kea_common_options
{
my ($ver) = @_;

# Keep only broadly useful option-data fields here. Less-common and vendor
# options remain available through the additional option-data grid.
return $ver == 6 ? (
	[ 'dns-servers', $text{'opt_common_dns-servers'}, 46, 23 ],
	[ 'domain-search', $text{'opt_common_domain-search'}, 46, 24 ],
	[ 'sntp-servers', $text{'opt_common_sntp-servers'}, 46, 31 ],
	[ 'preference', $text{'opt_common_preference'}, 10, 7 ],
	[ 'unicast', $text{'opt_common_unicast'}, 40, 12 ],
	[ 'bootfile-url', $text{'opt_common_bootfile-url'}, 60, 59 ],
	[ 'bootfile-param', $text{'opt_common_bootfile-param'}, 60, 60 ],
	[ 'new-posix-timezone', $text{'opt_common_new-posix-timezone'}, 46, 41 ],
	[ 'new-tzdb-timezone', $text{'opt_common_new-tzdb-timezone'}, 32, 42 ],
	) : (
	[ 'routers', $text{'opt_common_routers'}, 46, 3 ],
	[ 'broadcast-address', $text{'opt_common_broadcast-address'}, 20, 28 ],
	[ 'domain-name', $text{'opt_common_domain-name'}, 40, 15 ],
	[ 'domain-name-servers', $text{'opt_common_domain-name-servers'}, 46, 6 ],
	[ 'domain-search', $text{'opt_common_domain-search'}, 46, 119 ],
	[ 'ntp-servers', $text{'opt_common_ntp-servers'}, 46, 42 ],
	[ 'time-servers', $text{'opt_common_time-servers'}, 46, 4 ],
	[ 'log-servers', $text{'opt_common_log-servers'}, 46, 7 ],
	[ 'root-path', $text{'opt_common_root-path'}, 46, 17 ],
	[ 'tftp-server-name', $text{'opt_common_tftp-server-name'}, 46, 66 ],
	[ 'boot-file-name', $text{'opt_common_boot-file-name'}, 46, 67 ],
	[ 'nis-domain', $text{'opt_common_nis-domain'}, 40, 40 ],
	[ 'nis-servers', $text{'opt_common_nis-servers'}, 46, 41 ],
	[ 'netbios-name-servers', $text{'opt_common_netbios-name-servers'}, 46, 44 ],
	[ 'netbios-scope', $text{'opt_common_netbios-scope'}, 32, 47 ],
	[ 'netbios-node-type', $text{'opt_common_netbios-node-type'}, 10, 46 ],
	[ 'time-offset', $text{'opt_common_time-offset'}, 10, 2 ],
	);
}

# kea_advanced_options(version)
# Returns advanced option-data fields shown outside the common list.
sub kea_advanced_options
{
my ($ver) = @_;
return $ver == 4 ? (
	[ 'dhcp-server-identifier', $text{'opt_common_dhcp-server-identifier'}, 20, 54 ],
	) : ( );
}

# kea_managed_options(version)
# Returns option-data entries Kea manages automatically and Webmin must not edit.
sub kea_managed_options
{
my ($ver) = @_;

# Kea derives subnet-mask from the subnet prefix, so expose it read-only only.
return $ver == 4 ? (
	[ 'subnet-mask', 1 ],
	) : ( );
}

# kea_common_option_names(version)
# Returns common option names for duplicate filtering and parsing.
sub kea_common_option_names
{
my ($ver) = @_;
return map { $_->[0] } &kea_common_options($ver);
}

# kea_common_option_codes(version)
# Returns common option codes for duplicate filtering and parsing.
sub kea_common_option_codes
{
my ($ver) = @_;
return map { $_->[3] } grep { defined($_->[3]) } &kea_common_options($ver);
}

# kea_advanced_option_names(version)
# Returns advanced option names for duplicate filtering and parsing.
sub kea_advanced_option_names
{
my ($ver) = @_;
return map { $_->[0] } &kea_advanced_options($ver);
}

# kea_advanced_option_codes(version)
# Returns advanced option codes for duplicate filtering and parsing.
sub kea_advanced_option_codes
{
my ($ver) = @_;
return map { $_->[3] } grep { defined($_->[3]) } &kea_advanced_options($ver);
}

# kea_managed_option_names(version)
# Returns auto-managed option names that cannot be edited directly.
sub kea_managed_option_names
{
my ($ver) = @_;
return map { $_->[0] } &kea_managed_options($ver);
}

# kea_managed_option_codes(version)
# Returns auto-managed option codes that cannot be edited directly.
sub kea_managed_option_codes
{
my ($ver) = @_;
return map { $_->[1] } &kea_managed_options($ver);
}

# kea_option_code(version, name)
# Looks up a known DHCP option code by name.
sub kea_option_code
{
my ($ver, $name) = @_;
foreach my $o (&kea_common_options($ver), &kea_advanced_options($ver)) {
	return $o->[3] if ($o->[0] eq $name && defined($o->[3]));
	}
return;
}

# kea_option_name(version, code)
# Looks up a known DHCP option name by code.
sub kea_option_name
{
my ($ver, $code) = @_;
foreach my $o (&kea_common_options($ver), &kea_advanced_options($ver)) {
	return $o->[0] if (defined($o->[3]) && defined($code) &&
			   $o->[3] == $code);
	}
return;
}

# kea_known_option(&option, version)
# Returns true when an option-data row maps to a named UI field.
sub kea_known_option
{
my ($o, $ver) = @_;
return 0 if (ref($o) ne 'HASH');
return 1 if ($o->{'name'} && &indexof($o->{'name'},
	(&kea_common_option_names($ver), &kea_advanced_option_names($ver))) >= 0);
return 1 if (defined($o->{'code'}) &&
	     &kea_option_name($ver, $o->{'code'}));
return 0;
}

# kea_same_known_option(&option, name, code)
# Compares an option-data row with a known option by name or code.
sub kea_same_known_option
{
my ($o, $name, $code) = @_;
return 0 if (ref($o) ne 'HASH');
return 1 if ($name ne '' && defined($o->{'name'}) && $o->{'name'} eq $name);
return 1 if (defined($code) && defined($o->{'code'}) && $o->{'code'} == $code);
return 0;
}

# kea_option_value(&options, name, [version])
# Reads the data value for a known option-data entry.
sub kea_option_value
{
my ($opts, $name, $ver) = @_;
$opts = [ ] if (ref($opts) ne 'ARRAY');
my $code = defined($ver) ? &kea_option_code($ver, $name) : undef;

# Match by either canonical name or known option code so numeric configs still
# populate named UI fields.
foreach my $o (@$opts) {
	return $o->{'data'} if (ref($o) eq 'HASH' &&
				(defined($o->{'name'}) && $o->{'name'} eq $name ||
				 defined($code) && defined($o->{'code'}) &&
				 $o->{'code'} == $code));
	}
return "";
}

# kea_set_option_value(&options, version, name, value, [&new-option])
# Updates or removes one known option-data entry.
sub kea_set_option_value
{
my ($opts, $ver, $name, $value, $newopt) = @_;
$opts = [ ] if (ref($opts) ne 'ARRAY');
my $code = &kea_option_code($ver, $name);
my ($found, @keep);

# Replace all existing entries for this known option with at most one updated
# entry, preserving unrelated option-data rows.
foreach my $o (@$opts) {
	if (&kea_same_known_option($o, $name, $code)) {
		if (!$found && defined($value) && $value ne '') {
			my %copy = ref($o) eq 'HASH' ? %$o : ( );
			$copy{'name'} = $name
				if (!$copy{'name'} && !defined($copy{'code'}));
			$copy{'data'} = $value;
			push(@keep, \%copy);
			$found = 1;
			}
		}
	else {
		push(@keep, $o);
		}
	}
if (!$found && defined($value) && $value ne '') {
	my %copy = ref($newopt) eq 'HASH' ? %$newopt :
		   ( 'name' => $name, 'data' => $value );

	# Prefer the original representation when a numeric option row was
	# promoted into a named field.
	$copy{'data'} = $value;
	$copy{'name'} = $name if (!$copy{'name'} && !defined($copy{'code'}));
	push(@keep, \%copy);
	}
@$opts = @keep;
}

# kea_other_options(&options, version)
# Returns option-data rows not represented by named fields.
sub kea_other_options
{
my ($opts, $ver) = @_;
$opts = [ ] if (ref($opts) ne 'ARRAY');

# The free-form option grid should contain only entries not already represented
# by named/common fields and not managed automatically by Kea.
my %known = map { $_ => 1 } (&kea_common_option_names($ver),
			     &kea_advanced_option_names($ver),
			     &kea_managed_option_names($ver));
my %known_codes = map { $_ => 1 } (&kea_common_option_codes($ver),
				   &kea_advanced_option_codes($ver),
				   &kea_managed_option_codes($ver));
return [ grep {
	ref($_) eq 'HASH' &&
	!(defined($_->{'name'}) && $known{$_->{'name'}}) &&
	!(defined($_->{'code'}) && $known_codes{$_->{'code'}})
	} @$opts ];
}

# kea_common_option_rows(&options, version, prefix)
# Renders common option-data form rows for a scope.
sub kea_common_option_rows
{
my ($opts, $ver, $prefix) = @_;
print &ui_table_start($text{'options_common'}, "width=100%", 4);

# The metadata list drives both labels and field names so DHCPv4/DHCPv6 can
# share the same rendering code without copying option tables.
foreach my $o (&kea_common_options($ver)) {
	my ($name, $label, $size) = @$o;
	print &ui_table_row(&kea_option_hlink($name, $label),
		&ui_textbox($prefix.$name, &kea_option_value($opts, $name, $ver),
			    $size || 40));
	}
print &ui_table_end();
}

# kea_advanced_option_rows(&options, version, prefix)
# Renders advanced option-data form rows for a scope.
sub kea_advanced_option_rows
{
my ($opts, $ver, $prefix) = @_;
return if ($ver != 4);

# The advanced option list is intentionally small and DHCPv4-only. These are
# valid option-data entries but are risky enough to stay off the common tab.
foreach my $o (&kea_advanced_options($ver)) {
	my ($name, $label, $size) = @$o;
	print &ui_table_row(&kea_option_hlink($name, $label),
		&ui_textbox($prefix.$name, &kea_option_value($opts, $name, $ver),
			    $size || 40));
	}
}

# kea_option_hlink(option-name, [label])
# Returns a standard Webmin help link for a Kea option-data field.
sub kea_option_hlink
{
my ($name, $label) = @_;
return &hlink($label || $name, &kea_help_id("opt", $name));
}

# kea_field_hlink(field-name, [label])
# Returns a standard Webmin help link for a structured Kea object field.
sub kea_field_hlink
{
my ($name, $label) = @_;
return &hlink($label || $text{'field_'.$name} || $name,
	      &kea_help_id("field", $name));
}

# kea_help_id(prefix, name)
# Maps Kea's dash-heavy option and field names to help file basenames.
sub kea_help_id
{
my ($prefix, $name) = @_;
$name =~ s/[^A-Za-z0-9]+/_/g;
$name =~ s/^_+//;
$name =~ s/_+$//;
return $prefix."_".$name;
}

# kea_option_data_rows(&options, prefix, version)
# Renders the generic option-data editor grid.
sub kea_option_data_rows
{
my ($opts, $prefix, $ver) = @_;
$opts = &kea_other_options($opts, $ver) if ($ver);
$opts = [ ] if (ref($opts) ne 'ARRAY');

# option-data rows can contain long strings, so keep them inside the same
# wrapper used by other wide row-based editors in this module.
print &ui_tag_start('div', { 'class' => 'option-data-table' });
print &ui_columns_start([
	&kea_field_hlink('option-name', $text{'opt_name'}),
	&kea_field_hlink('option-code', $text{'opt_code'}),
	&kea_field_hlink('option-space', $text{'opt_space'}),
	&kea_field_hlink('option-data', $text{'opt_data'}) ], 100);
my $rows = @$opts + 3;
for(my $i=0; $i<$rows; $i++) {
	my $o = $opts->[$i] || { };
	print &ui_columns_row([
		&ui_textbox($prefix."name_$i", $o->{'name'} || "", 24),
		&ui_textbox($prefix."code_$i", $o->{'code'} || "", 6),
		&ui_textbox($prefix."space_$i", $o->{'space'} || "", 12),
		&ui_textbox($prefix."data_$i", $o->{'data'} || "", 45),
		]);
	}
print &ui_columns_end();
print &ui_tag_end('div');
}

# kea_option_data_section(&options, prefix, version)
# Renders the generic option-data section when it has content or is required.
sub kea_option_data_section
{
my ($opts, $prefix, $ver, $always) = @_;
my $other = &kea_other_options($opts, $ver);
return if (!@$other && !$always);
print &ui_subheading($text{'options_custom'});
print &ui_div($text{'options_custom_desc'});
&kea_option_data_rows($other, $prefix);
}

# kea_ddns_domains(&root, section-name)
# Returns D2 forward or reverse domain rows without forcing missing sections.
sub kea_ddns_domains
{
my ($root, $section) = @_;
my $conf = ref($root->{$section}) eq 'HASH' ? $root->{$section} : { };
return ref($conf->{'ddns-domains'}) eq 'ARRAY' ?
	$conf->{'ddns-domains'} : [ ];
}

# kea_ddns_listener_endpoint(&root)
# Returns the visible D2 listener endpoint as separate host and port strings.
sub kea_ddns_listener_endpoint
{
my ($root) = @_;
my $host = $root->{'ip-address'} || "";
my $port = defined($root->{'port'}) ? $root->{'port'} : "";
return ($host, $port);
}

# kea_ddns_listener_target(&root)
# Returns the D2 listener as host:port text for display and comparison.
sub kea_ddns_listener_target
{
my ($root) = @_;
my ($host, $port) = &kea_ddns_listener_endpoint($root);
return "" if ($host eq '' && $port eq '');
return $host.($port ne '' ? ":".$port : "");
}

# kea_ddns_listener_host(&root)
# Returns the normalized D2 listener host without IPv6 brackets.
sub kea_ddns_listener_host
{
my ($root) = @_;
my ($host) = &kea_ddns_listener_endpoint($root);
$host = lc(&kea_trim_form_value($host));
$host =~ s/^\[(.*)\]$/$1/;
return $host;
}

# kea_ddns_listener_loopback(&root)
# Returns true for addresses that still accept only local D2 requests.
sub kea_ddns_listener_loopback
{
my ($root) = @_;
my $host = &kea_ddns_listener_host($root);
return 0 if ($host eq '');
return 1 if ($host eq 'localhost' || $host eq '::1');
return $host =~ /^127(?:\.\d{1,3}){3}$/ ? 1 : 0;
}

# kea_ddns_listener_non_default_loopback(&root)
# 127.0.0.2 and similar are local, but DHCP sender targets must match exactly.
sub kea_ddns_listener_non_default_loopback
{
my ($root) = @_;
return 0 if (!&kea_ddns_listener_loopback($root));
my $host = &kea_ddns_listener_host($root);
return $host ne '127.0.0.1' && $host ne '::1' && $host ne 'localhost';
}

# kea_ddns_listener_non_loopback(&root)
# D2 should normally only receive name-change requests from local Kea daemons.
sub kea_ddns_listener_non_loopback
{
my ($root) = @_;
my $host = &kea_ddns_listener_host($root);
return 0 if ($host eq '');
return &kea_ddns_listener_loopback($root) ? 0 : 1;
}

# kea_ddns_domain_server_fields(&domain)
# Flattens D2 server addresses and only shows a port when it is safe to edit as
# one shared value. Mixed per-server ports are preserved by leaving it blank.
sub kea_ddns_domain_server_fields
{
my ($domain) = @_;
my $servers = ref($domain->{'dns-servers'}) eq 'ARRAY' ?
	$domain->{'dns-servers'} : [ ];
my @addrs;
my ($port, $mixed_port, $server_without_port);
foreach my $s (@$servers) {
	next if (ref($s) ne 'HASH');
	push(@addrs, $s->{'ip-address'}) if ($s->{'ip-address'});
	if (defined($s->{'port'})) {
		if (!defined($port)) {
			$port = $s->{'port'};
			$mixed_port = 1 if ($server_without_port);
			}
		elsif ($port ne $s->{'port'}) {
			$mixed_port = 1;
			}
		}
	else {
		$server_without_port = 1;
		$mixed_port = 1;
		}
		}
return (join(" ", @addrs), !$mixed_port && defined($port) ? $port : "",
	$mixed_port ? 1 : 0);
}

# kea_ddns_domain_rows(&domains, prefix)
# Renders the D2 forward/reverse DNS update domain table.
sub kea_ddns_domain_rows
{
my ($domains, $prefix) = @_;
$domains = [ ] if (ref($domains) ne 'ARRAY');
print &ui_tag_start('div', { 'class' => 'option-data-table' });
print &ui_columns_start([
	&kea_field_hlink('ddns-domain-name', $text{'ddns_domain_name'}),
	&kea_field_hlink('ddns-domain-key', $text{'ddns_domain_key'}),
	&kea_field_hlink('ddns-domain-servers', $text{'ddns_domain_servers'}),
	&kea_field_hlink('ddns-domain-port', $text{'ddns_domain_port'}) ], 100);

# D2 domains are array entries. Keep a few empty rows so new domains can be
# added without a separate "add row" round trip.
my $rows = @$domains + 3;
for(my $i=0; $i<$rows; $i++) {
	my $d = ref($domains->[$i]) eq 'HASH' ? $domains->[$i] : { };
	my ($servers, $port, $mixed_port) = &kea_ddns_domain_server_fields($d);
	my $port_field = &ui_textbox($prefix."port_$i", $port, 7);
	if ($mixed_port) {
		$port_field .= " ".&ui_tag('small',
			$text{'ddns_mixed_ports'}, {
				'style' => 'color:var(--text-color-light, #777)' });
		}
	print &ui_columns_row([
		&ui_textbox($prefix."name_$i", $d->{'name'} || "", 28),
		&ui_textbox($prefix."key_$i", $d->{'key-name'} || "", 20),
		&ui_textbox($prefix."servers_$i", $servers, 42),
		$port_field,
		]);
	}
print &ui_columns_end();
print &ui_tag_end('div');
}

# kea_select_options(current-value, default-label, value...)
# Builds a conservative select list without losing uncommon existing values.
sub kea_select_options
{
my ($current, $default_label, @values) = @_;
my @opts = ([ "", $default_label ]);
my %known = ( '' => 1 );
foreach my $v (@values) {
	push(@opts, [ $v, $v ]);
	$known{$v} = 1;
	}
if (defined($current) && $current ne '' && !$known{$current}) {
	push(@opts, [ $current, $current ]);
	}
return \@opts;
}

# kea_tsig_algorithm_options(current-value)
# Builds the TSIG algorithm select list while preserving unusual existing values.
sub kea_tsig_algorithm_options
{
my ($current) = @_;
return &kea_select_options($current, $text{'socket_default'},
	'hmac-sha256', 'hmac-sha384', 'hmac-sha512',
	'hmac-sha224', 'hmac-sha1', 'hmac-md5');
}

# kea_tsig_key_names(&keys)
# Returns configured TSIG key names for DDNS domain validation.
sub kea_tsig_key_names
{
my ($keys) = @_;
my %names;
foreach my $key (@{ref($keys) eq 'ARRAY' ? $keys : [ ]}) {
	next if (ref($key) ne 'HASH' || !$key->{'name'});
	$names{$key->{'name'}} = 1;
	}
return \%names;
}

# kea_parse_ddns_domain_rows(&existing-domains, prefix, [&tsig-keys])
# Parses D2 domain rows while preserving unexposed keys by row index.
sub kea_parse_ddns_domain_rows
{
my ($domains, $prefix, $keys) = @_;
$domains = [ ] if (ref($domains) ne 'ARRAY');
my $keynames = ref($keys) eq 'ARRAY' ? &kea_tsig_key_names($keys) : undef;
my @parsed;

# Rebuild only submitted rows while retaining unexposed per-domain properties
# from the row's existing object.
for(my $i=0; defined($in{$prefix."name_$i"}) ||
		  defined($in{$prefix."key_$i"}) ||
		  defined($in{$prefix."servers_$i"}) ||
		  defined($in{$prefix."port_$i"}); $i++) {
	my $name = &kea_trim_form_value($in{$prefix."name_$i"});
	my $key = &kea_trim_form_value($in{$prefix."key_$i"});
	my $servers = &kea_trim_form_value($in{$prefix."servers_$i"});
	my $port = &kea_trim_form_value($in{$prefix."port_$i"});
	next if ($name eq '' && $key eq '' && $servers eq '' && $port eq '');
	&error($text{'ddns_edomain'}) if ($name eq '');
	&error($text{'ddns_eserver'}) if ($servers eq '');
	&error($text{'ddns_eport'}) if ($port ne '' && $port !~ /^\d+$/);
	&error(&text('ddns_ekey_unknown', $key))
		if ($key ne '' && $keynames && !$keynames->{$key});

	my %domain = ref($domains->[$i]) eq 'HASH' ? %{$domains->[$i]} : ( );
	&kea_set_optional_string(\%domain, 'name', $name);
	&kea_set_optional_string(\%domain, 'key-name', $key);
	my @addrs = grep { $_ ne '' } split(/[,\s]+/, $servers);
	foreach my $addr (@addrs) {
		&error(&text('ddns_eaddr', &html_escape($addr)))
			if (!&check_ipaddress($addr) && !&check_ip6address($addr));
		}
	if (@addrs) {
		my @old = ref($domain{'dns-servers'}) eq 'ARRAY' ?
			@{$domain{'dns-servers'}} : ( );
		my @newservers;
		for(my $j=0; $j<@addrs; $j++) {
			my %server = ref($old[$j]) eq 'HASH' ? %{$old[$j]} : ( );
			$server{'ip-address'} = $addrs[$j];
			if ($port ne '') {
				$server{'port'} = int($port);
				}
			elsif (!defined($server{'port'})) {
				$server{'port'} = 53;
				}
			push(@newservers, \%server);
			}
		$domain{'dns-servers'} = \@newservers;
		}
	else {
		delete($domain{'dns-servers'});
		}
	push(@parsed, \%domain);
	}
return \@parsed;
}

# kea_tsig_key_rows(&keys, prefix)
# Renders D2 TSIG keys used by DNS update domains.
sub kea_tsig_key_rows
{
my ($keys, $prefix) = @_;
$keys = [ ] if (ref($keys) ne 'ARRAY');
print &ui_tag_start('div', { 'class' => 'option-data-table' });
print &ui_columns_start([
	&kea_field_hlink('tsig-key-name', $text{'tsig_key_name'}),
	&kea_field_hlink('tsig-key-algorithm', $text{'tsig_key_algorithm'}),
	&kea_field_hlink('tsig-key-secret', $text{'tsig_key_secret'}) ], 100);

# Existing secrets are never echoed back into the browser. Leaving the password
# field empty keeps the old secret during save.
my $rows = @$keys + 3;
for(my $i=0; $i<$rows; $i++) {
	my $key = ref($keys->[$i]) eq 'HASH' ? $keys->[$i] : { };
	print &ui_columns_row([
		&ui_textbox($prefix."name_$i", $key->{'name'} || "", 24),
		&ui_select($prefix."algorithm_$i", $key->{'algorithm'} || "",
			&kea_tsig_algorithm_options($key->{'algorithm'})),
		&ui_password($prefix."secret_$i", "", 44),
		]);
	}
print &ui_columns_end();
print &ui_tag_end('div');
}

# kea_parse_tsig_key_rows(&existing-keys, prefix)
# Parses TSIG key rows while preserving existing secrets unless replaced.
sub kea_parse_tsig_key_rows
{
my ($keys, $prefix) = @_;
$keys = [ ] if (ref($keys) ne 'ARRAY');
my @parsed;

# Empty rows are ignored. A visible name with no algorithm is rejected because
# Kea requires every TSIG key to declare an algorithm.
for(my $i=0; defined($in{$prefix."name_$i"}) ||
		  defined($in{$prefix."algorithm_$i"}) ||
		  defined($in{$prefix."secret_$i"}); $i++) {
	my $name = &kea_trim_form_value($in{$prefix."name_$i"});
	my $algorithm = &kea_trim_form_value($in{$prefix."algorithm_$i"});
	my $secret = &kea_trim_form_value($in{$prefix."secret_$i"});
	next if ($name eq '' && $algorithm eq '' && $secret eq '');
	&error($text{'ddns_ekey'}) if ($name eq '');
	&error($text{'ddns_ekey_algorithm'}) if ($algorithm eq '');
	my %key = ref($keys->[$i]) eq 'HASH' ? %{$keys->[$i]} : ( );
	&kea_set_optional_string(\%key, 'name', $name);
	&kea_set_optional_string(\%key, 'algorithm', $algorithm);
	$key{'secret'} = $secret if ($secret ne '');
	push(@parsed, \%key);
	}
return \@parsed;
}

# kea_logger_rows(&loggers, prefix)
# Renders the common fields from Kea's root-level loggers array.
sub kea_logger_rows
{
my ($loggers, $prefix) = @_;
$loggers = [ ] if (ref($loggers) ne 'ARRAY');
print &ui_tag_start('div', { 'class' => 'option-data-table' });
print &ui_columns_start([
	&kea_field_hlink('logger-name', $text{'logging_name'}),
	&kea_field_hlink('logger-severity', $text{'logging_severity'}),
	&kea_field_hlink('logger-debuglevel', $text{'logging_debuglevel'}),
	&kea_field_hlink('logger-output', $text{'logging_output'}),
	&kea_field_hlink('logger-pattern', $text{'logging_pattern'}) ], 100);

# Existing logger rows are shown first, with spare rows for adding more
# loggers. Multiple output-options are preserved, but the UI edits the first.
my $rows = @$loggers + 2;
for(my $i=0; $i<$rows; $i++) {
	my $logger = ref($loggers->[$i]) eq 'HASH' ? $loggers->[$i] : { };
	my $outputs = ref($logger->{'output-options'}) eq 'ARRAY' ?
		$logger->{'output-options'} : [ ];
	my $first = ref($outputs->[0]) eq 'HASH' ? $outputs->[0] : { };
	print &ui_columns_row([
		&ui_textbox($prefix."name_$i", $logger->{'name'} || "", 24),
		&kea_logger_severity_select($prefix."severity_$i",
					    $logger->{'severity'} || ""),
		&ui_textbox($prefix."debuglevel_$i",
			    defined($logger->{'debuglevel'}) ?
				$logger->{'debuglevel'} : "", 6),
		&ui_textbox($prefix."output_$i", $first->{'output'} || "", 24),
		&ui_textbox($prefix."pattern_$i",
			    &kea_logger_display_value($first->{'pattern'}), 32),
		]);
	}
print &ui_columns_end();
print &ui_tag_end('div');
}

# kea_logger_severity_select(name, value)
# Renders the logger severity selector.
sub kea_logger_severity_select
{
my ($name, $value) = @_;
return &ui_select($name, $value, [
	[ "", $text{'logging_default'} ],
	map { [ $_, $_ ] } qw(FATAL ERROR WARN INFO DEBUG)
	]);
}

# kea_logger_display_value(value)
# Shows control characters in compact text fields without losing intent.
sub kea_logger_display_value
{
my ($value) = @_;
return "" if (!defined($value));
$value =~ s/\\/\\\\/g;
$value =~ s/\n/\\n/g;
$value =~ s/\r/\\r/g;
$value =~ s/\t/\\t/g;
return $value;
}

# kea_logger_form_value(value)
# Converts the visible escape form back to the value Kea expects in JSON.
sub kea_logger_form_value
{
my ($value) = @_;
$value = &kea_trim_form_value($value);
$value =~ s/\\n/\n/g;
$value =~ s/\\r/\r/g;
$value =~ s/\\t/\t/g;
$value =~ s/\\\\/\\/g;
return $value;
}

# kea_parse_common_option_rows(&options, version, prefix)
# Parses common option-data form fields back into option-data rows.
sub kea_parse_common_option_rows
{
my ($opts, $ver, $prefix) = @_;
$opts = [ ] if (ref($opts) ne 'ARRAY');
foreach my $name (&kea_common_option_names($ver)) {
	my $value = &kea_trim_form_value($in{$prefix.$name});
	&kea_set_option_value($opts, $ver, $name, $value);
	}
}

# kea_parse_advanced_option_rows(&options, version, prefix)
# Parses advanced option-data form fields back into option-data rows.
sub kea_parse_advanced_option_rows
{
my ($opts, $ver, $prefix) = @_;
$opts = [ ] if (ref($opts) ne 'ARRAY');
foreach my $name (&kea_advanced_option_names($ver)) {
	my $value = &kea_trim_form_value($in{$prefix.$name});
	&kea_set_option_value($opts, $ver, $name, $value);
	}
}

# kea_parse_option_rows(prefix)
# Parses generic option-data rows from submitted form fields.
sub kea_parse_option_rows
{
my ($prefix) = @_;
my @opts;

# Stop at the first index where all row fields have disappeared from the form.
for(my $i=0; defined($in{$prefix."name_$i"}) ||
		  defined($in{$prefix."code_$i"}) ||
		  defined($in{$prefix."data_$i"}); $i++) {
	my $name = &kea_trim_form_value($in{$prefix."name_$i"});
	my $code = &kea_trim_form_value($in{$prefix."code_$i"});
	my $data = &kea_trim_form_value($in{$prefix."data_$i"});
	my $space = &kea_trim_form_value($in{$prefix."space_$i"});
	next if ($name eq '' && $code eq '' && $data eq '');
	&error($text{'opt_ename'}) if ($name eq '' && $code eq '');
	&error(&text('opt_ecode', $code))
		if ($code ne '' && $code !~ /^\d+$/);

	# Store the smallest valid option-data object; optional fields are added
	# only when the admin typed them.
	my %opt;
	$opt{'name'} = $name if ($name ne '');
	$opt{'code'} = int($code) if ($code =~ /^\d+$/);
	$opt{'data'} = $data if ($data ne '');
	$opt{'space'} = $space if ($space ne '');
	push(@opts, \%opt);
	}
return \@opts;
}

# kea_parse_other_option_rows(&options, version, prefix)
# Merges generic option-data rows with named option rows.
sub kea_parse_other_option_rows
{
my ($opts, $ver, $prefix) = @_;
if (defined($in{$prefix."name_0"}) ||
    defined($in{$prefix."code_0"}) ||
    defined($in{$prefix."space_0"}) ||
    defined($in{$prefix."data_0"})) {
	my $parsed = &kea_parse_option_rows($prefix);

# Start with known options currently owned by named fields, then merge the
# additional rows back in. This lets numeric known options round-trip cleanly.
	my %managed_names = map { $_ => 1 } &kea_managed_option_names($ver);
	my %managed_codes = map { $_ => 1 } &kea_managed_option_codes($ver);
	my @merged = grep { &kea_known_option($_, $ver) } @$opts;
	foreach my $o (@$parsed) {
		&error(&text('opt_emanaged', $o->{'name'}))
			if ($o->{'name'} && $managed_names{$o->{'name'}});
		&error(&text('opt_emanaged', $o->{'code'}))
			if (defined($o->{'code'}) && $managed_codes{$o->{'code'}});
		my $name = $o->{'name'} || "";
		my $code = $o->{'code'};
		$name ||= &kea_option_name($ver, $code)
			if (defined($code));
		if ($name && &indexof($name, (&kea_common_option_names($ver),
					      &kea_advanced_option_names($ver))) >= 0) {
			# A numeric row for a known option is promoted into the
			# named field's canonical storage instead of being rejected
			# as a duplicate.
			&kea_set_option_value(\@merged, $ver, $name,
				$o->{'data'}, $o);
			next;
			}
		push(@merged, $o);
		}
	return \@merged;
	}
return $opts;
}

# kea_parse_logger_rows(&loggers, prefix)
# Parses root-level Kea logger rows while preserving unexposed logger keys.
sub kea_parse_logger_rows
{
my ($loggers, $prefix) = @_;
$loggers = [ ] if (ref($loggers) ne 'ARRAY');
my @parsed;

# A completely empty row is ignored. Non-empty rows require a logger name
# because Kea uses the name to attach messages to the right logging channel.
for(my $i=0; defined($in{$prefix."name_$i"}) ||
		  defined($in{$prefix."severity_$i"}) ||
		  defined($in{$prefix."debuglevel_$i"}) ||
		  defined($in{$prefix."output_$i"}) ||
		  defined($in{$prefix."pattern_$i"}); $i++) {
	my $name = &kea_trim_form_value($in{$prefix."name_$i"});
	my $severity = &kea_trim_form_value($in{$prefix."severity_$i"});
	my $debuglevel = &kea_trim_form_value($in{$prefix."debuglevel_$i"});
	my $output = &kea_trim_form_value($in{$prefix."output_$i"});
	my $pattern = &kea_logger_form_value($in{$prefix."pattern_$i"});
	next if ($name eq '' && $severity eq '' && $debuglevel eq '' &&
		 $output eq '' && $pattern eq '');
	&error($text{'logging_ename'}) if ($name eq '');
	&error($text{'logging_edebug'})
		if ($debuglevel ne '' && $debuglevel !~ /^\d+$/);
	&error($text{'logging_eseverity'})
		if ($severity ne '' &&
		    &indexof($severity, qw(FATAL ERROR WARN INFO DEBUG)) < 0);
	&error($text{'logging_edebug_severity'})
		if ($debuglevel ne '' && $debuglevel != 0 &&
		    $severity ne 'DEBUG');

	my %logger = ref($loggers->[$i]) eq 'HASH' ? %{$loggers->[$i]} : ( );
	$logger{'name'} = $name;
	if ($severity ne '') {
		$logger{'severity'} = $severity;
		}
	else {
		delete($logger{'severity'});
		}
	if ($debuglevel ne '') {
		$logger{'debuglevel'} = int($debuglevel);
		}
	else {
		delete($logger{'debuglevel'});
		}

	# Only the first output-options entry is edited by the UI. Additional
	# entries, if present, are kept after it.
	my @outputs = ref($logger{'output-options'}) eq 'ARRAY' ?
		@{$logger{'output-options'}} : ( );
	my %first = ref($outputs[0]) eq 'HASH' ? %{$outputs[0]} : ( );
	if ($output ne '') {
		$first{'output'} = $output;
		}
	else {
		delete($first{'output'});
		}
	if ($pattern ne '') {
		$first{'pattern'} = $pattern;
		}
	else {
		delete($first{'pattern'});
		}
	if (keys(%first)) {
		$outputs[0] = \%first;
		$logger{'output-options'} = \@outputs;
		}
	elsif (@outputs > 1) {
		shift(@outputs);
		$logger{'output-options'} = \@outputs;
		}
	else {
		delete($logger{'output-options'});
		}
	push(@parsed, \%logger);
	}
return \@parsed;
}

# kea_parse_pool_rows(prefix)
# Parses DHCP address pool rows from submitted form fields.
sub kea_parse_pool_rows
{
my ($prefix) = @_;
my @pools;

# Pool syntax varies between address families and can include ranges or CIDR.
# Kea's native config test validates the final string.
for(my $i=0; defined($in{$prefix."pool_$i"}); $i++) {
	my $pool = &kea_trim_form_value($in{$prefix."pool_$i"});
	next if ($pool eq '');
	push(@pools, { 'pool' => $pool });
	}
return \@pools;
}

# kea_parse_pd_pool_rows(prefix)
# Parses DHCPv6 prefix-delegation pool rows.
sub kea_parse_pd_pool_rows
{
my ($prefix) = @_;
my @pools;

# Prefix delegation is DHCPv6-only, but keeping the parser here lets the subnet
# save handler stay protocol-neutral.
for(my $i=0; defined($in{$prefix."prefix_$i"}) ||
		  defined($in{$prefix."prefix_len_$i"}) ||
		  defined($in{$prefix."delegated_len_$i"}); $i++) {
	my $pool_prefix = &kea_trim_form_value($in{$prefix."prefix_$i"});
	my $plen = &kea_trim_form_value($in{$prefix."prefix_len_$i"});
	my $dlen = &kea_trim_form_value($in{$prefix."delegated_len_$i"});
	my $excluded = &kea_trim_form_value($in{$prefix."excluded_prefix_$i"});
	my $elen = &kea_trim_form_value($in{$prefix."excluded_prefix_len_$i"});
	next if ($pool_prefix eq '' && $plen eq '' && $dlen eq '');
	my %pool;
	$pool{'prefix'} = $pool_prefix if ($pool_prefix ne '');
	$pool{'prefix-len'} = int($plen) if ($plen =~ /^\d+$/);
	$pool{'delegated-len'} = int($dlen) if ($dlen =~ /^\d+$/);
	$pool{'excluded-prefix'} = $excluded if ($excluded ne '');
	$pool{'excluded-prefix-len'} = int($elen) if ($elen =~ /^\d+$/);
	push(@pools, \%pool);
	}
return \@pools;
}

# kea_parse_reservation_rows(prefix, version)
# Parses host reservation rows for DHCPv4 or DHCPv6.
sub kea_parse_reservation_rows
{
my ($prefix, $ver) = @_;
my @reservations;

# Reservations differ by protocol: DHCPv6 can assign multiple addresses and
# delegated prefixes, while DHCPv4 stores a single ip-address value.
for(my $i=0; defined($in{$prefix."type_$i"}) ||
		  defined($in{$prefix."identifier_$i"}) ||
		  defined($in{$prefix."address_$i"}); $i++) {
	my $type = &kea_trim_form_value($in{$prefix."type_$i"}) ||
		   ($ver == 6 ? 'duid' : 'hw-address');
	my $identifier = &kea_trim_form_value($in{$prefix."identifier_$i"});
	my $address = &kea_trim_form_value($in{$prefix."address_$i"});
	my $hostname = &kea_trim_form_value($in{$prefix."hostname_$i"});
	my $prefixes = &kea_trim_form_value($in{$prefix."prefixes_$i"});
	next if ($identifier eq '' && $address eq '' && $hostname eq '');
	my %r;
	$r{$type} = $identifier if ($identifier ne '');
	if ($ver == 6) {
		my @addresses = grep { $_ ne '' } split(/\s*,\s*|\s+/, $address || "");
		$r{'ip-addresses'} = \@addresses if (@addresses);
		my @prefixes = grep { $_ ne '' } split(/\s*,\s*|\s+/, $prefixes || "");
		$r{'prefixes'} = \@prefixes if (@prefixes);
		}
	else {
		$r{'ip-address'} = $address if ($address ne '');
		}
	$r{'hostname'} = $hostname if ($hostname ne '');
	push(@reservations, \%r);
	}
return \@reservations;
}

# kea_component_interfaces(&config)
# Returns configured listen interfaces for a DHCP component.
sub kea_component_interfaces
{
my ($root) = @_;
my $ifaces = ref($root->{'interfaces-config'}) eq 'HASH' ?
	$root->{'interfaces-config'}->{'interfaces'} : undef;
return $text{'iface_none'} if (ref($ifaces) ne 'ARRAY' || !@$ifaces);
return join(", ", @$ifaces);
}

# kea_dhcp_subnet_count(&root, version)
# Counts subnets across daemon-level and shared-network scopes.
sub kea_dhcp_subnet_count
{
my ($root, $ver) = @_;
my $subkey = &kea_subnet_key($ver);
my @shareds = ref($root->{'shared-networks'}) eq 'ARRAY' ?
		@{$root->{'shared-networks'}} : ( );
my @subnets = ref($root->{$subkey}) eq 'ARRAY' ? @{$root->{$subkey}} : ( );
foreach my $s (@shareds) {
	push(@subnets, @{$s->{$subkey}}) if (ref($s->{$subkey}) eq 'ARRAY');
	}
return scalar(@subnets);
}

# kea_dhcp_has_listening_interfaces(&root)
# Returns true when interfaces-config contains at least one interface.
sub kea_dhcp_has_listening_interfaces
{
my ($root) = @_;
my $ifaces = ref($root->{'interfaces-config'}) eq 'HASH' ?
	$root->{'interfaces-config'}->{'interfaces'} : undef;
return ref($ifaces) eq 'ARRAY' && @$ifaces ? 1 : 0;
}

# kea_dhcp_needs_interface_warning(&root, version)
# Returns true when subnets exist but no listening interfaces are configured.
sub kea_dhcp_needs_interface_warning
{
my ($root, $ver) = @_;
return &kea_dhcp_subnet_count($root, $ver) &&
       !&kea_dhcp_has_listening_interfaces($root) ? 1 : 0;
}

# kea_component_summary(&component, &root)
# Returns the services-table summary for a component config.
sub kea_component_summary
{
my ($c, $root) = @_;
if ($c->{'id'} eq 'dhcp4') {
	return &kea_dhcp_summary($root, 4);
	}
elsif ($c->{'id'} eq 'dhcp6') {
	return &kea_dhcp_summary($root, 6);
	}
elsif ($c->{'id'} eq 'ddns') {

	# DDNS configs are deep; the summary only reports whether
	# forward/reverse domain lists are present.
	my $forward = ref($root->{'forward-ddns'}) eq 'HASH' ?
		$root->{'forward-ddns'}->{'ddns-domains'} : undef;
	my $reverse = ref($root->{'reverse-ddns'}) eq 'HASH' ?
		$root->{'reverse-ddns'}->{'ddns-domains'} : undef;
	return &text('summary_ddns',
		&kea_yesno($forward), &kea_yesno($reverse));
	}
elsif ($c->{'id'} eq 'ctrl') {
	return &text('summary_ctrl',
		$root->{'http-host'} || "127.0.0.1",
		$root->{'http-port'} || "8000");
	}
return $text{'summary_empty'};
}

# kea_dhcp_summary(&root, 4|6)
# Summarizes DHCP subnets, pools, and reservations for one protocol.
sub kea_dhcp_summary
{
my ($root, $ver) = @_;
my $subkey = $ver == 6 ? 'subnet6' : 'subnet4';

# Count subnets both at the daemon level and inside shared networks because Kea
# allows either storage location.
my @shareds = ref($root->{'shared-networks'}) eq 'ARRAY' ?
		@{$root->{'shared-networks'}} : ( );
my @subnets = ref($root->{$subkey}) eq 'ARRAY' ? @{$root->{$subkey}} : ( );
foreach my $s (@shareds) {
	push(@subnets, @{$s->{$subkey}}) if (ref($s->{$subkey}) eq 'ARRAY');
	}
my ($pools, $pdpools, $reservations) = (0, 0, 0);
foreach my $s (@subnets) {
	$pools += @{$s->{'pools'}} if (ref($s->{'pools'}) eq 'ARRAY');
	$pdpools += @{$s->{'pd-pools'}} if (ref($s->{'pd-pools'}) eq 'ARRAY');
	$reservations += @{$s->{'reservations'}}
		if (ref($s->{'reservations'}) eq 'ARRAY');
	}
return $ver == 6 ? &text('summary_dhcp6', scalar(@subnets),
			 scalar(@shareds), $pools, $pdpools, $reservations)
		 : &text('summary_dhcp4', scalar(@subnets),
			 scalar(@shareds), $pools, $reservations);
}

# kea_yesno(value)
# Returns the localized yes/no label for a boolean value.
sub kea_yesno
{
my ($v) = @_;
return $v ? $text{'yes'} : $text{'no'};
}

# kea_action_command(action)
# Builds the command used by global start, stop, and restart actions.
sub kea_action_command
{
my ($action) = @_;
my $cmd = &kea_config_value($action.'_cmd');

# Ignore packaged keactrl commands on systems where the Kea packages no longer
# ship keactrl, and fall back to systemd units below.
if ($cmd && $cmd =~ /\bkeactrl\b/ &&
    !&has_command(&kea_config_value('keactrl_path')) &&
    !&has_command('keactrl')) {
	$cmd = undef;
	}
if ($cmd && $cmd =~ /^systemctl\b/ && !&has_command('systemctl')) {
	$cmd = undef;
	}
if (!$cmd) {
	my $systemctl = &has_command('systemctl');
	if ($systemctl) {
		my $verb = $action eq 'restart' ? 'restart' : $action;
		my @units = grep { $_ } map { &kea_component_systemd_unit($_) }
			    &kea_components();

		# Act on all Kea units together because the header action buttons
		# are global.
		$cmd = &quote_path($systemctl)." ".$verb." ".
		       join(" ", @units);
		}
	}
if (!$cmd) {
	my $keactrl = &has_command(&kea_config_value('keactrl_path')) ||
		      &has_command('keactrl');
	if ($keactrl) {
		my $kcmd = $action eq 'restart' ? 'reload' : $action;
		$cmd = &quote_path($keactrl)." ".$kcmd;
		}
	}
return $cmd;
}

# kea_run_action(action)
# Executes a global Kea service action and returns any failure text.
sub kea_run_action
{
my ($action) = @_;
my $cmd = &kea_action_command($action);
return $text{'action_ecmd'} if (!$cmd);

# Return formatted command output only on failure; successful actions redirect
# back to the module index with a Webmin log entry.
my $out = &backquote_logged("$cmd 2>&1");
if ($?) {
	return &ui_tag('pre', &html_escape($out));
	}
return;
}

# get_all_config_files()
# Returns config files that Webmin should include in module backups.
sub get_all_config_files
{
my @rv;
foreach my $c (&kea_components()) {
	my $file = &kea_config_file($c);
	next if (!$file);
	push(@rv, $file);

	# Backups should include files pulled in by Kea include directives.
	push(@rv, &kea_config_includes($file, 0)) if (-r $file);
	}

# The Control Agent can keep API credentials in a separate password file.
# Include it with the config backup so a restore can bring the service back.
push(@rv, &kea_control_agent_password_files());
return &unique(@rv);
}

# kea_config_includes(file, depth)
# Finds Kea include files so backups cover all referenced config fragments.
sub kea_config_includes
{
my ($file, $depth) = @_;
return ( ) if ($depth > 10);
my $text = &read_file_contents($file);
return ( ) if (!defined($text));
my $dir = &kea_dirname($file);
my @rv;

# Keep include discovery parallel to parse-time expansion so backup coverage
# matches the files Kea would read.
while($text =~ /<\?include\s+"([^"]+)"\s*\?>/g) {
	my $inc = $1 =~ /^\// ? $1 :
		  -r "$dir/$1" ? "$dir/$1" : $1;
	push(@rv, $inc);
	push(@rv, &kea_config_includes($inc, $depth + 1)) if (-r $inc);
	}
return @rv;
}

1;
