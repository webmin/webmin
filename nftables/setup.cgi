#!/usr/bin/perl
# setup.cgi
# Create a Webmin-managed nftables profile table

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'setup_err'});
if ($in{'action'} eq 'create') {
	my $profile = $in{'profile'} || 'virtualmin';
	my $table_name = $in{'table_name'} || default_profile_table_name();
	$table_name =~ /^\w[\w-]*$/ || error($text{'create_ename'});

	my @tables = get_nftables_save();
	foreach my $t (@tables) {
		if ($t->{'family'} eq 'inet' && $t->{'name'} eq $table_name) {
			error(text('setup_edup', nft_table_spec($t)));
			}
		}
	my ($active, $active_err) = get_active_nftables_save();
	if (!$active_err) {
		foreach my $t (@$active) {
			if ($t->{'family'} eq 'inet' && $t->{'name'} eq $table_name &&
			    table_is_externally_managed($t)) {
				error(text('create_eexternal', nft_table_spec($t)));
				}
			}
		}

	my @allow = grep { $_ ne '' } split(/\0/, $in{'allow'} || '');
	my $table = create_profile_ruleset($profile, $table_name, \@allow);
	push(@tables, $table);

	my $error = save_configuration(@tables);
	if ($error) {
		error(text('setup_failed', $error));
		}
	$error = apply_restore();
	if ($error) {
		error(text('setup_failed', $error));
		}
	webmin_log("setup", "create", $profile,
		   { 'family' => 'inet', 'table' => $table_name });
	redirect("index.cgi?table_family=inet&table_name=".urlize($table_name));
	return;
	}

ui_print_header(undef, $text{'setup_title'}, "", "intro", 1, 1);

print ui_form_start("setup.cgi");
print ui_hidden("action", "create");

my @profiles = setup_profiles();
my $profile = $in{'profile'} || 'virtualmin';
my %profile_map = map { $_->{'id'} => $_ } @profiles;
$profile = 'virtualmin' if (!$profile_map{$profile});
my %checked = map { $_ => 1 } @{$profile_map{$profile}->{'services'} || [ ]};
my @profile_opts = map { [ $_->{'id'}, $_->{'name'} ] } @profiles;

print ui_table_start($text{'setup_header'}, "width=100%", 2);
print ui_table_row($text{'setup_table_name'},
	ui_textbox("table_name", $in{'table_name'} || profile_table_name($profile), 24));
print ui_table_row($text{'setup_profile'},
	ui_select("profile", $profile, \@profile_opts, 1, 0, 0, 0).
	ui_tag('div', ui_note($profile_map{$profile}->{'desc'}, 0),
		{ 'id' => 'nftables_profile_note',
		  'style' => 'margin-top: 0.35em; margin-left: 0.15em;' }));
print ui_table_end();

my @services = setup_services();
my @links = ( select_all_link("allow", 0),
	      select_invert_link("allow", 0) );
print ui_hr();
print ui_links_row(\@links);
my @tds = ( "width=5" );
print ui_columns_start(
	[ "", $text{'setup_service_col'}, $text{'setup_type_col'},
	  $text{'setup_port_col'}, $text{'setup_proto_col'} ], 100, 0, \@tds,
	$text{'setup_services'});
foreach my $svc (sort { lc($a->{'label'}) cmp lc($b->{'label'}) } @services) {
	print ui_checked_columns_row([
		$svc->{'label'},
		$svc->{'type'},
		$svc->{'port'},
		$svc->{'proto'},
		], \@tds, "allow", $svc->{'id'}, $checked{$svc->{'id'}});
	}
print ui_columns_end();
print profile_javascript(@profiles);

print ui_form_end([ [ undef, $text{'setup_create'} ] ]);
ui_print_footer("index.cgi", $text{'index_return'});

