
do 'status-lib.pl';

# list_system_info(&data, &in, [&skip-modules])
# Returns permitted monitors and module services as blocks or a table.
# Passes dashboard options and the optional skip list to providers; in is unused.
sub list_system_info
{
my ($data, $in, $skip) = @_;

# Pair local monitors with supplied services to share status and actions
my @monitors = &list_services();
my @provided = &module_dashboard_monitors($data, $skip);
my %controls = &match_dashboard_services(\@monitors, \@provided);
my %checks;
foreach my $m (@monitors) {
	my $p = $controls{$m->{'id'}};
	push(@{$checks{$p->{'id'}}}, $m) if ($p);
	}

# Apply dashboard limits to both monitors and supplied services
my %allowed = map { $_->{'id'} => 1 }
		  &dashboard_visible_monitors(\%access, @monitors, @provided);
# pair_allowed(&monitor) allows a pair if either saved ID is permitted
my $pair_allowed = sub {
	my ($m) = @_;
	my $p = $controls{$m->{'id'}};
	return $allowed{$m->{'id'}} || ($p && $allowed{$p->{'id'}});
	};

# Show configured monitors only for permitted users with saved results
my $show = $config{'sysinfo'} &&
	   ($config{'sysinfo_users'} == 2 ||
	    ($config{'sysinfo_users'} == 1 ?
		&foreign_available($module_name) :
		$base_remote_user =~ /^(root|admin)$/));
my (%oldstatus, @serv);
if ($show && &read_file($oldstatus_file, \%oldstatus)) {
	# Apply each monitor's visibility setting and the pair's ACL
	@serv = grep { !$_->{'nodashboard'} && &$pair_allowed($_) } @monitors;
	}
my %shown = map { $_->{'id'} => 1 } @serv;

# Provider services remain eligible when sysinfo hides monitors. Skip a
# service if any paired monitor is already shown or explicitly hidden.
foreach my $p (@provided) {
	my @m = @{$checks{$p->{'id'}} || []};
	next if (grep { $_->{'nodashboard'} || $shown{$_->{'id'}} } @m);
	push(@serv, $p) if ($allowed{$p->{'id'}} ||
			    grep { $allowed{$_->{'id'}} } @m);
	}
return ( ) if (!@serv);

# Include CSS in cached or sidebar copies without marking page assets loaded
local $main::ui_page_assets_done = 0;
my $assets = &ui_page_assets({ 'nojs' => 1 });

my $can = &foreign_available($module_name) && $access{'edit'};
my $down = 0;
my @rows;
foreach my $s (@serv) {
	# Use provider status for paired services, or saved results per host
	my $service = $controls{$s->{'id'}} || $s;
	my $stat = $service->{'provider'} ? { '*' => $service->{'up'} } :
		   &expand_oldstatus($oldstatus{$s->{'id'}}, $s);
	my @hosts = &expand_remotes($s);
	my @ups = grep { defined($_) } map { $stat->{$_} } @hosts;
	$down += scalar(grep { $_ == 0 } @ups);

	# Summarize multiple hosts by their worst status
	my ($worst) = sort { (&status_to_state($b))[2] <=>
			     (&status_to_state($a))[2] } @ups;
	my $row = { 'name' => $s->{'desc'}, 'remote' => join(' ', @hosts),
		    'up' => $worst };
	if (defined($worst)) {
		# Keep monitor-specific status wording
		($row->{'state'}, $row->{'icon'}) = &status_to_state($worst);
		$row->{'msg'} = &status_to_text(
			$worst, $s->{'provider'} ? undef : $s);
		}
	else {
		# No saved result is unknown, not a failure
		($row->{'state'}, $row->{'icon'}) = ( 'neutral', 'minus' );
		$row->{'msg'} = $text{'info_unknown'};
		}

	if ($can && !$s->{'provider'}) {
		# A monitor links to its own settings
		$row->{'href'} = &get_webprefix()."/$module_name/".
				 "edit_mon.cgi?id=".&urlize($s->{'id'});
		}
	elsif ($service->{'manage'}) {
		# A service links to the module that manages it
		$row->{'href'} = &get_webprefix().$service->{'manage'};
		}

	if (@hosts != 1 || $hosts[0] ne '*') {
		# Identify each host and show its status when available
		$row->{'hosts'} = join(" ", map {
			my $up = $stat->{$_};
			&ui_chip($_ eq '*' ? $text{'index_local'} : $_,
				 defined($up) ?
				  { 'state' => (&status_to_state($up))[0],
				    'title' => &status_to_text($up, $s) } :
				  undef);
			} @hosts);
		}

	# Let the action helper enforce local-service and permission checks
	$row->{'actions'} = &ui_cluster(
		[ &monitor_action_buttons($service, $stat->{'*'}) ],
		{ 'gap' => '6px' });
	push(@rows, $row);
	}

# Apply the monitor sort setting to both layouts; otherwise keep source order
if ($config{'sort_mode'} == 1) {
	# Sort by the displayed monitor or service name
	@rows = sort { $a->{'name'} cmp $b->{'name'} } @rows;
	}
elsif ($config{'sort_mode'} == 2) {
	# Sort by host names before they are formatted for display
	@rows = sort { $a->{'remote'} cmp $b->{'remote'} } @rows;
	}
elsif ($config{'sort_mode'} == 3) {
	# Sort by the displayed status, with unchecked monitors last
	@rows = sort { ($a->{'up'} // 2) <=> ($b->{'up'} // 2) } @rows;
	}

# Expand the panel when a check is down and use the chosen layout
return ( { 'type' => 'html',
	   'desc' => $text{'info_title'},
	   'open' => $down ? 1 : 0,
	   'id' => $module_name.'_services',
	   'html' => $assets.($config{'sysinfo'} == 2 ?
				&dashboard_list(\@rows) :
				&dashboard_blocks(\@rows)) } );
}

# dashboard_list(&rows)
# Renders a table with status text and service controls
sub dashboard_list
{
my ($rows) = @_;
# Include host and action columns only when at least one row needs them
my $hosts = grep { $_->{'hosts'} } @$rows;
my $actions = grep { $_->{'actions'} } @$rows;
my @heads = ( $text{'index_name'} );
push(@heads, $text{'index_host'}) if ($hosts);
push(@heads, $text{'index_up'});
push(@heads, $text{'info_actions'}) if ($actions);
my $html = &ui_columns_start(\@heads);
foreach my $r (@$rows) {
	# Escape names and status text before adding links and colors
	my $name = &html_escape($r->{'name'});
	$name = &ui_link($r->{'href'}, $name) if ($r->{'href'});
	my $status = &html_escape($r->{'msg'});
	$status = &ui_text_color($status, $r->{'state'} eq 'warning' ?
					'warn' : $r->{'state'})
		if ($r->{'state'} ne 'neutral');
	my @cols = ( $name );
	# Show each host as plain text on its own line
	push(@cols, join("<br>\n", map {
		$_ eq '*' ? $text{'index_local'} : &html_escape($_)
		} split(/\s+/, $r->{'remote'}))) if ($hosts);
	push(@cols, $status);
	push(@cols, $r->{'actions'}) if ($actions);
	$html .= &ui_columns_row(\@cols);
	}
return $html.&ui_columns_end();
}

# dashboard_blocks(&rows)
# Renders prepared service rows as blocks, up to four across
sub dashboard_blocks
{
my ($rows) = @_;
my @blocks;
foreach my $r (@$rows) {
	# Render the status, linked name and any host chips
	my $name = &html_escape($r->{'name'});
	my $stat = &ui_stat({
		'small' => 1,
		'value' => $r->{'msg'},
		'icon' => $r->{'icon'},
		'state' => $r->{'state'},
		'label_html' => $r->{'href'} ?
			&ui_tag('a', $name, { 'class' => 'ui_link',
					      'href' => $r->{'href'} }) : $name,
		'desc_html' => $r->{'hosts'} });
	# Align controls with the status; the grid stacks them on small screens
	push(@blocks, &ui_card({ 'body' => &ui_grid(
		[ $stat, $r->{'actions'} ],
		{ 'template' => 'minmax(0, 1fr) auto', 'gap' => '6px',
		  'align' => 'start' }) }));
	}
return &ui_grid(\@blocks, { 'min' => 'max(16em, calc(25% - 6px))',
			    'gap' => '7px' });
}

