# Builders for the UI demo pages. These functions use WebminCore helpers
# and the language, configuration and input hashes, and return HTML so
# the same pages can be rendered by the CGIs or with standalone test data.

use strict;
use warnings;

our (%config, %in, %text);

# demo_gallery_page()
# Returns the widget gallery page, organized with the existing tabs. Each
# tab opens with a short description in the same block markup that
# vui_ui_block of Virtualmin produces, as the Virtualmin Podman module does.
sub demo_gallery_page
{
my @tabs = ( [ 'cards', $text{'index_tab_cards'} ],
	     [ 'elements', $text{'index_tab_elements'} ],
	     [ 'alerts', $text{'index_tab_alerts'} ],
	     [ 'forms', $text{'index_tab_forms'} ],
	     [ 'choices', $text{'index_tab_choices'} ],
	     [ 'buttons', $text{'index_tab_buttons'} ],
	     [ 'accordions', $text{'index_tab_accordions'} ],
	     [ 'tables', $text{'index_tab_tables'} ],
	     [ 'lists', $text{'index_tab_lists'} ],
	     [ 'iconlinks', $text{'index_tab_iconlinks'} ],
	     [ 'editor', $text{'index_tab_editor'} ] );
my %builders = ( 'cards' => \&demo_cards_tab,
		 'elements' => \&demo_elements_tab,
		 'alerts' => \&demo_alerts_tab,
		 'forms' => \&demo_forms_tab,
		 'choices' => \&demo_choices_tab,
		 'buttons' => \&demo_buttons_tab,
		 'accordions' => \&demo_accordions_tab,
		 'tables' => \&demo_tables_tab,
		 'lists' => \&demo_lists_tab,
		 'iconlinks' => \&demo_iconlinks_tab,
		 'editor' => \&demo_editor_tab );
# The tab to open comes from the URL, else from the module config, whose
# default_tab option is set on the module configuration page
my $mode = $in{'mode'} || $config{'default_tab'} || 'cards';
$mode = 'cards' if (!(grep { $_->[0] eq $mode } @tabs));
my $rv = "";
$rv .= ui_page_start({
	'desc' => $text{'index_desc'},
	'help' => 'https://webmin.com/docs/development/creating-modules',
	'help_title' => $text{'index_docs'},
	});
$rv .= ui_tabs_start(\@tabs, 'mode', $mode, 1);
foreach my $tab (@tabs) {
	$rv .= ui_tabs_start_tab('mode', $tab->[0]);
	# The description, with the rest of it behind a ui_details tick when
	# the lang file has an index_<tab>_more string, as the Virtualmin SSL
	# certificate page extends its tab descriptions
	my $desc = html_escape($text{'index_'.$tab->[0].'_desc'});
	my $more = $text{'index_'.$tab->[0].'_more'};
	$rv .= ui_tag('div',
		$more ? ui_details({ 'html' => 1, 'class' => 'inline',
				     'title' => $desc,
				     'content' => html_escape($more) })
		      : ui_p($desc),
		{ 'class' => 'vui_ui_block' });
	$rv .= $builders{$tab->[0]}->();
	$rv .= ui_tabs_end_tab('mode', $tab->[0]);
	}
$rv .= ui_tabs_end(1);
$rv .= ui_page_end();
return $rv;
}

# demo_cards_tab()
# Returns the cards and stat tiles panel of the gallery
sub demo_cards_tab
{
my $rv = "";

# A service control card as a module would build it, a card with header
# actions and a footer, and a card with a state accent.
#
# The four buttons are plain ui_submit calls. Their colors and icons in
# Authentic (green Start with a play icon, red Stop, orange Restart, a
# switch icon for the boot option) are not chosen here. The theme looks
# the button label up in the lang table, finds the key or keys holding
# that exact text, and picks the style from the KEY NAME : keys
# containing start, restart, index_stop, index_reload, index_boot,
# delete, status and so on (see get_button_style in Authentic). Two
# rules follow, for as long as this theme behavior exists :
#  - name button keys simply and stably, as index_start, index_stop,
#    index_restart, index_reload and index_boot_off are here;
#  - keep each button text unique in the lang file. If the same text,
#    say "Restart", also sits under some other key, the lookup may find
#    that key instead and the button gets no color or icon.
#
# The credentials
# row uses the existing ui_text_mask(text, tag) : the password is shown
# as dots and revealed while the enclosing tag (here a tt) is hovered, as
# the Virtualmin Podman module shows recipe logins.
my $service = ui_card({
	'title' => $text{'index_service'},
	'actions' => ui_badge($text{'index_running'}, 'success'),
	'body' =>
		ui_dl([
			[ $text{'index_boot'}, html_escape($text{'index_boot_on'}) ],
			[ $text{'index_creds'},
			  text('index_creds_userpass', ui_tag('tt', 'admin'),
			       ui_tag('tt', ui_text_mask('Y8u-2mP4-qL9x', 'tt'))) ],
			]).
		ui_hr().
		ui_form_start('index.cgi', 'post').
		ui_cluster([
			ui_submit($text{'index_start'}, 'start'),
			ui_submit($text{'index_stop'}, 'stop', 0,
				  "data-ui-confirm='".
				  quote_escape($text{'index_stop_confirm'})."'"),
			ui_submit($text{'index_restart'}, 'restart'),
			ui_submit($text{'index_boot_off'}, 'bootoff'),
			]).
		ui_form_end(),
	});
$rv .= ui_grid([
	$service,
	ui_card({
		'title' => $text{'index_card_actions'},
		'desc' => $text{'index_card_desc'},
		'actions' => [
			ui_badge($text{'index_syncing'}, 'info'),
			ui_link('index.cgi', html_escape($text{'index_manage'})),
			],
		'body' => html_escape($text{'index_card_actions_body'}),
		'footer' => html_escape($text{'index_card_footer'}),
		}),
	ui_card({
		'title' => $text{'index_card_state'},
		'state' => 'warning',
		'body' => html_escape($text{'index_card_state_body'}),
		}),
	]);

# Stat tiles
$rv .= ui_card({
	'title' => $text{'index_stats'},
	'desc' => $text{'index_stats_desc'},
	'body' => ui_stats([
		{ 'value' => 128, 'label' => $text{'index_stat_units'},
		  'desc' => $text{'index_stat_units_desc'},
		  'href' => 'index.cgi' },
		{ 'value' => 3, 'label' => $text{'index_stat_failed'},
		  'desc' => $text{'index_stat_failed_desc'},
		  'state' => 'danger' },
		{ 'value' => '42 d', 'label' => $text{'index_stat_uptime'},
		  'desc' => $text{'index_stat_uptime_desc'},
		  'state' => 'success' },
		{ 'value' => "94%", 'label' => $text{'index_stat_disk'},
		  'desc' => $text{'index_stat_disk_desc'},
		  'state' => 'warning' },
		]),
	});
# A narrow card next to a wide one, laid out with the template option
# of ui_grid. The left card is a description list flowed into two
# columns; the right one is flush, holds a list, and its header action
# is a search box that filters that list client-side, aimed at the
# card through its id
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_k_system'},
		'body' => ui_dl([
			[ $text{'index_k_hostname'}, ui_tag('tt', 'web01.example.com') ],
			[ $text{'index_k_os'}, 'AlmaLinux 10.2' ],
			[ $text{'index_k_kernel'}, ui_tag('tt', '6.12.0-211.49.1') ],
			[ $text{'index_k_uptime'}, '42 '.$text{'index_l_days_plain'} ],
			[ $text{'index_k_load'}, '0.42 0.38 0.35' ],
			[ $text{'index_k_memory'}, '5.1 GB of 16 GB' ],
			], { 'cols' => 2 }),
		}),
	ui_card({
		'id' => 'demo_services',
		'title' => $text{'index_k_services'},
		'actions' => ui_search({ 'name' => 'svc', 'width' => '12em',
					 'filter' => '#demo_services' }),
		'flush' => 1,
		'body' => ui_list([
			{ 'title' => 'httpd', 'desc' => 'The Apache HTTP Server',
			  'badge' => [ $text{'index_running'}, 'success' ] },
			{ 'title' => 'mariadb', 'desc' => 'MariaDB database server',
			  'badge' => [ $text{'index_running'}, 'success' ] },
			{ 'title' => 'postfix', 'desc' => 'Postfix Mail Transport Agent',
			  'badge' => [ $text{'index_stopped'}, 'danger' ] },
			{ 'title' => 'sshd', 'desc' => 'OpenSSH server daemon',
			  'badge' => [ $text{'index_running'}, 'success' ] },
			], { 'flush' => 1 }),
		}),
	], { 'template' => 'minmax(280px, 1fr) minmax(0, 2fr)' });

