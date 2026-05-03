#!/usr/bin/perl
# setup.cgi
# Create a Webmin-managed nftables profile table

require './nftables-lib.pl'; ## no critic
use strict;
use warnings;
our (%in, %text);
ReadParse();
error_setup($text{'setup_err'});
assert_acl('setup');
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
	my $table = create_profile_ruleset($table_name, $profile, \@allow);
	assert_table_acl($table);
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

ui_print_header(undef, $text{'index_profile_setup'}, "", "intro", 1, 1);

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
