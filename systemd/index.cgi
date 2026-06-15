#!/usr/local/bin/perl
# Display systemd system and user units grouped by unit type.

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %config, %in, %text);

ReadParse();

# Read query params to restore the selected tab/user context on return links.
# The index is GET-addressable, so every value from %in below is either reduced
# to known values or validated before use, and none is printed raw.
has_command("systemctl") || error($text{'systemd_esystemctl'});
systemd_can_enter_module(\%access) || systemd_acl_error('penter');

# Print the page shell before building the tab contents.
ui_print_header(version_title(),
		 $text{'index_title'}, "", "intro", 1, 1, undef,
		 action_links());
print index_style();

# Query parameters only choose the active tab and optional user context.
my $scope = $in{'scope'} eq 'user' && tab_visible('user') ? 'user' : '';
my $unituser = clean_unit_value($in{'unituser'});
$unituser ||= systemd_acl_default_user(\%access) || "";
my $unituser_details = $unituser ?
	get_user_details($unituser) : undef;
if ($scope eq 'user') {
	$unituser_details || error($text{'systemd_euser'});
	systemd_can_view_user_scope(\%access, $unituser) ||
		systemd_acl_error('pview_user');
	}
$unituser = "" if (!$unituser_details);

# Load both system and user units so the visible tab set matches reality.
my @system_units = systemd_can_view_system(\%access) ? list_units() : ( );
my @user_units = tab_visible('user') &&
		 systemd_can_view_user_scope(\%access) ?
	grep { systemd_acl_user_allowed(\%access, $_->{'user'}) }
	     list_all_user_units() : ( );
my @tabs = index_tabs(\@system_units, \@user_units, $unituser);

# Pick a valid active tab.  Invalid mode values fall back to the first tab.
my %valid_tabs = map { $_->{'id'}, 1 } @tabs;
my $requested = defined($in{'mode'}) ? $in{'mode'} : "";
my $mode = $requested && $valid_tabs{$requested} ? $requested :
	   $scope eq 'user' && $valid_tabs{'user'} ? 'user' :
	   $tabs[0]->{'id'};
my $formno = 0;

# When several unit groups exist, render Webmin tabs around each table.
if (@tabs > 1) {
	my @uitabs = map { [ $_->{'id'}, $_->{'title'} ] } @tabs;
	print ui_tabs_start(\@uitabs, "mode", $mode, 1);
	foreach my $tab (@tabs) {
		print ui_tabs_start_tab("mode", $tab->{'id'});
		$formno++ if (print_index_tab($tab, $formno));
		print ui_tabs_end_tab("mode", $tab->{'id'});
		}
	print ui_tabs_end(1);
	}
else {
	# A single unit group does not need tab chrome.
	print_index_tab($tabs[0], $formno);
	}

print_index_tools();
ui_print_footer("/", $text{'index'});

# version_title()
# Returns the first line of systemctl --version, or a plain fallback.
sub version_title
{
my $systemctl = has_command("systemctl");
return $text{'mode_systemd'} if (!$systemctl);

# Only the first line is useful as a subtitle, for example "systemd 252".
my $out = backquote_command(quotemeta($systemctl)." --version 2>/dev/null");
return $text{'mode_systemd'} if ($? || !defined($out) || $out eq "");
my ($first) = split(/\r?\n/, $out, 2);
$first = clean_unit_value($first);
return $first || $text{'mode_systemd'};
}

# index_style()
# Returns CSS used by the systemd index fragment.
sub index_style
{
# The style is emitted in the body so SPA theme navigation applies it too.
return ui_tag('style',
	".systemd_linger_toggle { text-decoration: none; }\n".
	".systemd_linger_toggle .ui_text_color { border-bottom: 1px dotted currentColor; }\n",
	{ 'type' => 'text/css' });
}