# Small state cards : the accent color says what kind of news it is, the
# title is built with title_html to carry an icon, and the footer holds
# the next step
$rv .= ui_grid([
	ui_card({
		'state' => 'success',
		'title_html' => ui_svg_icon('check-circle')." ".
				html_escape($text{'index_k_ok'}),
		'body' => html_escape($text{'index_k_ok_body'}),
		}),
	ui_card({
		'state' => 'info',
		'title_html' => ui_svg_icon('download')." ".
				html_escape($text{'index_k_updates'}),
		'body' => html_escape($text{'index_k_updates_body'}),
		'footer' => ui_link_button('index.cgi', $text{'index_k_install'}),
		}),
	ui_card({
		'state' => 'danger',
		'title_html' => ui_svg_icon('x-circle')." ".
				html_escape($text{'index_k_backup'}),
		'body' => html_escape($text{'index_k_backup_body'}),
		'footer' => ui_link('index.cgi', html_escape($text{'index_l_log'})),
		}),
	]);

# A card with a standard table inside, keeping the body padding so the
# table's own border stays clear of the card's; a metric card mixing a
# stat tile with inline progress bars; and a card printed progressively
# with ui_card_start and ui_card_end, as a page streaming command output
# would do, holding a code block and ending with a badge in its footer
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_k_logins'},
		'body' => ui_columns_table(
			[ $text{'index_k_user'}, $text{'index_k_from'},
			  $text{'index_k_when'} ], 100,
			[ [ 'root', '10.211.55.2', '2 '.$text{'index_feed_hours'} ],
			  [ 'deploy', '192.0.2.10', '5 '.$text{'index_feed_hours'} ],
			  [ 'root', '10.211.55.2', $text{'index_k_yesterday'} ] ]),
		}),
	ui_card({
		'title' => $text{'index_k_storage'},
		'body' => ui_stack([
			ui_stat({ 'value' => '63%', 'label' => $text{'index_disk'},
				  'desc' => '63 GB of 100 GB', 'state' => 'warning' }),
			ui_progress(91, { 'label' => '/home', 'inline' => 1,
					  'thresholds' => 1 }),
			ui_progress(12, { 'label' => '/var/log', 'inline' => 1,
					  'thresholds' => 1 }),
			], { 'gap' => '10px' }),
		'footer' => ui_link('index.cgi', html_escape($text{'index_k_details'})),
		}),
	ui_card_start({ 'title' => $text{'index_k_output'},
			'desc' => $text{'index_k_output_desc'} }).
	ui_tag('pre', html_escape(
		"Sep 05 08:12:01 web01 systemd[1]: Starting httpd...\n".
		"Sep 05 08:12:02 web01 httpd[2183]: listening on port 443, port 80\n".
		"Sep 05 08:12:02 web01 systemd[1]: Started The Apache HTTP Server."),
		{ 'class' => 'ui_code_block' }).
	ui_card_end(ui_badge($text{'index_k_done'}, 'success')),
	]);

return $rv;
}

# demo_elements_tab()
# Returns the description list, stat tiles, feed, empty state, badges,
# tooltips, progress bars and icons panel. Cards are paired so that a
# short one sits next to a short one.
sub demo_elements_tab
{
my $rv = "";

# A description list with help bubbles and HTML values, and stat tiles
# with icons and links
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_e_dl'},
		'desc' => $text{'index_e_dl_desc'},
		'body' => ui_dl([
			# Array rows : label, HTML value, optional help text
			[ $text{'index_e_dl_status'},
			  ui_badge($text{'index_running'}, 'success'),
			  $text{'index_e_dl_status_help'} ],
			[ $text{'index_e_dl_version'}, ui_code('2.660') ],
			# A link inside a value is built with ui_tag, not
			# ui_link : Authentic turns every ui_link into a button
			[ $text{'index_e_dl_config'},
			  ui_code('/etc/webmin/miniserv.conf')." ".
				ui_tag('a', html_escape($text{'index_edit'}),
				       { 'href' => 'index.cgi' }),
			  $text{'index_e_dl_config_help'} ],
			# A hash row escapes its value for you
			{ 'label' => $text{'index_e_dl_started'},
			  'value' => '2026-09-05 08:12 <root>',
			  'help' => $text{'index_e_dl_started_help'} },
			], { 'wide' => '35%' }),
		}),
	ui_card({
		'title' => $text{'index_e_istats'},
		'desc' => $text{'index_e_istats_desc'},
		'body' => ui_stats([
			{ 'value' => 12, 'label' => $text{'index_e_domains'},
			  'icon' => 'globe', 'href' => 'index.cgi' },
			{ 'value' => 48, 'label' => $text{'index_e_users'},
			  'icon' => 'user', 'href' => 'index.cgi' },
			{ 'value' => 131, 'label' => $text{'index_e_mail'},
			  'icon' => 'server' },
			{ 'value' => 2, 'label' => $text{'index_e_alerts'},
			  'icon' => 'warning', 'state' => 'danger',
			  'href' => 'index.cgi' },
			], { 'min' => '120px' }),
		}),
	]);

# Activity feed, with one event built from HTML, and the empty state
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_feed'},
		'actions' => ui_link('index.cgi', html_escape($text{'index_allevents'})),
		'body' => ui_feed([
			{ 'when' => $text{'index_feed_now'},
			  'text' => 'Service started (v0.1.4)',
			  'state' => 'success' },
			{ 'when' => '5 '.$text{'index_feed_minutes'},
			  'text' => 'Service stopped' },
			{ 'when' => '2 '.$text{'index_feed_hours'},
			  # A text link in the event, so ui_tag rather than
			  # ui_link, which Authentic would render as a button
			  'text_html' => text('index_feed_backup', ui_code('/home')).
					 " ".ui_tag('a', html_escape($text{'index_l_log'}),
						    { 'href' => 'index.cgi' }),
			  'state' => 'info' },
			{ 'when' => '14 '.$text{'index_feed_hours'},
			  'text' => '3 failed login attempts blocked',
			  'state' => 'warning' },
			]),
		}),
	ui_card({
		'title' => $text{'index_empty'},
		'body' => ui_empty_state({
			'icon' => 'search',
			'title' => $text{'index_empty_title'},
			'desc' => $text{'index_empty_desc'},
			'actions' => ui_link_button('index.cgi',
						    $text{'index_empty_action'}),
			}),
		}),
	]);

