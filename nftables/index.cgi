#!/usr/bin/perl
# index.cgi
# Display current nftables configuration

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%in, %text, %config);
ReadParse();
my $can_view_saved = check_acl('view');
if (!$can_view_saved &&
	!check_acl('active') &&
	!check_acl('create') &&
	!check_acl('setup') &&
	!check_manual_acl())
{
	error($text{'acl_ecannot'});
	}
my $partial = $in{'partial'};
if (!$partial) {
	ui_print_header(nft_version_text() || "", 
			$text{'index_title'}, "", "intro", 1, 1,
			undef, restart_button());
	}

# quick_hidden_fields(table-index, &table, selected-view)
# Returns hidden table selectors for quick action forms
sub quick_hidden_fields
{
my ($idx, $table, $view) = @_;
return ui_hidden("table", $idx).
       ui_hidden("table_family", $table->{'family'}).
       ui_hidden("table_name", $table->{'name'}).
       ui_hidden("view", $view);
}

# quick_service_autocomplete()
# Returns the quick service textbox and JavaScript-backed matcher
sub quick_service_autocomplete
{
my $placeholder = quote_escape($text{'quick_service_placeholder'});
my $results_style = "display: none; position: absolute; z-index: 1000; ".
       "left: 0; right: auto; width: 100%; min-width: 0; ".
       "max-height: 18em; overflow: auto; ".
       "border: 1px solid var(--border-color-input-results, ".
       "var(--border-color-input, #3f4855)); ".
       "border-radius: var(--border-radius-input, 3px); ".
       "background-color: var(--bg-color-input, #fff); ".
       "color: var(--text-color, inherit);";
my $results = ui_tag('div', undef, {
	'id' => 'nftables_quick_service_results',
	'role' => 'listbox',
	'style' => $results_style,
});
my $input = ui_textbox(
	       "service_text",
	       "",
	       32,
	       undef,
	       undef,
	       "autocomplete='off' placeholder='".$placeholder."'"
       );
my $wrap = ui_tag('span', $input.$results, {
	'id' => 'nftables_quick_service_wrap',
	'style' => 'position: relative; display: inline-block; max-width: 100%;',
});
return ui_hidden("service", "").
       $wrap.
       quick_service_autocomplete_javascript();
}