# print_index_tools()
# Prints advanced module actions below the unit tables.
sub print_index_tools
{
my @buttons;
push(@buttons, [ "edit_manual.cgi",
		 $text{'index_edit_files'},
		 $text{'index_edit_filesdesc'} ])
	if (systemd_acl_bool(\%access, 'manual') ||
	    systemd_acl_bool(\%access, 'manual_user'));
push(@buttons, [ "dropins.cgi",
		 $text{'index_dropins'},
		 $text{'index_dropinsdesc'} ])
	if ($config{'show_dropin_inventory'} &&
	    systemd_can_enter_module(\%access));
push(@buttons, [ "restart.cgi",
		 $text{'index_reload'},
		 $text{'index_reloaddesc'} ])
	if (systemd_can_reload(\%access));
return if (!@buttons);
print ui_hr();
print ui_buttons_start();
foreach my $button (@buttons) {
	print ui_buttons_row(@$button);
	}
print ui_buttons_end();
}

# index_tab_groups()
# Returns the system-unit tab layout and the unit suffixes each tab owns.
sub index_tab_groups
{
return (
	{ 'id' => 'service', 'types' => [ 'service' ],
	  'create' => 'service' },
	{ 'id' => 'timer', 'types' => [ 'timer' ],
	  'create' => 'timer' },
	{ 'id' => 'socket', 'types' => [ 'socket' ],
	  'create' => 'socket' },
	{ 'id' => 'path', 'types' => [ 'path' ],
	  'create' => 'path' },
	{ 'id' => 'target', 'types' => [ 'target' ],
	  'create' => 'target' },
	{ 'id' => 'storage', 'types' => [ 'mount', 'automount', 'swap' ],
	  'create' => 'mount', 'show_type' => 1 },
	{ 'id' => 'resources', 'types' => [ 'slice', 'scope' ],
	  'create' => 'slice', 'show_type' => 1, 'inspect_only' => 1 },
	{ 'id' => 'device', 'types' => [ 'device' ],
	  'inspect_only' => 1, 'selectable' => 0,
	  'show_unit_state' => 0 },
	);
}

# index_type_tab(type)
# Returns the tab id that owns a unit type.
sub index_type_tab
{
my ($type) = @_;
foreach my $tab (index_tab_groups()) {
	return $tab->{'id'} if (indexof($type, @{$tab->{'types'}}) >= 0);
	}
return;
}

# index_tabs(system-units, user-units, [user])
# Builds tab metadata for system unit types plus one user-units tab.
sub index_tabs
{
my ($system_units, $user_units, $unituser) = @_;
my %by_tab;

# System units are grouped by suffix, with related low-level types combined.
foreach my $u (@$system_units) {
	my ($display, $type) = index_name_type($u->{'name'});
	$type = 'service' if (!$type);
	next if (indexof($type, get_list_unit_types()) < 0);
	next if (!unit_visible_on_index($u));
	my $tabid = index_type_tab($type);
	next if (!$tabid);
	$u->{'_display'} = $config{'show_unit_suffixes'} ?
		$u->{'name'} : $display;
	$u->{'_type'} = $type;
	push(@{$by_tab{$tabid}}, $u);
	}

# Keep tab ordering stable even when some unit types are absent.
my @tabs;
foreach my $group (index_tab_groups()) {
	next if (!tab_visible($group->{'id'}));
	next if (!systemd_can_view_system(\%access));
	my $units = $by_tab{$group->{'id'}} || [ ];
	push(@tabs, { %$group,
		      'title' => index_tab_title($group->{'id'}),
		      'desc' => index_tab_desc($group->{'id'}),
		      'units' => $units });
	}

# User units share one tab because the owner column distinguishes accounts.
my @visible_user_units;
foreach my $u (@$user_units) {
	next if (!unit_visible_on_index($u));
	my ($display, $type) = index_name_type($u->{'name'});
	$u->{'_display'} = $config{'show_unit_suffixes'} ?
		$u->{'name'} : $display;
	$u->{'_type'} = $type || 'service';
	push(@visible_user_units, $u);
	}
$user_units = \@visible_user_units;
if (tab_visible('user') &&
    systemd_can_view_user_scope(\%access, $unituser)) {
	push(@tabs, { 'id' => 'user',
		      'user' => 1,
		      'unituser' => $unituser,
		      'title' => $text{'systemd_tab_user'},
		      'desc' => $text{'systemd_tabdesc_user'},
		      'units' => $user_units });
	}
return @tabs;
}