# Badges, chips, tooltips and inline elements next to the ring gauges
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_badges'},
		'body' =>
		    ui_stack([
			# One badge per state, the default icon of each state,
			# and the neutral one with no icon at all
			ui_cluster([
			    ui_badge($text{'index_running'}, 'success'),
			    ui_badge($text{'index_pending'}, 'warning'),
			    ui_badge($text{'index_stopped'}, 'danger'),
			    ui_badge($text{'index_syncing'}, 'info'),
			    ui_badge($text{'index_off'}, 'neutral',
				     { 'icon' => '' }),
			    ]),
			# A dot instead of an icon, an icon of your own, a
			# tooltip on hover, and chips for tags
			ui_cluster([
			    ui_badge($text{'index_running'}, 'success',
				     { 'dot' => 1 }),
			    ui_badge($text{'index_stopped'}, 'danger',
				     { 'dot' => 1 }),
			    ui_badge($text{'index_badge_clock'}, 'info',
				     { 'icon' => 'clock' }),
			    ui_badge($text{'index_badge_tip'}, 'neutral',
				     { 'icon' => 'question-circle',
				       'title' => $text{'index_badge_tip_text'} }),
			    ui_chip('journal'),
			    ui_chip('ipv6'),
			    ]),
			# Inline code, a note, the existing help bubble, and
			# ui_tip, which gives any HTML the same theme tooltip
			ui_cluster([
			    ui_code('/etc/webmin/miniserv.conf'),
			    ui_note($text{'index_note'}, 0),
			    html_escape($text{'index_help_demo'})." ".
				ui_help($text{'index_help_tip'}),
			    ui_tip(ui_tag('u', html_escape($text{'index_tip_text'})),
				   $text{'index_tip'}),
			    ]),
			], { 'gap' => '14px' }),
		}),
	ui_card({
		'title' => $text{'index_p_rings'},
		'desc' => $text{'index_p_rings_desc'},
		'body' => ui_cluster([
			ui_progress(34, { 'label' => $text{'index_disk'},
					  'ring' => 1, 'thresholds' => 1 }),
			ui_progress(78, { 'label' => $text{'index_memory'},
					  'ring' => 1, 'thresholds' => 1 }),
			ui_progress(96, { 'label' => $text{'index_cpu'},
					  'ring' => 1, 'thresholds' => 1 }),
			ui_progress(3.4, { 'label' => $text{'index_p_quota'},
					   'ring' => 1, 'max' => 10, 'size' => 72,
					   'value' => '3.4G' }),
			ui_progress(0, { 'label' => $text{'index_p_working'},
					 'ring' => 1, 'indeterminate' => 1 }),
			], { 'gap' => '24px' }),
		}),
	]);

# Progress bars, the plain ones and the variations
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_progress'},
		'body' => ui_stack([
			# A bar with its own max and value text, bars whose
			# color follows the value through thresholds, and
			# bars with the value marker on the bar itself
			ui_progress(3.4, { 'label' => $text{'index_disk'},
					   'max' => 10,
					   'value' => $text{'index_p_disk_value'} }),
			ui_progress(45, { 'label' => $text{'index_memory'},
					  'thresholds' => 1 }),
			ui_progress(96, { 'label' => $text{'index_cpu'},
					  'thresholds' => [ 60, 85 ] }),
			ui_progress(62, { 'label' => $text{'index_p_inside'},
					  'inside' => 1, 'state' => 'success' }),
			ui_progress(34, { 'label' => $text{'index_disk'},
					  'inside' => 1 }),
			ui_progress(96, { 'label' => $text{'index_cpu'},
					  'inside' => 1, 'thresholds' => 1 }),
			ui_progress(52, { 'small' => 1 }),
			], { 'gap' => '14px' }),
		}),
	ui_card({
		'title' => $text{'index_p_more'},
		'body' => ui_stack([
			ui_progress(0, {
				'label' => $text{'index_p_segments'},
				'segments' => [
					{ 'pct' => 46, 'state' => 'info',
					  'label' => $text{'index_p_used'} },
					{ 'pct' => 22, 'state' => 'warning',
					  'label' => $text{'index_p_cache'} },
					{ 'pct' => 9, 'state' => 'danger',
					  'label' => $text{'index_p_reserved'} },
					] }),
			ui_progress(0, { 'label' => $text{'index_p_busy'},
					 'indeterminate' => 1 }),
			ui_stack([
				ui_progress(18, { 'label' => $text{'index_cpu'},
						  'inline' => 1, 'thresholds' => 1 }),
				ui_progress(71, { 'label' => $text{'index_memory'},
						  'inline' => 1, 'thresholds' => 1 }),
				ui_progress(93, { 'label' => $text{'index_disk'},
						  'inline' => 1, 'thresholds' => 1 }),
				], { 'gap' => '6px' }),
			], { 'gap' => '18px' }),
		}),
	]);

# Icon set
my @icons = ( 'check', 'check-circle', 'x', 'x-circle', 'info-circle',
	      'question-circle', 'warning', 'search', 'external',
	      'chevron-down', 'chevron-up', 'chevron-right', 'chevron-left',
	      'arrow-right', 'plus', 'minus', 'refresh', 'play', 'stop',
	      'power', 'clock', 'shield', 'server', 'gear', 'user', 'trash',
	      'download', 'upload', 'edit', 'terminal', 'filter', 'book',
	      'globe', 'dot' );
$rv .= ui_card({
	'title' => $text{'index_icons'},
	'desc' => $text{'index_icons_desc'},
	'body' => ui_cluster(
		[ map { ui_tip(ui_svg_icon($_, { 'size' => 18 }), $_) }
		      @icons ],
		{ 'gap' => '14px' }),
	});
return $rv;
}