# setup_profiles()
# Returns available ruleset profiles and their default policies/services
sub setup_profiles
{
return (
	{ 'id' => 'allow_all',
	  'name' => $text{'setup_profile_allow_all'},
	  'desc' => $text{'setup_profile_allow_all_desc'},
	  'input' => 'accept',
	  'forward' => 'accept',
	  'output' => 'accept',
	  'services' => [ ] },
	{ 'id' => 'management',
	  'name' => $text{'setup_profile_management'},
	  'desc' => $text{'setup_profile_management_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'accept',
	  'services' => [ qw(ssh webmin) ] },
	{ 'id' => 'web',
	  'name' => $text{'setup_profile_web'},
	  'desc' => $text{'setup_profile_web_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'accept',
	  'services' => [ qw(ssh webmin http https) ] },
	{ 'id' => 'mail',
	  'name' => $text{'setup_profile_mail'},
	  'desc' => $text{'setup_profile_mail_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'accept',
	  'services' => [ qw(ssh usermin smtp submission smtps pop3 pop3s imap imaps) ] },
	{ 'id' => 'dns',
	  'name' => $text{'setup_profile_dns'},
	  'desc' => $text{'setup_profile_dns_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'accept',
	  'services' => [ qw(ssh webmin dhcpv6 dns dot mdns) ] },
	{ 'id' => 'virtualmin',
	  'name' => $text{'setup_profile_virtualmin'},
	  'desc' => $text{'setup_profile_virtualmin_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'accept',
	  'services' => [ qw(ssh webmin dhcpv6 dns dot ftp http https imap imaps
			     mdns pop3 pop3s smtp submission smtps ftp_data
			     ssh_alt webmin_range usermin passive_ftp) ] },
	{ 'id' => 'locked',
	  'name' => $text{'setup_profile_locked'},
	  'desc' => $text{'setup_profile_locked_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'drop',
	  'services' => [ ] },
	{ 'id' => 'custom',
	  'name' => $text{'setup_profile_custom'},
	  'desc' => $text{'setup_profile_custom_desc'},
	  'input' => 'drop',
	  'forward' => 'drop',
	  'output' => 'accept',
	  'services' => [ ] },
	);
}

# setup_services()
# Returns selectable services and ports used by ruleset profiles
sub setup_services
{
my $webmin_port = get_webmin_port();
my $usermin_port = get_usermin_port();
return (
	{ 'id' => 'ssh', 'label' => $text{'setup_svc_ssh'},
	  'type' => $text{'setup_type_service'}, 'port' => '22',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 22 accept' ] },
	{ 'id' => 'webmin', 'label' => text('setup_svc_webmin', $webmin_port),
	  'type' => $text{'setup_type_service'}, 'port' => $webmin_port,
	  'proto' => 'TCP', 'rules' => [ "tcp dport $webmin_port accept" ] },
	{ 'id' => 'dhcpv6', 'label' => $text{'setup_svc_dhcpv6'},
	  'type' => $text{'setup_type_service'}, 'port' => '546',
	  'proto' => 'UDP',
	  'rules' => [ 'ip6 daddr fe80::/64 udp dport 546 accept' ] },
	{ 'id' => 'dns', 'label' => $text{'setup_svc_dns'},
	  'type' => $text{'setup_type_service'}, 'port' => '53',
	  'proto' => 'TCP/UDP',
	  'rules' => [ 'tcp dport 53 accept', 'udp dport 53 accept' ] },
	{ 'id' => 'dot', 'label' => $text{'setup_svc_dot'},
	  'type' => $text{'setup_type_service'}, 'port' => '853',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 853 accept' ] },
	{ 'id' => 'ftp', 'label' => $text{'setup_svc_ftp'},
	  'type' => $text{'setup_type_service'}, 'port' => '21',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 21 accept' ] },
	{ 'id' => 'http', 'label' => $text{'setup_svc_http'},
	  'type' => $text{'setup_type_service'}, 'port' => '80',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 80 accept' ] },
	{ 'id' => 'https', 'label' => $text{'setup_svc_https'},
	  'type' => $text{'setup_type_service'}, 'port' => '443',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 443 accept' ] },
	{ 'id' => 'imap', 'label' => $text{'setup_svc_imap'},
	  'type' => $text{'setup_type_service'}, 'port' => '143',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 143 accept' ] },
	{ 'id' => 'imaps', 'label' => $text{'setup_svc_imaps'},
	  'type' => $text{'setup_type_service'}, 'port' => '993',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 993 accept' ] },
	{ 'id' => 'mdns', 'label' => $text{'setup_svc_mdns'},
	  'type' => $text{'setup_type_service'}, 'port' => '5353',
	  'proto' => 'UDP',
	  'rules' => [ 'ip daddr 224.0.0.251 udp dport 5353 accept',
		       'ip6 daddr ff02::fb udp dport 5353 accept' ] },
	{ 'id' => 'pop3', 'label' => $text{'setup_svc_pop3'},
	  'type' => $text{'setup_type_service'}, 'port' => '110',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 110 accept' ] },
	{ 'id' => 'pop3s', 'label' => $text{'setup_svc_pop3s'},
	  'type' => $text{'setup_type_service'}, 'port' => '995',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 995 accept' ] },
	{ 'id' => 'smtp', 'label' => $text{'setup_svc_smtp'},
	  'type' => $text{'setup_type_service'}, 'port' => '25',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 25 accept' ] },
	{ 'id' => 'submission', 'label' => $text{'setup_svc_submission'},
	  'type' => $text{'setup_type_service'}, 'port' => '587',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 587 accept' ] },
	{ 'id' => 'smtps', 'label' => $text{'setup_svc_smtps'},
	  'type' => $text{'setup_type_service'}, 'port' => '465',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 465 accept' ] },
	{ 'id' => 'ftp_data', 'label' => $text{'setup_port_ftp_data'},
	  'type' => $text{'setup_type_port'}, 'port' => '20',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 20 accept' ] },
	{ 'id' => 'ssh_alt', 'label' => $text{'setup_port_ssh_alt'},
	  'type' => $text{'setup_type_port'}, 'port' => '2222',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 2222 accept' ] },
	{ 'id' => 'webmin_range', 'label' => $text{'setup_port_webmin_range'},
	  'type' => $text{'setup_type_port'}, 'port' => '10000-10100',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 10000-10100 accept' ] },
	{ 'id' => 'usermin', 'label' => $text{'setup_port_usermin'},
	  'type' => $text{'setup_type_port'}, 'port' => $usermin_port,
	  'proto' => 'TCP', 'rules' => [ "tcp dport $usermin_port accept" ] },
	{ 'id' => 'passive_ftp', 'label' => $text{'setup_port_passive_ftp'},
	  'type' => $text{'setup_type_port'}, 'port' => '49152-65535',
	  'proto' => 'TCP', 'rules' => [ 'tcp dport 49152-65535 accept' ] },
	);
}

# create_profile_ruleset(profile-id, table-name, &allowed-service-ids)
# Builds an inet table for a selected profile and service list
sub create_profile_ruleset
{
my ($profile_id, $table_name, $allow_ids) = @_;
my %profiles = map { $_->{'id'} => $_ } setup_profiles();
my $profile = $profiles{$profile_id} || error($text{'setup_invalid_type'});
my @services = setup_services();
my %services = map { $_->{'id'} => $_ } @services;
my %allow;
foreach my $id (@$allow_ids) {
	$services{$id} || error(text('setup_eservice', $id));
	$allow{$id} = 1;
	}

my $table = {
	'name' => $table_name,
	'family' => 'inet',
	'rules' => [ ],
	'sets' => { },
	'chains' => {
		'input' => {
			'type' => 'filter',
			'hook' => 'input',
			'priority' => 0,
			'policy' => $profile->{'input'}
			},
		'forward' => {
			'type' => 'filter',
			'hook' => 'forward',
			'priority' => 0,
			'policy' => $profile->{'forward'}
			},
		'output' => {
			'type' => 'filter',
			'hook' => 'output',
			'priority' => 0,
			'policy' => $profile->{'output'}
			}
		}
	};
return $table if ($profile_id eq 'allow_all');

add_profile_rule($table, 'input', 'ct state established,related accept');
add_profile_rule($table, 'input', 'iif "lo" accept');
add_profile_rule($table, 'input', 'meta l4proto { icmp, ipv6-icmp } accept');
if ($profile->{'output'} eq 'drop') {
	add_profile_rule($table, 'output', 'ct state established,related accept');
	add_profile_rule($table, 'output', 'oif "lo" accept');
	add_profile_rule($table, 'output', 'meta l4proto { icmp, ipv6-icmp } accept');
	}

my %seen;
my %ports;
my @special_rules;
foreach my $id (map { $_->{'id'} } @services) {
	next if (!$allow{$id});
	foreach my $rule (@{$services{$id}->{'rules'}}) {
		next if ($seen{$rule}++);
		if ($rule =~ /^(tcp|udp)\s+dport\s+(\S+)\s+accept$/) {
			$ports{$1}->{$2} = 1;
			}
		else {
			push(@special_rules, $rule);
			}
		}
	}
add_profile_port_set($table, $profile_id, \%ports);
foreach my $rule (@special_rules) {
	add_profile_rule($table, 'input', $rule);
	}
return $table;
}

# add_profile_port_set(&table, profile-id, &proto-ports)
# Adds profile service port sets and their input accept rules
sub add_profile_port_set
{
my ($table, $profile_id, $ports) = @_;
# Keep TCP and UDP ports in separate sets when they differ, otherwise a UDP
# accept rule would also allow TCP-only service ports.
my @protos = grep { keys %{$ports->{$_}} } sort keys %$ports;
return if (!@protos);
foreach my $proto (@protos) {
	next if (!keys %{$ports->{$proto}});
	my $set_name = profile_port_set_name($profile_id, $proto, scalar(@protos));
	my @elements = normalize_port_set_elements(keys %{$ports->{$proto}});
	$table->{'sets'}->{$set_name} = {
		'name' => $set_name,
		'type' => 'inet_service',
		'flags' => (grep { /-/ } @elements) ? 'interval' : undef,
		'elements' => \@elements,
		'raw_lines' => [ ],
		};
	add_profile_rule($table, 'input', "$proto dport \@$set_name accept");
	}
return;
}

# profile_javascript(@profiles)
# Returns JavaScript for profile-driven table names, notes and service checks
sub profile_javascript
{
my (@profiles) = @_;
my %profile_services = map {
	$_->{'id'} => $_->{'services'}
	} @profiles;
my %profile_tables = map {
	$_->{'id'} => profile_table_name($_->{'id'})
	} @profiles;
my %profile_notes = map {
	$_->{'id'} => ui_note($_->{'desc'}, 0)
	} @profiles;
my $json = convert_to_json(\%profile_services);
my $table_json = convert_to_json(\%profile_tables);
my $note_json = convert_to_json(\%profile_notes);
return <<EOF;
<script type='text/javascript'>
(function() {
	var profileServices = $json;
	var profileTables = $table_json;
	var profileNotes = $note_json;
	var tableInput = document.querySelector('input[name="table_name"]');
	var profileSelect = document.querySelector('select[name="profile"]');
	var profileNote = document.getElementById('nftables_profile_note');
	var tableNameTouched = false;
	if (tableInput) {
		tableInput.addEventListener('input', function() {
			tableNameTouched = true;
		});
	}
	function applyProfileServices(profile) {
		var selected = {};
		(profileServices[profile] || []).forEach(function(id) {
			selected[id] = true;
		});
		document.querySelectorAll('input[name="allow"]').forEach(function(input) {
			var checked = !!selected[input.value];
			if (input.checked != checked) {
				input.click();
			}
		});
	}
	function applyProfileTable(profile) {
		if (!tableInput || tableNameTouched || !profileTables[profile]) {
			return;
		}
		tableInput.value = profileTables[profile];
	}
	function applyProfileNote(profile) {
		if (profileNote && profileNotes[profile]) {
			profileNote.innerHTML = profileNotes[profile];
		}
	}
	if (profileSelect) {
		profileSelect.addEventListener('change', function() {
			applyProfileServices(this.value);
			applyProfileTable(this.value);
			applyProfileNote(this.value);
		});
	}
})();
</script>
EOF
}

# add_profile_rule(&table, chain, rule-text)
# Appends a generated rule to a profile table
sub add_profile_rule
{
my ($table, $chain, $text) = @_;
push(@{$table->{'rules'}}, {
	'text' => $text,
	'chain' => $chain,
	'index' => scalar(@{$table->{'rules'}}),
	});
return;
}

# profile_table_name(profile-id)
# Returns an unused default table name for a profile
sub profile_table_name
{
my ($profile) = @_;
my $base = profile_base_table_name($profile);
my @tables = get_nftables_save();
my %used = map { $_->{'family'} eq 'inet' ? ($_->{'name'} => 1) : ( ) }
	   @tables;
my $name = $base;
my $i = 1;
while ($used{$name}) {
	$name = $base."_".$i++;
	}
return $name;
}

# profile_base_table_name(profile-id)
# Returns the base table name for a profile before uniquifying
sub profile_base_table_name
{
my ($profile) = @_;
my %names = (
	'allow_all' => 'profile_allow_all',
	'management' => 'profile_management',
	'web' => 'profile_web',
	'mail' => 'profile_mail',
	'dns' => 'profile_dns',
	'virtualmin' => 'profile_hosting',
	'locked' => 'profile_locked',
	'custom' => 'profile_custom',
	);
return $names{$profile} || 'profile_custom';
}

# profile_port_set_name(profile, proto, proto-count)
# Returns the set name used for profile-generated service ports
sub profile_port_set_name
{
my ($profile, $proto, $proto_count) = @_;
my $name = profile_base_table_name($profile);
$name .= "_".$proto if ($proto_count && $proto_count > 1);
$name .= "_ports";
$name =~ s/[^\w-]/_/g;
return $name;
}

# default_profile_table_name()
# Returns the default table name for the default profile
sub default_profile_table_name
{
return profile_table_name('virtualmin');
}