# print_index_tab(tab, form-number)
# Outputs one tab description and its mass-action table.
sub print_index_tab
{
my ($tab, $formno) = @_;
my $user_tab = $tab->{'user'} ? 1 : 0;
my $can_status = systemd_can_inspect(\%access, $user_tab, $tab->{'unituser'});
my $can_logs = systemd_can_logs(\%access, $user_tab, $tab->{'unituser'});
my $can_start = systemd_can_runtime(\%access, 'start',
				    $user_tab, $tab->{'unituser'});
my $can_stop = systemd_can_runtime(\%access, 'stop',
				   $user_tab, $tab->{'unituser'});
my $can_restart = systemd_can_runtime(\%access, 'restart',
				      $user_tab, $tab->{'unituser'});
my $can_boot = systemd_can_boot(\%access, $user_tab, $tab->{'unituser'});
my $can_mask = $user_tab ? 0 :
	       systemd_can_mask(\%access, $user_tab, $tab->{'unituser'});
my $can_delete = $user_tab ?
	systemd_can_delete(\%access, $user_tab, $tab->{'unituser'}) : 0;
my $selectable = exists($tab->{'selectable'}) ? $tab->{'selectable'} : 1;
$selectable &&= $can_status || $can_logs || $can_start || $can_stop ||
	       $can_restart || $can_boot || $can_mask || $can_delete ? 1 : 0;
my $show_unit_state = exists($tab->{'show_unit_state'}) ?
	$tab->{'show_unit_state'} : 1;
my $show_type = !$config{'show_unit_suffixes'} &&
	($user_tab || $tab->{'show_type'});
my %linger_cache;

# The create link inherits tab context so the create form opens with the right
# unit type or user-unit mode selected.
my $create_type = $user_tab ? 'service' : $tab->{'create'};
my $create_link = index_create_link($tab, $user_tab, $create_type);
my @links = $selectable ?
	( select_all_link("d", $formno),
	  select_invert_link("d", $formno) ) :
	( );
push(@links, $create_link) if ($create_link);

print ui_div($tab->{'desc'});
if (!@{$tab->{'units'}}) {
	print ui_tag('p', index_empty_message($tab));
	print ui_links_row([ $create_link ]) if ($create_link);
	return 0;
	}

# Start the mass-action form and keep scope in a hidden field for user units.
print ui_form_start("mass_units.cgi", "post");
print ui_links_row(\@links) if (@links);
print ui_hidden("scope", "users") if ($user_tab);

# Mixed-type tabs only need a type column when unit suffixes are hidden.
my @heads = $selectable ? ( "" ) : ( );
push(@heads, $text{'systemd_name'});
push(@heads, $text{'systemd_desc'}) if ($config{'desc'});
push(@heads, $text{'systemd_type'}) if ($show_type);
push(@heads, $text{'systemd_unit_state'}) if ($show_unit_state);
push(@heads, $text{'systemd_runtime_state'});
push(@heads, $text{'systemd_owner'}, $text{'systemd_linger_status'})
	if ($user_tab);
print ui_columns_start(\@heads);
foreach my $u (@{$tab->{'units'}}) {
	# Generated units without real files and masked units are shown read-only.
	my $editable = $u->{'file'} && -f $u->{'file'} ? 1 : 0;
	my $link = index_edit_url($u, $user_tab);
	my $title = (!$editable ||
		     (defined($u->{'boot'}) && $u->{'boot'} == -1) ?
		     html_escape($u->{'_display'}) :
		     ui_link($link, html_escape($u->{'_display'})));
	my $checkvalue = $user_tab ?
		user_unit_selection_value($u->{'user'}, $u->{'name'}) :
		$u->{'name'};

	# Build the row from common columns first, then append user-only columns.
	my @row = $selectable ?
		( ui_checkbox("d", $checkvalue, undef) ) :
		( );
	push(@row, $title);
	push(@row, html_escape($u->{'desc'})) if ($config{'desc'});
	push(@row, html_escape(index_unit_type_title($u->{'_type'})))
		if ($show_type);
	push(@row, index_unit_state_column($u->{'unitstate'}))
		if ($show_unit_state);
	push(@row, index_runtime_state_column(
		$u->{'runtime'}, $u->{'substate'}));
	if ($user_tab) {
		# Linger is per user, so cache it instead of calling loginctl per row.
		if (!exists($linger_cache{$u->{'user'}})) {
			$linger_cache{$u->{'user'}} =
				user_linger_enabled($u->{'user'});
			}
		my $linger_html = systemd_can_linger(\%access, $u->{'user'}) ?
			linger_toggle_link(
				$u->{'user'}, $linger_cache{$u->{'user'}}) :
			html_escape($linger_cache{$u->{'user'}} ?
				    $text{'yes'} : $text{'no'});
		push(@row, ui_tag('tt', html_escape($u->{'user'})),
		     $linger_html);
		}
	print ui_columns_row(\@row);
	}

# Repeat row-selection links below the table for long lists.
print ui_columns_end();
if ($selectable) {
	print ui_links_row(\@links);
	my @runtime_buttons;
	push(@runtime_buttons, [ "start", $text{'index_start'} ])
		if ($can_start);
	push(@runtime_buttons, [ "stop", $text{'index_stop'} ])
		if ($can_stop);
	push(@runtime_buttons, [ "restart", $text{'index_restart'} ])
		if ($can_restart);
	my @boot_buttons = $can_boot ?
		( [ "addboot", $text{'index_addboot'} ],
		  [ "delboot", $text{'index_delboot'} ] ) : ( );
	my @mask_buttons = $can_mask ?
		( [ "mask", $text{'index_mask'} ],
		  [ "unmask", $text{'index_unmask'} ] ) : ( );
	my @inspect_buttons;
	push(@inspect_buttons, [ "status", $text{'index_statusnow'} ])
		if ($can_status);
	push(@inspect_buttons, [ "logs", $text{'index_logsnow'} ])
		if ($can_logs);
	my @delete_buttons = $can_delete ?
		( [ "delete", $text{'index_delete'} ] ) : ( );
	my @action_groups = $tab->{'inspect_only'} ?
		grep { @$_ } ( \@inspect_buttons ) :
		grep { @$_ } ( \@runtime_buttons, \@boot_buttons,
				\@mask_buttons, \@inspect_buttons );
	print ui_form_grouped_buttons([ [ @action_groups ],
					[ \@delete_buttons ] ])
		if (@action_groups || @delete_buttons);
	}
print ui_form_end();
return 1;
}