# demo_forms_tab()
# Returns the form panel of the gallery. The form is the existing
# ui_table_start / ui_table_row layout with the existing controls, and
# shows the new toggle switch among them.
sub demo_forms_tab
{
my $rv = "";
$rv .= ui_form_start('index.cgi', 'post');
$rv .= ui_hidden('demo', 1);
$rv .= ui_table_start($text{'index_f_title'}, 'width=100%', 2);
$rv .= ui_table_row($text{'index_f_name'},
	ui_textbox('name', 'web01', 30)." ".ui_help($text{'index_f_name_help'}));
# Password fields. The strength meter, the show/hide eye and the generate
# key button seen next to them are an Authentic feature, not part of the
# core library. The theme only turns them on for a list of module pages
# it knows, or when a password input on the page carries a data-password
# attribute : then every password input gets the meter and the buttons,
# except one marked data-password-again, which is treated as the repeat
# field and only gets the eye. Other themes show plain password inputs.
# The theme measures the field at page load to size the meter. A field
# in a hidden tab pane measures 0 then, so themes that do not account
# for hidden inputs can collapse it to zero width.
$rv .= ui_table_row($text{'index_f_pass'},
	ui_password('pass', '', 30, 0, undef, 'data-password'));
$rv .= ui_table_row($text{'index_f_pass2'},
	ui_password('pass2', '', 30, 0, undef, 'data-password-again'));
$rv .= ui_table_row($text{'index_f_port'},
	ui_textbox('port', 10000, 8)." ".ui_help($text{'index_f_port_help'}));
$rv .= ui_table_row($text{'index_f_proto'},
	ui_select('proto', 'https',
		  [ [ 'http', 'HTTP' ], [ 'https', 'HTTPS' ],
		    [ 'both', $text{'index_f_both'} ] ]));
$rv .= ui_table_row($text{'index_f_log'},
	ui_radio('log', 'errors',
		 [ [ 'all', $text{'index_f_log_all'} ],
		   [ 'errors', $text{'index_f_log_err'} ],
		   [ 'none', $text{'index_f_log_none'} ] ]));
$rv .= ui_table_row($text{'index_f_feat'},
	ui_checkbox('ssl', 1, $text{'index_f_ssl'}, 1)."<br>".
	ui_checkbox('compress', 1, $text{'index_f_compress'}, 0));
$rv .= ui_table_row($text{'index_f_boot'},
	ui_toggle({ 'name' => 'boot', 'checked' => 1,
		    'label' => $text{'index_f_boot_label'} }));
$rv .= ui_table_row($text{'index_f_active'}, ui_yesno_radio('active', 1));
$rv .= ui_table_row($text{'index_f_limit'},
	ui_opt_textbox('limit', '', 6, $text{'index_f_unlimited'},
		       $text{'index_f_limit_to'}));
$rv .= ui_table_row($text{'index_f_quota'}, ui_bytesbox('quota', 1073741824));

# Date selection as in the Webmin Actions Log module : quick choices, or
# a range of two date inputs each with the popup calendar chooser
$rv .= ui_table_row($text{'index_f_dates'},
	ui_radio('tall', 2,
		 [ [ 1, $text{'index_f_dates_all'}."<br>" ],
		   [ 2, $text{'index_f_today'}."<br>" ],
		   [ 3, $text{'index_f_yesterday'}."<br>" ],
		   [ 4, $text{'index_f_week'}."<br>" ],
		   [ 0, "<span class='ui_data'>".
			text('index_f_between', demo_date_input('from'),
			     demo_date_input('to'))."</span>" ] ]));
$rv .= ui_table_row($text{'index_f_notes'},
	ui_textarea('notes', "# ".$text{'index_f_notes_value'}, 4, 60));
$rv .= ui_table_end();
$rv .= ui_form_end([ [ 'save', $text{'save'} ],
		     [ 'cancel', $text{'index_f_cancel'} ],
		     [ 'delete', $text{'delete'}, undef, 0,
		       "data-ui-confirm='".
		       quote_escape($text{'index_f_delete_confirm'})."'" ] ]);

# Choosers : each is the plain textbox followed by a button that opens the
# matching popup chooser and fills the field in. file_chooser_button
# picks a file, or a directory when its type argument is 1; ui_filebox is
# the shorthand for the same pair when the form is the first on the
# page. ui_user_textbox and ui_group_textbox pick one Unix user or group,
# ui_users_textbox and ui_groups_textbox several, separated by spaces.
# The popups find their field by the index of the form in the page, so
# it is passed here : the service card form is 0, the edit form above is
# 1, and this one is 2. The first label carries a help link built with
# hlink, which opens help/file.html from the module's help directory.
my $formno = 2;
$rv .= ui_form_start('index.cgi', 'post');
$rv .= ui_hidden('demo', 6);
$rv .= ui_table_start($text{'index_f_pickers'}, 'width=100%', 2);
$rv .= ui_table_row(hlink($text{'index_f_file'}, 'file'),
	ui_textbox('cfg', '/etc/example/service.conf', 40)." ".
	file_chooser_button('cfg', 0, $formno));
$rv .= ui_table_row($text{'index_f_dir'},
	ui_textbox('logdir', '/var/log', 40)." ".
	file_chooser_button('logdir', 1, $formno));
$rv .= ui_table_row($text{'index_f_owner'},
	ui_user_textbox('owner', 'root', $formno));
$rv .= ui_table_row($text{'index_f_group'},
	ui_group_textbox('grp', 'wheel', $formno));
$rv .= ui_table_row($text{'index_f_members'},
	ui_users_textbox('members', 'root nobody', $formno));
$rv .= ui_table_row($text{'index_f_groups'},
	ui_groups_textbox('grps', 'wheel adm', $formno));
$rv .= ui_table_end();
$rv .= ui_form_end([ [ undef, $text{'save'} ] ]);

# The new controls on their own : a search box with its own placeholder,
# and a toggle in each state, each labelled with the setting it switches
$rv .= ui_card({
	'title' => $text{'index_f_stacked'},
	'desc' => $text{'index_f_stacked_desc'},
	'body' => ui_cluster([
		ui_search({ 'name' => 'q', 'width' => '18em',
			    'placeholder' => $text{'index_f_search_ph'} }),
		ui_toggle({ 'name' => 'alerts',
			    'label' => $text{'index_f_alerts'} }),
		ui_toggle({ 'name' => 'autoupdate', 'checked' => 1,
			    'label' => $text{'index_f_autoupdate'} }),
		], { 'gap' => '20px' }),
	});
return $rv;
}

# demo_date_input(name)
# Returns day, month and year inputs followed by the calendar popup button,
# exactly as the Webmin Actions Log module builds its date fields
sub demo_date_input
{
my ($name) = @_;
return ui_date_input(undef, undef, undef,
		     $name."_d", $name."_m", $name."_y").
       date_chooser_button($name."_d", $name."_m", $name."_y");
}