# quick_service_autocomplete_javascript()
# Returns JavaScript for the quick service autocomplete widget
sub quick_service_autocomplete_javascript
{
my $labels = convert_to_json({
	'no_matches' => $text{'quick_service_nomatch'},
	'failed' => $text{'quick_service_searchfail'},
});
my $js = <<EOF;
(function() {
var labels = $labels;
if (!window.fetch) {
	return;
}
var mode = document.querySelector('form[action="manage_port.cgi"] input[name="mode"][value="service"]');
if (!mode || !mode.form) {
	return;
}
var form = mode.form;
var input = form.querySelector('input[name="service_text"]');
var hidden = form.querySelector('input[name="service"]');
var box = document.getElementById('nftables_quick_service_results');
if (!input || !hidden || !box) {
	return;
}
var timer = null;
var serial = 0;
var currentQuery = "";
var results = [];
var active = -1;

function trim(value) {
	return (value || "").replace(/^\\s+|\\s+\$/g, "");
}

function showBox() {
	placeBox();
	box.style.display = "block";
}

function hideBox() {
	box.style.display = "none";
	box.textContent = "";
	results = [];
	active = -1;
}

function placeBox() {
	var rect = input.getBoundingClientRect();
	var below = window.innerHeight - rect.bottom;
	var above = rect.top;
	box.style.width = input.offsetWidth + "px";
	var preferred = Math.min(box.scrollHeight || 288, 288);
	if (below < preferred && above >= preferred) {
		box.style.top = "auto";
		box.style.bottom = (input.offsetHeight + 2) + "px";
	}
	else {
		box.style.top = (input.offsetHeight + 2) + "px";
		box.style.bottom = "auto";
	}
}

function styleRow(row, selected) {
	row.style.padding = "0.25em 0.45em";
	row.style.cursor = "pointer";
	row.style.whiteSpace = "nowrap";
	row.style.overflow = "hidden";
	row.style.textOverflow = "ellipsis";
	row.style.borderTop = "1px solid var(--border-color-input-results, #3f4855)";
	row.style.backgroundColor = selected ?
		"var(--bg-color-input-results-hover, rgba(127,127,127,0.16))" :
		"";
}

function setActive(index) {
	active = index;
	var rows = box.querySelectorAll('[data-service-id]');
	for (var i = 0; i < rows.length; i++) {
		styleRow(rows[i], i === active);
	}
	var row = rows[active];
	if (row) {
		var top = row.offsetTop;
		var bottom = top + row.offsetHeight;
		if (top < box.scrollTop) {
			box.scrollTop = top;
		}
		else if (bottom > box.scrollTop + box.clientHeight) {
			box.scrollTop = bottom - box.clientHeight;
		}
	}
}

function choose(item) {
	if (!item) {
		return;
	}
	hidden.value = item.id || "";
	input.value = item.label || item.id || "";
	hideBox();
}

function message(text) {
	box.textContent = "";
	var row = document.createElement("div");
	row.textContent = text;
	row.style.padding = "0.25em 0.45em";
	row.style.fontStyle = "italic";
	box.appendChild(row);
	results = [];
	active = -1;
	showBox();
}

function draw(items, query) {
	box.textContent = "";
	results = items || [];
	if (!results.length) {
		if (query) {
			message(labels.no_matches);
		}
		else {
			hideBox();
		}
		return;
	}
	results.forEach(function(item, index) {
		var row = document.createElement("div");
		row.setAttribute("role", "option");
		row.setAttribute("data-service-id", item.id || "");
		row.textContent = item.label || item.id || "";
		styleRow(row, false);
		row.addEventListener("mousedown", function(event) {
			event.preventDefault();
			choose(item);
		});
		row.addEventListener("mousemove", function() {
			setActive(index);
		});
		box.appendChild(row);
	});
	showBox();
	setActive(0);
}

function search() {
	var query = trim(input.value);
	currentQuery = query;
	if (!query) {
		hideBox();
		return;
	}
	var mySerial = ++serial;
	fetch("search_services.cgi?q=" + encodeURIComponent(query) + "&limit=20", {
		credentials: "same-origin"
	}).then(function(response) {
		if (!response.ok) {
			throw new Error("service search failed");
		}
		return response.json();
	}).then(function(items) {
		if (mySerial !== serial || query !== currentQuery) {
			return;
		}
		draw(items, query);
	}).catch(function() {
		if (mySerial === serial) {
			message(labels.failed);
		}
	});
}

input.addEventListener("input", function() {
	hidden.value = "";
	if (timer) {
		clearTimeout(timer);
	}
	timer = setTimeout(search, 200);
});

input.addEventListener("focus", function() {
	if (trim(input.value) && !hidden.value) {
		search();
	}
});

input.addEventListener("keydown", function(event) {
	var open = box.style.display !== "none";
	if (!open) {
		return;
	}
	if (event.key === "ArrowDown") {
		event.preventDefault();
		if (results.length) {
			setActive((active + 1) % results.length);
		}
	}
	else if (event.key === "ArrowUp") {
		event.preventDefault();
		if (results.length) {
			setActive((active + results.length - 1) % results.length);
		}
	}
	else if (event.key === "Enter" && active >= 0 && results[active]) {
		event.preventDefault();
		choose(results[active]);
	}
	else if (event.key === "Escape") {
		hideBox();
	}
});

form.addEventListener("submit", function() {
	if (!hidden.value) {
		hidden.value = trim(input.value);
	}
});

document.addEventListener("mousedown", function(event) {
	var wrap = document.getElementById("nftables_quick_service_wrap");
	if (wrap && !wrap.contains(event.target)) {
		hideBox();
	}
});

window.addEventListener("resize", function() {
	if (box.style.display !== "none") {
		placeBox();
	}
});

window.addEventListener("scroll", function() {
	if (box.style.display !== "none") {
		placeBox();
	}
}, true);
})();
EOF
return ui_tag('script', $js, {
	'type' => 'text/javascript',
});
}

# Check for nft command
my $cmd = get_nft_command();
if (!$cmd) {
	print text('index_ecommand', "<tt>nft</tt>");
	if (!$partial) {
		ui_print_footer("/", $text{'index'});
		}
	exit;
	}