# index_name_type(unit-name)
# Splits a full unit name into display name and unit type.
sub index_name_type
{
my ($name) = @_;
my $units_piped = join('|', map { quotemeta } get_unit_types());

# Only strip suffixes that systemd understands as unit types.
my ($type) = $name =~ /\.([^.]+)$/;
if (defined($type) && $type =~ /^(?:$units_piped)$/) {
	my $display = $name;
	$display =~ s/\.$type$//;
	return ($display, $type);
	}
return ($name, "");
}

# index_tab_title(type)
# Returns the plural tab title for a systemd unit type.
sub index_tab_title
{
my ($type) = @_;
return $text{'systemd_tab_'.$type} ||
       $text{'systemd_type_'.$type} ||
       ucfirst($type);
}

# index_tab_desc(type)
# Returns the explanatory text shown under a systemd unit tab.
sub index_tab_desc
{
my ($type) = @_;
return $text{'systemd_tabdesc_'.$type} || "";
}

# index_create_label(tab-id, create-type)
# Returns the tab-specific label for the create-unit link.
sub index_create_label
{
my ($tabid, $type) = @_;
return $text{'index_sadd_'.$tabid} ||
       $text{'index_sadd_'.$type} ||
       $text{'index_sadd'};
}

# index_create_link(tab, user-tab, create-type)
# Returns the create link for a tab, if allowed.
sub index_create_link
{
my ($tab, $user_tab, $create_type) = @_;
return "" if (!$create_type);
return "" if (!systemd_can_create(\%access, $user_tab, $tab->{'unituser'}));
my $create_url = $user_tab && $tab->{'unituser'} ?
	"edit_unit.cgi?new=1&scope=user&unittype=service&unituser=".
	urlize($tab->{'unituser'}) :
	$user_tab ? "edit_unit.cgi?new=1&scope=user&unittype=service" :
	"edit_unit.cgi?new=1&unittype=".urlize($create_type);
return ui_link($create_url,
	       index_create_label($tab->{'id'}, $create_type));
}