# demo_choices_tab()
# Returns the choice widgets panel : three ways to let the user pick one
# option that needs its own inputs, all replacing ui_radio_table and the
# hand-built tables of radios and fields of pages like the backup
# destination selector of the Backup Configuration Files module or the
# address selectors of Virtualmin's "Change IP Address" page :
#  - ui_choice : a boxed list where every option shows its inputs and
#    fields all the time, each row wrapping on narrow screens instead of
#    squeezing a five-column table;
#  - ui_select_switch : a select and, under it, only the block of the
#    chosen option, switched by ui-lib.js, for many options or long field
#    lists;
#  - ui_radio_list : the compact list of radios with at most one input
#    each, buttons at the left edge and close together in one box.
# Each option is a hash : value, label, optional content shown after the
# label (or first in the block for the select), optional desc, and
# optional fields laid out in as many columns as fit.
sub demo_choices_tab
{
my $rv = "";
$rv .= ui_form_start('index.cgi', 'post');
$rv .= ui_hidden('mode', 'choices');

# The backup destination options, built for a given field name prefix so
# that the two widgets below can show the same set without clashing. The
# file chooser needs the index of this form on the page : the service
# card form is 0, the edit and choosers forms of the Forms tab are 1 and
# 2, so this one is 3.
my $formno = 3;
my $dest_options = sub {
	my ($p) = @_;
	return [
		{ 'value' => 'local', 'label' => $text{'index_c_local'},
		  'content' => ui_textbox($p.'local_file', '', 45, 0, undef,
				"placeholder='/backups/configs-%y-%m-%d.tar.gz'").
			       " ".file_chooser_button($p.'local_file', 0, $formno) },
		( map { {
		  'value' => $_->[0], 'label' => $_->[1],
		  'content' => ui_textbox($p.$_->[0].'_server', '', 20),
		  'fields' => [
			[ $text{'index_c_path'},
			  ui_textbox($p.$_->[0].'_path', '', 25) ],
			[ $text{'index_c_login'},
			  ui_textbox($p.$_->[0].'_user', 'root', 15) ],
			[ $text{'index_c_pass'},
			  ui_password($p.$_->[0].'_pass', '', 15) ],
			[ $text{'index_c_port'},
			  ui_opt_textbox($p.$_->[0].'_port', '', 5, $text{'default'}) ],
			] } } ( [ 'ftp', $text{'index_c_ftp'} ],
				[ 'ssh', $text{'index_c_ssh'} ] ) ),
		{ 'value' => 'download', 'label' => $text{'index_c_download'},
		  'desc' => $text{'index_c_download_desc'} },
		];
	};
$rv .= ui_table_start($text{'index_c_backup'}, 'width=100%', 2);
$rv .= ui_table_row($text{'index_c_dest'},
	ui_choice('dest', 'ftp', $dest_options->('')), 2);
$rv .= ui_table_row($text{'index_c_dest_select'},
	ui_select_switch('dest2', 'ftp', $dest_options->('s_')), 2);
$rv .= ui_table_end();

# The address selectors, one ui_radio_table each in Virtualmin
$rv .= ui_table_start($text{'index_c_ip'}, 'width=100%', 2);
foreach my $v ( [ 'mode4', 'index_c_ip4', '10.211.55.20' ],
		[ 'mode6', 'index_c_ip6', 'fdb2:2c26:f4e4:0:21c:42ff:fea2:f273' ] ) {
	my ($name, $key, $addr) = @$v;
	$rv .= ui_table_row($text{$key}, ui_radio_list($name, 'shared', [
		{ 'value' => 'none', 'label' => $text{'index_c_none'} },
		{ 'value' => 'shared', 'label' => $text{'index_c_shared'},
		  'content' => ui_select($name.'_shared', $addr,
			[ [ $addr, text('index_c_shared_of', $addr) ] ]) },
		{ 'value' => 'dedicated', 'label' => $text{'index_c_dedicated'},
		  'content' => ui_textbox($name.'_ip', '', 24)." ".
			       ui_checkbox($name.'_active', 1,
					   $text{'index_c_active'}, 0) },
		]));
	}
$rv .= ui_table_end();
$rv .= ui_form_end([ [ undef, $text{'save'} ] ]);
return $rv;
}

# demo_buttons_tab()
# Returns the button examples : every single button function, the row of
# ui_form_end, the responsive groups of ui_form_grouped_buttons, the
# left and right split of ui_form_end_side_by_side, and the confirmation
# page a delete link should lead to.
#
# The buttons under a page (the "Return to ..." ones) are not built here
# at all : they come from the pairs of URL and text given to
# ui_print_footer, most specific first, which every theme draws as its
# footer buttons. edit_manual.cgi shows a page with two of them.
sub demo_buttons_tab
{
my $rv = "";
my $confirm = "data-ui-confirm='".
	      quote_escape($text{'index_f_delete_confirm'})."'";

# Submit, reset and link buttons in one row. ui_submit sends the form, and gets
# its color and icon in Authentic from the lang key of its label (see
# the Cards tab) : "save" is green here and "delete" red. The third
# argument disables a button. ui_reset restores the form's initial values, and
# ui_link_button is a link drawn as a button. ui_button, a button that
# does only what its onclick says, is left out here. The confirm attribute
# is handled by ui-lib.js.
$rv .= ui_card({
	'title' => $text{'index_b_single'},
	'desc' => $text{'index_b_single_desc'},
	'body' => ui_form_start('index.cgi', 'post').
		  ui_hidden('demo', 4).
		  ui_cluster([
			ui_submit($text{'save'}),
			ui_submit($text{'delete'}, 'delete', 0, $confirm),
			ui_submit($text{'index_b_disabled'}, 'noop', 1),
			ui_reset($text{'index_b_reset'}),
			ui_link_button('index.cgi?mode=cards',
				       $text{'index_b_cards'}),
			]).
		  ui_form_end(),
	});

# The usual end of an edit form. ui_form_end takes one array per button :
# name, label, HTML after the button, disabled flag, extra attributes.
# A button without a name is the default action.
$rv .= ui_form_start('index.cgi', 'post');
$rv .= ui_hidden('demo', 5);
$rv .= ui_table_start($text{'index_b_end'}, 'width=100%', 2);
$rv .= ui_table_row($text{'index_f_name'}, ui_textbox('name3', 'web02', 30));
$rv .= ui_table_end();
$rv .= ui_form_end([
	[ undef, $text{'save'} ],
	[ 'apply', $text{'index_b_saveapply'} ],
	[ 'delete', $text{'delete'}, undef, 0, $confirm ],
	]);

# Responsive button groups : related actions stay together, destructive
# ones are kept apart, and a button that submits elsewhere is bound to
# its own hidden form through the form attribute
$rv .= ui_form_start('index.cgi', 'post');
$rv .= ui_hidden('demo', 2);
$rv .= ui_table_start($text{'index_f_grouped'}, 'width=100%', 2);
$rv .= ui_table_row($text{'index_f_name'}, ui_textbox('name2', 'web01', 30));
$rv .= ui_table_row($text{'index_f_boot'},
	ui_toggle({ 'name' => 'boot4', 'checked' => 1,
		    'label' => $text{'index_f_boot_label'} }));
$rv .= ui_table_end();
my @save_actions = ( [ undef, $text{'save'} ] );
my @lifecycle_actions = ( [ 'stop', $text{'index_stop'} ],
			  [ 'restart', $text{'index_restart'} ] );
my @delete_actions = ( [ 'delete', $text{'delete'}, undef, 0, $confirm ] );
my @inspect_actions = ( [ undef, $text{'index_f_logs'}, undef, undef,
			  "form='demo_logs_form'" ] );
$rv .= ui_form_grouped_buttons([
	[ \@save_actions, \@lifecycle_actions, \@delete_actions ],
	\@inspect_actions,
	]);
$rv .= ui_form_end();
$rv .= ui_form_start('index.cgi', undef, undef,
		     "id='demo_logs_form' style='display:none;'").
       ui_hidden('demo', 3).
       ui_form_end();
# A note under buttons goes in its own div with a little room above it
$rv .= ui_tag('div', ui_note($text{'index_f_grouped_desc'}),
	      { 'style' => 'margin-top: 6px' });

# Save at the left and Delete at the right, as Virtualmin's edit pages
# end. The form gets an id, ui_form_end_side_by_side closes it, and the
# left buttons still submit it through the form attribute. The right
# side is raw HTML, here a small form of its own, since a form cannot
# be nested in another one.
$rv .= ui_form_start('index.cgi', 'post', undef, "id='demo_side_form'");
$rv .= ui_hidden('demo', 6);
$rv .= ui_table_start($text{'index_b_sides'}, 'width=100%', 2);
$rv .= ui_table_row($text{'index_f_name'}, ui_textbox('name4', 'web03', 30));
$rv .= ui_table_end();
$rv .= ui_form_end_side_by_side('demo_side_form',
	[ [ undef, $text{'save'} ], [ 'apply', $text{'index_b_saveapply'} ] ],
	[ ui_form_start('index.cgi', 'post').
	  ui_hidden('demo', 7).
	  ui_submit($text{'delete'}, 'delete', 0, $confirm).
	  ui_form_end() ]);

# The page a delete link leads to before anything is removed, as
# delete_user.cgi of Users and Groups shows. ui_confirmation_form returns
# the message, the red warning, any extra inputs, the hidden fields and
# the buttons, centered, and submits to the CGI that does the work. The
# lang key of the button holds "delete", so Authentic paints it red
# with its icon, as it does for every key containing that word.
$rv .= ui_card({
	'title' => $text{'index_b_confirm'},
	'desc' => $text{'index_b_confirm_desc'},
	'body' => ui_confirmation_form('index.cgi',
		text('index_b_confirm_msg', ui_tag('tt', 'web01')),
		[ [ 'demo', 8 ], [ 'name', 'web01' ] ],
		[ [ 'confirm', $text{'index_b_delete'} ] ],
		ui_checkbox('purge', 1, $text{'index_b_confirm_purge'}, 0),
		$text{'index_b_confirm_warn'}),
	});
return $rv;
}