if (!$partial) {
	my @foreign_firewalls = list_foreign_firewall_modules();
	if (@foreign_firewalls) {
		my @names;
		foreach my $fw (@foreign_firewalls) {
			my $name = html_escape($fw->{'desc'});
			push(@names, ui_tag('strong', $name));
			}
		print ui_alert_box(
			text('index_foreign_firewalls', trim(join(", ", @names))),
			'warn', undef, undef, "");
		}
	}

# Load tables
my @tables = $can_view_saved ? get_nftables_save() : ();
@tables = grep { check_table_acl($_) } @tables;
my $rules_html = "";

if (!@tables) {
	$rules_html .= ui_buttons_start();
	$rules_html .= ui_buttons_row(
		"setup.cgi",
		$text{'index_profile_setup'},
		$text{'index_profile_setupdesc'}
	) if (check_acl('setup'));
	$rules_html .= ui_buttons_row(
		"create_table.cgi",
		$text{'index_table_create'},
		$text{'index_table_createdesc'}
	) if (check_acl('create'));
	$rules_html .= ui_buttons_row(
		"active.cgi",
		$text{'index_ruleset_active'},
		$text{'index_ruleset_activedesc'}
	) if (check_acl('active'));
	$rules_html .= ui_buttons_row(
		"edit_manual.cgi",
		$text{'index_edit_manual'},
		$text{'index_edit_manualdesc'}
	) if (check_manual_acl());
	$rules_html .= ui_buttons_end();
	}