# index_empty_message(tab)
# Returns the empty-state message for a unit tab.
sub index_empty_message
{
my ($tab) = @_;
if ($tab->{'user'}) {
	return text('index_empty_user_owner',
		    ui_tag('tt', html_escape($tab->{'unituser'})))
		if ($tab->{'unituser'});
	return $text{'index_empty_user'};
	}
return $text{'index_empty_'.$tab->{'id'}} || $text{'index_empty_units'};
}

# index_unit_type_title(type)
# Returns the display label for a single unit type.
sub index_unit_type_title
{
my ($type) = @_;
return $text{'systemd_type_'.$type} || $type;
}

# user_unit_selection_value(user, unit)
# Encodes a user-unit owner and name into one checkbox value for mass actions.
sub user_unit_selection_value
{
my ($user, $unit) = @_;
return urlize($user)."\t".urlize($unit);
}

# linger_toggle_link(user, enabled)
# Returns a link to toggle linger for a user-unit owner.
sub linger_toggle_link
{
my ($user, $enabled) = @_;

# The link flips the current state and lets set_linger.cgi validate again.
my $target = $enabled ? 0 : 1;
my $label = $enabled ? $text{'yes'} : $text{'no'};
my $type = $enabled ? 'success' : 'warn';
my $title = $enabled ? text('systemd_linger_disable', $user) :
		       text('systemd_linger_enable', $user);
my $url = "set_linger.cgi?user=".urlize($user)."&enabled=".$target;
return ui_tag('a', ui_text_color(html_escape($label), $type),
	       { 'href' => $url,
		 'class' => 'systemd_linger_toggle',
		 'title' => $title });
}

# index_unit_state_column(state)
# Returns a formatted UnitFileState value for a unit row.
sub index_unit_state_column
{
my ($state) = @_;
return index_state_column($state, {
	'enabled' => 'success',
	'enabled-runtime' => 'success',
	'disabled' => 'warn',
	'masked' => 'danger',
	'masked-runtime' => 'danger',
	'bad' => 'danger',
	});
}

# index_runtime_state_column(state, substate)
# Returns a formatted ActiveState value, with SubState when systemd reports it.
sub index_runtime_state_column
{
my ($state, $substate) = @_;
return index_state_column($state, {
	'active' => 'success',
	'inactive' => 'warn',
	'activating' => 'warn',
	'deactivating' => 'warn',
	'failed' => 'danger',
	}, $substate);
}

# index_state_column(state, colors, [substate])
# Returns a displayed systemd state value with light semantic coloring.
sub index_state_column
{
my ($state, $colors, $substate) = @_;
return ui_tag('i', $text{'index_unknown'})
	if (!defined($state) || $state eq "");
my $label = ucfirst($state);
$label .= " (".$substate.")"
	if (defined($substate) && $substate ne "" && $substate ne $state);
my $safe = html_escape($label);
my $color = $colors->{$state};
return $color ? ui_text_color($safe, $color) : $safe;
}

# index_edit_url(unit, user-tab)
# Returns the edit URL for a unit, preferring its safe override file.
sub index_edit_url
{
my ($unit, $user_tab) = @_;
my $url = $user_tab ?
	"edit_unit.cgi?scope=user&unituser=".urlize($unit->{'user'}).
	"&name=".urlize($unit->{'name'}) :
	"edit_unit.cgi?name=".urlize($unit->{'name'});
if (dropin_exists($user_tab, $unit->{'user'}, $unit->{'name'})) {
	$url .= "&dropin=1";
	}
return $url;
}