# demo_accordions_tab()
# Returns a settings form in the style of the grub2 module : a first
# table of common settings, followed by collapsible sections for the
# rest, all in one form
sub demo_accordions_tab
{
my $rv = "";
$rv .= ui_form_start('index.cgi', 'post');
$rv .= ui_hidden('demo', 4);

# Common settings, always visible
$rv .= ui_table_start($text{'index_a_general'}, 'width=100%', 2);
$rv .= ui_table_row($text{'index_a_hostname'}, ui_textbox('hostname', 'web01.example.com', 40));
$rv .= ui_table_row($text{'index_a_enabled'}, ui_yesno_radio('enabled', 1));
$rv .= ui_table_row($text{'index_a_desc'}, ui_textbox('description', '', 60));
$rv .= ui_table_end();

# Less common settings in collapsible sections. The fifth argument opens
# a section : the first two start open, the last one collapsed
$rv .= ui_hidden_table_start($text{'index_a_network'}, 'width=100%', 2, 'network', 1);
$rv .= ui_table_row($text{'index_a_address'},
	ui_opt_textbox('address', '', 20, $text{'index_a_dhcp'}, $text{'index_a_static'}));
$rv .= ui_table_row($text{'index_a_gateway'}, ui_textbox('gateway', '', 20));
$rv .= ui_table_row($text{'index_a_dns'}, ui_textarea('dns', "", 3, 40));
$rv .= ui_hidden_table_end('network');

$rv .= ui_hidden_table_start($text{'index_a_limits'}, 'width=100%', 2, 'limits', 1);
$rv .= ui_table_row($text{'index_a_memory'}, ui_bytesbox('memory', 2147483648));
$rv .= ui_table_row($text{'index_a_cpus'},
	ui_opt_textbox('cpus', '', 6, $text{'index_a_nolimit'}, $text{'index_a_limit_to'}));
$rv .= ui_table_row($text{'index_a_pids'},
	ui_opt_textbox('pids', '', 6, $text{'index_a_nolimit'}, $text{'index_a_limit_to'}));
$rv .= ui_hidden_table_end('limits');

$rv .= ui_hidden_table_start($text{'index_a_security'}, 'width=100%', 2, 'security', 0);
$rv .= ui_table_row($text{'index_a_readonly'},
	ui_toggle({ 'name' => 'readonly', 'label' => $text{'index_a_readonly_label'} }));
$rv .= ui_table_row($text{'index_a_privileged'}, ui_yesno_radio('privileged', 0));
$rv .= ui_table_row($text{'index_a_caps'}, ui_textbox('caps', '', 40));
$rv .= ui_hidden_table_end('security');

$rv .= ui_form_end([ [ undef, $text{'save'} ] ]);
return $rv;
}

# demo_tables_tab()
# Returns the tables panel : a sortable table, and a table with a
# checkbox column, select-all links and buttons acting on the selection
sub demo_tables_tab
{
my $rv = "";

# Empty state in place of a table with no rows
$rv .= ui_card({
	'title' => $text{'index_t_empty'},
	'flush' => 1,
	'body' => ui_empty_state({
		'icon' => 'clock',
		'title' => $text{'index_t_empty_title'},
		'desc' => $text{'index_t_empty_desc'},
		'actions' => ui_link_button('index.cgi', $text{'index_t_create'}),
		}),
	});
my @rows = (
	[ 'webmin.service', 'Webmin administration server',
	  $text{'index_running'}, '0.8%' ],
	[ 'sshd.service', 'OpenSSH server daemon',
	  $text{'index_running'}, '0.1%' ],
	[ 'httpd.service', 'The Apache HTTP Server',
	  $text{'index_failed'}, '0.0%' ],
	[ 'postfix.service', 'Postfix Mail Transport Agent',
	  $text{'index_running'}, '0.4%' ],
	[ 'firewalld.service', 'Firewall daemon with D-Bus interface',
	  $text{'index_stopped'}, '0.0%' ],
	[ 'mariadb.service', 'MariaDB database server',
	  $text{'index_running'}, '11.2%' ],
	);
my @heads = ( $text{'index_t_unit'}, $text{'index_t_desc'},
	      $text{'index_t_state'}, $text{'index_t_cpu'} );

# A standard column table with its sortable flag set, so that themes
# which support it add client-side sorting and searching
# The unit cell is a ui_details disclosure : the unit name is the
# summary, and the tick next to it opens compact details inside the cell,
# as the GRUB 2 module shows boot entry metadata. The classes inline and
# inlined keep the summary on one line with the tick. With html set the
# title and content are used as given, so they are escaped here.
my $n = 0;
my @detail_rows = map {
	my ($unit, @rest) = @$_;
	$n++;
	[ ui_details({
		'html' => 1,
		'title' => html_escape($unit),
		'content' => join("<br>",
			$text{'index_t_d_pid'}.": ".ui_tag('tt', 1000 + $n * 111),
			$text{'index_t_d_since'}.": 2026-09-0$n 08:1$n",
			$text{'index_t_d_mem'}.": ".($n * 17).".4 MB"),
		'class' => 'inline inlined' }),
	  map { html_escape($_) } @rest ];
	} @rows;
$rv .= ui_columns_table(\@heads, 100, \@detail_rows,
	undef, 0, $text{'index_t_sortable'}, undef, 1);
$rv .= ui_note($text{'index_t_sortable_desc'});

# The same data with a checkbox column, select links and buttons, as
# ui_form_columns_table builds it, also flagged as sortable. Failed units
# start out checked. The select links need the index of this form on the
# page, counted in document order : service card 0, edit form 1, choosers
# 2, choices 3, then on the Buttons tab the single buttons 4, form end 5,
# grouped buttons 6, its hidden logs form 7, side by side 8 and its right
# form 9, confirmation 10, then accordions 11, so this one is 12.
# The otherlinks argument adds links to the row of
# select links, on the left by default or on the right when the third
# element is "right", as the Users and Groups module places its "Create a
# new user" and "Run batch file" links.
$rv .= ui_hr();
$rv .= ui_form_columns_table('index.cgi',
	[ [ 'restart', $text{'index_restart'} ], [ 'stop', $text{'index_stop'} ] ],
	1,
	[ [ 'index.cgi?mode=tables', $text{'index_t_new'} ],
	  [ 'index.cgi?mode=tables', $text{'index_t_batch'}, 'right' ],
	  [ 'index.cgi?mode=tables', $text{'index_t_export'}, 'right' ] ],
	[ [ 'demo', 5 ] ],
	[ '', @heads ], 100,
	[ map { [
		{ 'type' => 'checkbox', 'name' => 'unit', 'value' => $_->[0],
		  'checked' => $_->[2] eq $text{'index_failed'} ? 1 : 0 },
		map { html_escape($_) } @$_,
		] } @rows ],
	undef, 0, undef, undef, 12, 1);
$rv .= ui_tag('div', ui_note($text{'index_t_checked_desc'}),
	      { 'style' => 'margin-top: 6px' });

return $rv;
}