else {
	# Select table
	my $found_table;
	if (defined($in{'table_family'}) && defined($in{'table_name'})) {
		for (my $i = 0 ; $i <= $#tables ; $i++) {
			if ($tables[$i]->{'family'} eq $in{'table_family'} &&
				$tables[$i]->{'name'} eq $in{'table_name'})
			{
				$in{'table'} = $i;
				$found_table = 1;
				last;
				}
			}
		}
	if (
		!$found_table &&
		(!defined($in{'table'}) ||
			$in{'table'} !~ /^\d+$/ ||
			$in{'table'} > $#tables)
	    )
	{
		$in{'table'} = 0;
		}
	my @table_opts;
	for (my $i = 0 ; $i <= $#tables ; $i++) {
		my $t = $tables[$i];
		push(@table_opts, [$i, $t->{'family'}." ".$t->{'name'}]);
		}

	if (!$partial) {
		print ui_form_start("index.cgi");
		print "<div class='nftables_table_select'>\n";
		print text('index_change'), "&nbsp;&nbsp;";
		print ui_select("table", $in{'table'}, \@table_opts, 1, 0, 1, 0,
			"onchange='this.form.querySelector(\"[name=nft_submit]\").click()'"
		);
		print ui_submit("", "nft_submit", 0, "style='display:none'");
		print " ",
		    ui_link_button("create_table.cgi", $text{'index_table_create'})
		    if (check_acl('create'));
		print " ",
		    ui_link_button(
			"delete_table.cgi?table=$in{'table'}&table_family=".
			    urlize(
				$tables[$in{'table'}]->{'family'}
			    ).
			    "&table_name=".
			    urlize($tables[$in{'table'}]->{'name'}),
			$text{'index_table_delete'}
		    ) if (check_acl('delete'));
		print "</div>\n";
		print ui_form_end();
		}

	# Identify current table
	my $curr = $tables[$in{'table'}];

	if ($curr) {
		my ($sets_html, $chains_html);

		# Show sets
		$sets_html .= ui_form_start("delete_sets.cgi", "post");
		$sets_html .= ui_hidden("table", $in{'table'});
		$sets_html .= ui_hidden("table_family", $curr->{'family'});
		$sets_html .= ui_hidden("table_name", $curr->{'name'});
		my $set_form = $partial ? 1 : 2;
		my $has_sets = $curr->{'sets'} &&
		    ref($curr->{'sets'}) eq 'HASH' &&
		    keys(%{$curr->{'sets'}});
		my @set_select_links = $has_sets && check_acl('delete')
		    ? (
			select_all_link("s", $set_form),
			select_invert_link("s", $set_form)
		    )
		    : ();
		my @set_top_links = @set_select_links;
		push(
			@set_top_links,
			ui_link(
				"edit_set.cgi?table=$in{'table'}&new=1",
				$text{'index_set_create'}
			)
		) if (check_acl('sets'));
		$sets_html .= ui_links_row(\@set_top_links);
		my @set_tds = ("width=5");
		$sets_html .= ui_columns_start(
			[
				"",
				$text{'index_set_name'},
				$text{'index_set_type'},
				$text{'index_set_flags'},
				$text{'index_set_elements'},
				$text{'index_set_actions'}
			],
			100, 0,
			\@set_tds
		);

		if ($has_sets) {
			foreach my $s (sort keys %{$curr->{'sets'}}) {
				my $set = $curr->{'sets'}->{$s} || {};
				my $actions_html = check_acl('sets')
				    ? ui_link(
					"edit_set.cgi?table=$in{'table'}&set=".
					    urlize(
						$s),
					$text{'index_set_edit'}
				    )
				    : "-";
				my @cols = (
					$s,
					$set->{'type'} || "-",
					$set->{'flags'} || "-",
					set_elements_summary($set),
					$actions_html
				);
				$sets_html .=
				      check_acl('delete')
				    ? ui_checked_columns_row(\@cols, \@set_tds, "s", $s)
				    : ui_columns_row(["", @cols]);
				}
			}
		$sets_html .= ui_columns_end();
		$sets_html .=
		    @set_select_links
		    ? ui_form_end([[undef, $text{'index_set_deletesel'}]])
		    : ui_form_end();

		# Show chains and rules
		$chains_html .= ui_form_start("delete_chains.cgi", "post", undef,
			"id='nftables_chains_form'");
		$chains_html .= ui_hidden("table", $in{'table'});
		$chains_html .= ui_hidden("table_family", $curr->{'family'});
		$chains_html .= ui_hidden("table_name", $curr->{'name'});
		my $chain_form = $partial ? 0 : 1;
		my @chain_select_links =
		    keys(%{$curr->{'chains'}}) && check_acl('delete')
		    ? (
			select_all_link("d", $chain_form),
			select_invert_link("d", $chain_form)
		    )
		    : ();
		my @chain_top_links = @chain_select_links;
		push(
			@chain_top_links,
			ui_link(
				"edit_chain.cgi?table=$in{'table'}&new=1",
				$text{'index_chain_create'}
			)
		) if (check_acl('chains'));
		$chains_html .= ui_links_row(\@chain_top_links);
		my @chain_tds = ("width=5");
		$chains_html .= ui_columns_start(
			[
				"", $text{'index_chain_col'},
				$text{'index_type'}, $text{'index_hook'},
				$text{'index_priority'}, $text{'index_policy_col'},
				$text{'index_rules'}, $text{'index_actions'}
			],
			100, 0,
			\@chain_tds
		);

		foreach my $c (sort keys %{$curr->{'chains'}}) {
			my $chain_def = $curr->{'chains'}->{$c} || {};
			my $policy = $chain_def->{'policy'};
			my $policy_label =
			    $policy
			    ? ($text{'index_policy_'.lc($policy)} || uc($policy))
			    : "-";
			my @rules = grep { $_->{'chain'} eq $c } @{$curr->{'rules'}};
			my $rules_html_row;
			if (@rules) {
				my $ri = 0;
				$rules_html_row = ui_tag_start(
					'table',
					{
						'class' => 'nftables_rules_table',
						'width' => '100%',
						'cellspacing' => 0,
						'cellpadding' => 0
					}
				);
				foreach my $r (@rules) {
					my $desc = describe_rule($r);
					my $rule_url =
					    "edit_rule.cgi?table=$in{'table'}&chain=".
					    urlize($c).
					    "&idx=$r->{'index'}";
					my $rule_link =
					      check_acl('rules')
					    ? ui_tag('a', $desc, {'href' => $rule_url})
					    : $desc;
					my $imgdir = "@{[get_webprefix()]}/images";
					my $up_url =
					    "move_rule.cgi?table=$in{'table'}&chain=".
					    urlize($c).
					    "&idx=$r->{'index'}&dir=up";
					my $down_url =
					    "move_rule.cgi?table=$in{'table'}&chain=".
					    urlize($c).
					    "&idx=$r->{'index'}&dir=down";
					my $down_move =
					    check_acl('rules') &&
					    $ri < $#rules
					    ? ui_tag(
						'a',
						ui_tag(
							'img', undef,
							{
								'class' =>
								    'ui_up_down_arrows_down',
								'src' =>
								    "$imgdir/movedown.gif",
								'border' => 0
							}
						),
						{
							'class' =>
							    'ui_up_down_arrows_down',
							'href' => $down_url
						}
					    )
					    : ui_tag(
						'img', undef,
						{
							'class' =>
							    'ui_up_down_arrows_gap',
							'src' => "$imgdir/movegap.gif"
						}
					    );
					my $up_move =
					    check_acl('rules') && $ri > 0
					    ? ui_tag(
						'a',
						ui_tag(
							'img', undef,
							{
								'class' =>
								    'ui_up_down_arrows_up',
								'src' =>
								    "$imgdir/moveup.gif",
								'border' => 0
							}
						),
						{
							'class' =>
							    'ui_up_down_arrows_up',
							'href' => $up_url
						}
					    )
					    : ui_tag(
						'img', undef,
						{
							'class' =>
							    'ui_up_down_arrows_gap',
							'src' => "$imgdir/movegap.gif"
						}
					    );
					$rules_html_row .= ui_tag_start('tr');
					$rules_html_row .= ui_tag('td', $rule_link,
						{'class' => 'nftables_rule_text'});
					$rules_html_row .= ui_tag(
						'td',
						$down_move,
						{
							'class' =>
							    'nftables_rule_move_down',
							'width' => 10,
							'style' =>
							    'white-space: nowrap; text-align: center;'
						}
					);
					$rules_html_row .= ui_tag(
						'td', $up_move,
						{
							'class' =>
							    'nftables_rule_move_up',
							'width' => 10,
							'style' =>
							    'white-space: nowrap; text-align: center;'
						}
					);
					$rules_html_row .= ui_tag_end('tr');
					$ri++;
					}
				$rules_html_row .= ui_tag_end('table');
				}
			else {
				$rules_html_row =
				    ui_tag('i', $text{'index_rules_none'});
				}

			my @actions;
			if (check_acl('chains')) {
				push(
					@actions,
					ui_link(
						"edit_chain.cgi?table=$in{'table'}&chain="
						    .
						    urlize(
							$c),
						$text{'index_cedit'}
					)
				);
				push(
					@actions,
					ui_link(
						"rename_chain.cgi?table=$in{'table'}&chain="
						    .
						    urlize(
							$c),
						$text{'index_crename'}
					)
				);
				}
			push(
				@actions,
				ui_link(
					"edit_rule.cgi?table=$in{'table'}&chain=".
					    urlize(
						$c).
					    "&new=1",
					$text{'index_radd'}
				)
			) if (check_acl('rules'));
			my $actions_html = @actions ? join(" | ", @actions) : "-";
			my @cols = (
				$c,
				$chain_def->{'type'} || "-",
				$chain_def->{'hook'} || "-",
				defined($chain_def->{'priority'})
				? $chain_def->{'priority'}
				: "-",
				$policy_label,
				$rules_html_row,
				$actions_html
			);
			$chains_html .=
			      check_acl('delete')
			    ? ui_checked_columns_row(\@cols, \@chain_tds, "d", $c)
			    : ui_columns_row(["", @cols]);
			}
		$chains_html .= ui_columns_end();
		$chains_html .=
		    @chain_select_links
		    ? ui_form_end([[undef, $text{'index_cdeletesel'}]])
		    : ui_form_end();

		my @tabs = (['chains', $text{'index_tab_chains'}]);
		push(@tabs, ['sets', $text{'index_tab_sets'}]) if (check_acl('sets'));
		my $tab =
		    check_acl('sets') &&
		    $in{'view'} &&
		    $in{'view'} eq 'sets' ? 'sets' : 'chains';
		$rules_html .= ui_hr();
		$rules_html .= ui_tabs_start(\@tabs, "view", $tab, 1);
		$rules_html .= ui_tabs_start_tab("view", "chains");
		$rules_html .= $chains_html;
		$rules_html .= ui_tabs_end_tab();

		if (check_acl('sets')) {
			$rules_html .= ui_tabs_start_tab("view", "sets");
			$rules_html .= $sets_html;
			$rules_html .= ui_tabs_end_tab();
			}
		$rules_html .= ui_tabs_end(1);

		if (check_quick_acl() && !table_supports_quick_l4($curr)) {
			my @proto_opts = (
				['tcp', 'TCP'],
				['udp', 'UDP'],
			);
			my $has_input_chain = find_input_chain($curr) ? 1 : 0;
			if ($has_input_chain) {
				my $ip_placeholder =
				    text('quick_ip_placeholder', '1.2.3.4', '2001:db8::1/64');
				if (check_quick_acl('ip')) {
					foreach my $action (
						['allow', $text{'index_allowip_go'}],
						['block', $text{'index_blockip_go'}],
					    )
					{
						$rules_html .=
						    "<br>".ui_form_start("manage_ip.cgi", "post");
						$rules_html .= quick_hidden_fields($in{'table'}, $curr, $tab);
						$rules_html .= ui_submit($action->[1], $action->[0]).
						    ui_textbox(
							"ip",
							undef,
							22,
							undef,
							undef,
							"placeholder='".
							    quote_escape($ip_placeholder)."'"
						    );
						$rules_html .= ui_form_end();
						}
					}
				if (check_quick_acl('port')) {
					$rules_html .=
					    "<br>".ui_form_start("manage_port.cgi", "post");
					$rules_html .= quick_hidden_fields($in{'table'}, $curr, $tab);
					$rules_html .= ui_hidden("mode", "port");
					$rules_html .= ui_submit($text{'index_allowport_go'}, "allow_port").
					    ui_textbox(
						"port",
						undef,
						14,
						undef,
						undef,
						"placeholder='".
						    quote_escape($text{'quick_port_placeholder'})."'"
					    ).
					    " ".
					    ui_select("proto", "tcp", \@proto_opts, 1, 0, 1);
					$rules_html .= ui_form_end();
					}

				if (check_quick_acl('service')) {
					$rules_html .=
					    "<br>".ui_form_start("manage_port.cgi", "post");
					$rules_html .= quick_hidden_fields($in{'table'}, $curr, $tab);
					$rules_html .= ui_hidden("mode", "service");
					$rules_html .=
					    ui_submit($text{'index_allowservice_go'},
						    "allow_service").
					    quick_service_autocomplete();
					$rules_html .= ui_form_end();
					}
				}
			if (check_quick_acl('forward')) {
				$rules_html .=
				    "<br>".ui_form_start("manage_forward.cgi", "post");
				$rules_html .= quick_hidden_fields($in{'table'}, $curr, $tab);
				$rules_html .= ui_submit($text{'index_forward_go'}, "forward").
				    ui_textbox(
					"src_port",
					undef,
					10,
					undef,
					undef,
					"placeholder='".quote_escape($text{'quick_forward_src'})."'"
				    ).
				    " ".
				    ui_select("proto", "tcp", \@proto_opts, 1, 0, 1).
				    " ".
				    $text{'quick_forward_to'}.
				    " ".
				    ui_textbox(
					"dst_port",
					undef,
					10,
					undef,
					undef,
					"placeholder='".quote_escape($text{'quick_forward_dst'})."'"
				    ).
				    " ".
				    ui_textbox(
					"dst_addr",
					undef,
					32,
					undef,
					undef,
					"placeholder='".quote_escape($text{'quick_forward_addr'})."'"
				    );
				$rules_html .= ui_form_end();
				}
			}
		}
	}

if ($partial) {
	print $rules_html;
	exit;
	}

print $rules_html;

my $init_support = foreign_check("init") && check_acl('bootup') ? 1 : 0;
if (
	@tables &&
	(check_acl('active') ||
		check_acl('setup') ||
		check_manual_acl() ||
		$init_support)
    )
{
	print ui_hr();
	print ui_buttons_start();
	print ui_buttons_row(
		"active.cgi",
		$text{'index_ruleset_active'},
		$text{'index_ruleset_activedesc'}
	) if (check_acl('active'));
	print ui_buttons_row(
		"setup.cgi",
		$text{'index_profile_setup'},
		$text{'index_profile_setupdesc'}
	) if (check_acl('setup'));
	print ui_buttons_row(
		"edit_manual.cgi",
		$text{'index_edit_manual'},
		$text{'index_edit_manualdesc'}
	) if (check_manual_acl());
	print ui_buttons_row("bootup.cgi", $text{'index_bootup'},
		$text{'index_bootupdesc'},
		undef, ui_yesno_radio("boot", nftables_started_at_boot()))
	    if ($init_support);
	print ui_buttons_end();
	}

ui_print_footer("/", $text{'index'});