# demo_lists_tab()
# Returns the lists panel of the gallery
sub demo_lists_tab
{
my $rv = "";

# List rows with descriptions, chips and trailing actions
$rv .= ui_card({
	'title' => $text{'index_l_title'},
	'desc' => $text{'index_l_desc'},
	'flush' => 1,
	'body' => ui_list([
		{ 'title' => 'apache-auth',
		  'href' => 'index.cgi',
		  'desc' => '0 failures, 0 bans — 5 tries in 10 minutes',
		  'meta' => '2 '.$text{'index_feed_hours'},
		  'actions' => ui_link('index.cgi',
				       html_escape($text{'index_edit'})) },
		{ 'title' => 'sshd',
		  'href' => 'index.cgi',
		  'badge' => [ '3 '.$text{'index_l_bans'}, 'warning' ],
		  'desc' => '14 failures — 5 tries in 10 minutes',
		  'tags' => [ 'journal' ],
		  'meta' => '10 '.$text{'index_feed_minutes'},
		  'actions' => ui_link('index.cgi',
				       html_escape($text{'index_edit'})) },
		{ 'title' => 'webmin',
		  'href' => 'index.cgi',
		  'icon' => 'shield',
		  'state' => 'success',
		  'desc' => '0 failures, 0 bans — then blocked for 1 hour',
		  'tags' => [ 'journal', 'ipv6' ],
		  'meta' => '1 '.$text{'index_feed_hours'} },
		], { 'flush' => 1 }),
	});


# Three more uses of ui_list side by side : a history with a state icon
# and colored badge per entry and link buttons as actions; a resource
# list whose description line is an inline progress bar; and a record
# list with a confirmed delete link, which asks through the data-ui-confirm
# attribute handled by ui-lib.js on any element
$rv .= ui_grid([
	ui_card({
		'title' => $text{'index_l_backups'},
		'flush' => 1,
		'body' => ui_list([
			{ 'title' => 'Full backup, 2026-09-04 02:00',
			  'icon' => 'check-circle', 'state' => 'success',
			  'desc' => text('index_l_backup_desc', 12, '/backup'),
			  'meta' => '1.2 GB',
			  'actions' => ui_link_button('index.cgi',
						      $text{'index_l_restore'}) },
			{ 'title' => 'Full backup, 2026-09-03 02:00',
			  'icon' => 'x-circle', 'state' => 'danger',
			  'badge' => [ $text{'index_l_failed'}, 'danger' ],
			  'desc' => $text{'index_l_backup_failed'},
			  'meta' => '0 B',
			  'actions' => ui_link_button('index.cgi',
						      $text{'index_l_log'}) },
			{ 'title' => 'Incremental, 2026-09-02 02:00',
			  'icon' => 'check-circle', 'state' => 'success',
			  'desc' => text('index_l_backup_desc', 12, '/backup'),
			  'meta' => '140 MB',
			  'actions' => ui_link_button('index.cgi',
						      $text{'index_l_restore'}) },
			], { 'flush' => 1 }),
		}),
	ui_card({
		'title' => $text{'index_l_fs'},
		'flush' => 1,
		'body' => ui_list([ map { {
			'title' => $_->[0],
			'desc_html' => ui_progress($_->[1], {
				'inline' => 1, 'thresholds' => 1,
				'value' => $_->[2] }),
			'tags' => [ $_->[3] ],
			'meta' => $_->[4],
			} } ( [ '/', 63, '63 GB of 100 GB', 'nvme0n1p2', 'xfs' ],
			      [ '/home', 91, '455 GB of 500 GB', 'nvme0n1p3', 'xfs' ],
			      [ '/var/log', 12, '2.4 GB of 20 GB', 'sda1', 'ext4' ] ) ],
			{ 'flush' => 1 }),
		}),
	ui_card({
		'title' => $text{'index_l_users'},
		'flush' => 1,
		'body' => ui_list([
			{ 'title' => 'root', 'icon' => 'user',
			  'badge' => [ $text{'index_l_admin'}, 'info' ],
			  'desc' => text('index_l_lastlogin', '2 '.$text{'index_feed_hours'}),
			  'actions' => ui_link('index.cgi', $text{'index_edit'}) },
			{ 'title' => 'backup', 'icon' => 'user',
			  'desc' => text('index_l_lastlogin', '3 '.$text{'index_l_days'}),
			  'actions' => ui_link('index.cgi', $text{'index_edit'})." ".
				       ui_link('index.cgi', $text{'index_l_delete'}, undef,
					       "data-ui-confirm='".
					       quote_escape($text{'index_l_delete_confirm'})."'") },
			{ 'title' => 'deploy', 'icon' => 'user',
			  'desc' => text('index_l_lastlogin', $text{'index_l_never'}),
			  'actions' => ui_link('index.cgi', $text{'index_edit'})." ".
				       ui_link('index.cgi', $text{'index_l_delete'}, undef,
					       "data-ui-confirm='".
					       quote_escape($text{'index_l_delete_confirm'})."'") },
			], { 'flush' => 1 }),
		}),
	]);
return $rv;
}

# demo_alerts_tab()
# Returns the alerts panel : the existing ui_alert(text, type, [icon],
# [attrs]) in every type. The type is success, info, warning, danger or
# danger-fatal, and the theme adds the icon and the title that go with
# it. The icon argument may be an icon class from the theme's icon set,
# or [ icon, title, no-break ] to use a custom icon and title and keep
# the message on the same line as the title.
sub demo_alerts_tab
{
my $rv = "";
$rv .= ui_alert($text{'index_al_success'}, 'success');
$rv .= ui_alert($text{'index_al_info'}, 'info');
$rv .= ui_alert($text{'index_al_warning'}, 'warning');
$rv .= ui_alert($text{'index_al_danger'}, 'danger');
$rv .= ui_alert($text{'index_al_inline'}, 'info',
		[ 'fa-clock', $text{'index_al_inline_title'}, 1 ]);

# More one-line alerts of every type, each with an icon from the theme's
# set that fits the message
$rv .= ui_alert($text{'index_al_backup'}, 'success',
		[ 'fa-hdd-o', $text{'index_al_backup_title'}, 1 ]);
$rv .= ui_alert($text{'index_al_cert'}, 'warning',
		[ 'fa-lock', $text{'index_al_cert_title'}, 1 ]);
$rv .= ui_alert($text{'index_al_db'}, 'danger',
		[ 'fa-plug', $text{'index_al_db_title'}, 1 ]);

# A custom icon with the default title, and a custom title with the
# default icon, both on two lines as usual
$rv .= ui_alert($text{'index_al_update'}, 'info', 'fa-download');
$rv .= ui_alert($text{'index_al_reboot'}, 'warning',
		[ undef, $text{'index_al_reboot_title'} ]);

# The full text of an error goes in a ui_details box with the error
# class, opened by the second argument, as the MariaDB module shows its
# connection error under its alert. It is placed last here because it
# sits flush against whatever follows it.
$rv .= ui_details({
	'html' => 1,
	'title' => html_escape($text{'index_al_errdetails'}),
	'content' => text('index_al_errmsg',
		ui_tag('tt', html_escape("DBI connect failed : Can't connect to ".
				      "local server through socket ".
				      "'/var/lib/mysql/mysql.sock' (2)"))),
	'class' => 'error' }, 1);
return $rv;
}

# demo_config_files()
# Returns the sample files the editor page offers
sub demo_config_files
{
return ( '/etc/example/service.conf',
	 '/etc/example/rules.conf',
	 '/etc/example/limits.conf' );
}

# demo_config_contents(file)
# Returns generated contents for one of the sample files
sub demo_config_contents
{
my ($file) = @_;
return join("\n", "# ".$file, "# ".$text{'index_e_sample'}, "",
	    "listen = 0.0.0.0:10000", "ssl = 1",
	    "max_connections = 50", "log_level = info", "");
}

# demo_editor_tab()
# Returns the panel leading to the manual config editor. The editor is a
# page of its own, edit_manual.cgi, because Authentic only turns a text
# area into a code editor on pages it recognizes by name, and a tab of
# index.cgi is not one of them. The list rows link straight to each file
# in the editor.
sub demo_editor_tab
{
my $rv = "";
$rv .= ui_card({
	'title' => $text{'index_e_files'},
	'flush' => 1,
	'body' => ui_list([ map { {
		'title' => $_,
		'href' => 'edit_manual.cgi?file='.urlize($_),
		'desc' => $text{'index_e_file_desc'},
		'icon' => 'edit',
		} } demo_config_files() ], { 'flush' => 1 }),
	'footer' => ui_link_button('edit_manual.cgi', $text{'index_e_button'}),
	});
return $rv;
}

# demo_iconlinks_tab()
# Returns the icon links panel : a grid of linked icons with titles under
# them, as the grub2 and Webmin Configuration modules show their
# sub-pages. This is the existing icons_table(&links, &titles, &icons,
# columns) function. The icons are small SVG files in the module's images
# directory, 48x48 like those of grub2. icons_table prints rather than
# returns, so its output is captured here.
sub demo_iconlinks_tab
{
my @pages = ( 'cards', 'forms', 'accordions', 'tables', 'lists' );
my $rv = capture_function_output(\&icons_table,
	[ map { "index.cgi?mode=$_" } @pages ],
	[ map { $text{'index_tab_'.$_} } @pages ],
	[ map { "images/$_.svg" } @pages ],
	scalar(@pages));

# Then the bottom-of-page action buttons after a rule, as the SSH Server
# and grub2 modules end their index page : icons first, a rule, then the
# buttons
$rv .= demo_page_actions();
return $rv;
}

# demo_page_actions()
# Returns the block of action buttons that modules such as grub2 and the
# Virtualmin Podman module put at the bottom of their index page, after a
# rule. This is the existing ui_buttons_start, ui_buttons_row and
# ui_buttons_end API, which builds one form per row with the button on
# the left and its description on the right. ui_buttons_row(script,
# label, description, hiddens, after-submit, before-submit, method,
# single-cell) : the after-submit and before-submit slots take extra
# inputs shown next to the button, the way the Webmin Configuration
# module asks whether to start at boot.
#
# Everything here submits back to index.cgi with GET, since the module is
# read-only.
sub demo_page_actions
{
my $rv = "";
$rv .= ui_hr();
$rv .= ui_buttons_start();

# A sentence of controls after the button, the way the Virtualmin Podman
# module offers "Add New [type] named [recipe] for [domain]" and the WP
# Workbench module "Create Scheduled Backup for [domain] every [hour]
# include [files and database]". Three things make it work :
#  - the button and the fields are wrapped in one flex span so they stay
#    aligned and wrap together : the span is opened in the before-submit
#    slot and closed at the end of the after-submit slot;
#  - the words between the fields are plain spans, and each select has an
#    aria-label since those words are not labels;
#  - single-cell is set, so the row has no description column and the
#    sentence can use the full width.
my @types = ( [ 'recipe', $text{'index_b_type_recipe'} ],
	      [ 'container', $text{'index_b_type_container'} ] );
my @recipes = ( [ 'budget', 'Actual Budget' ],
		[ 'wordpress', 'WordPress' ],
		[ 'nextcloud', 'Nextcloud' ] );
my @domains = ( [ 'example.com', 'example.com' ],
		[ 'shop.example.com', '&nbsp;&nbsp;shop.example.com' ],
		[ 'example.net', 'example.net' ] );
my $select_tags = "style='field-sizing:content;'";
my $sentence =
	ui_select('type', 'recipe', \@types, undef, undef, undef, 0,
		  "aria-label='".quote_escape($text{'index_b_type'})."' ".
		  $select_tags).
	ui_tag('span', html_escape($text{'index_b_named'})).
	ui_select('recipe', 'budget', \@recipes, undef, undef, undef, 0,
		  "aria-label='".quote_escape($text{'index_b_recipe'})."' ".
		  $select_tags).
	ui_tag('span', html_escape($text{'index_b_for'})).
	ui_select('dom', 'example.com', \@domains, undef, undef, undef, 0,
		  "aria-label='".quote_escape($text{'index_b_domain'})."' ".
		  $select_tags).
	ui_tag_end('span');
$rv .= ui_buttons_row('index.cgi', $text{'index_b_addnew'}, '',
	ui_hidden('mode', 'iconlinks'),
	$sentence,
	ui_tag_start('span', {
		'style' => 'display:flex;align-items:center;flex-wrap:wrap;'.
			   'gap:.5em;white-space:normal;' }),
	'get', 1);

# A plain action, with a hidden field carrying where to come back to
$rv .= ui_buttons_row('index.cgi', $text{'index_b_refresh'},
	$text{'index_b_refresh_desc'}, ui_hidden('mode', 'iconlinks'),
	undef, undef, 'get');

# A yes/no setting applied by the button
$rv .= ui_buttons_row('index.cgi', $text{'index_b_boot'},
	$text{'index_b_boot_desc'}, ui_hidden('mode', 'iconlinks'),
	ui_yesno_radio('boot', 1), undef, 'get');

$rv .= ui_buttons_end();
return $rv;
}

1;
