/*
 * ui-lib.js
 * Behavior for the widgets added to ui-lib.pl.
 *
 * Everything is wired through delegated event listeners keyed off
 * data-ui-* attributes, so no inline handlers are generated and pages
 * remain compatible with a strict Content-Security-Policy. Tabs, sorting
 * and select-all links keep using the scripts the existing ui-lib
 * functions and themes already provide.
 */
(function () {
	'use strict';

	// Replace old listeners when Ajax navigation reloads this script.
	if (window.webminUiWidgets) window.webminUiWidgets.remove();
	var listeners = [];
	function on(type, fn, capture, target) {
		target = target || document;
		target.addEventListener(type, fn, capture);
		listeners.push([ type, fn, capture, target ]);
	}
	window.webminUiWidgets = {
		remove: function () {
			listeners.forEach(function (l) {
				l[3].removeEventListener(l[0], l[1], l[2]);
			});
		}
	};

	// Filter table rows or list entries in the target container by the
	// text typed into a ui_search box, leaving header rows in place
	function applyFilter(input) {
		var sel = input.getAttribute('data-ui-filter');
		var target = sel && document.querySelector(sel);
		if (!target) return;
		var query = input.value.trim().toLowerCase();
		var items = target.querySelectorAll(
			'tbody tr, .ui_list_item, [data-ui-filter-item]');
		items.forEach(function (item) {
			if (item.classList.contains('ui_columns_heads') ||
			    item.classList.contains('ui_columns_heading')) return;
			item.hidden = query !== '' &&
				item.textContent.toLowerCase().indexOf(query) < 0;
		});
	}

	// Confirmation prompts on buttons and links carrying data-ui-confirm,
	// including existing ui_submit buttons given the attribute in tags.
	// Capture the click before a theme or inline handler performs the action.
	on('click', function (e) {
		var confirmer = e.target.closest && e.target.closest('[data-ui-confirm]');
		if (confirmer &&
		    !window.confirm(confirmer.getAttribute('data-ui-confirm'))) {
			e.preventDefault();
			e.stopImmediatePropagation();
		}
	}, true);

	on('input', function (e) {
		var input = e.target.closest && e.target.closest('[data-ui-filter]');
		if (input) applyFilter(input);
	});
	// Choice lists : focusing an input of an option selects that option,
	// as the existing ui_opt_textbox does
	on('focusin', function (e) {
		// Links, help buttons and other focusable content do not change the
		// selected option; only focusing one of its editable controls does.
		if (!e.target.matches ||
		    !e.target.matches('input:not([type="button"]):not([type="submit"]):not([type="reset"]), select, textarea')) return;
		var item = e.target.closest && e.target.closest('.ui_choice_item');
		if (!item) return;
		var input = item.querySelector('input[type="radio"]');
		if (input && e.target !== input && !input.checked && !input.disabled) {
			input.checked = true;
			input.dispatchEvent(new Event('change', { bubbles: true }));
		}
	});

	// Select switches : show the block of the chosen option, hide the rest
	function applySwitch(select) {
		var box = select.closest('.ui_select_switch');
		if (!box) return;
		box.querySelectorAll('.ui_select_switch_panel').forEach(function (panel) {
			// Nested switches manage their own panels independently.
			if (panel.closest('.ui_select_switch') !== box) return;
			panel.hidden =
				panel.getAttribute('data-ui-switch-value') !== select.value;
		});
	}
	on('change', function (e) {
		var select = e.target;
		if (select.matches && select.matches('select[data-ui-switch]')) {
			applySwitch(select);
		}
	});

	// Native reset restores select values after the reset event, without
	// firing change. Update the panels once those values have been restored.
	on('reset', function (e) {
		window.setTimeout(function () {
			if (e.defaultPrevented) return;
			document.querySelectorAll('select[data-ui-switch]').forEach(function (select) {
				if (select.form === e.target) applySwitch(select);
			});
		}, 0);
	});

	// Multiple selection lists submit newline-joined values in a hidden input.
	var multiAnchors = new WeakMap();
	// Find the checkbox inside any theme wrapper.
	function multiInput(item) {
		return item.querySelector('input[type="checkbox"]');
	}
	// Closing clears the query and returns focus to the button.
	function openMultiFilter(box, open) {
		var filter = box.querySelector('.ui_multi_filter');
		var search = box.querySelector('[data-ui-multi-search]');
		if (!filter || !search || search.disabled) return;
		filter.classList.toggle('ui_multi_filter_open', open);
		if (!open) search.value = '';
		applyMulti(box);
		(open ? search : filter.querySelector('.ui_multi_filter_toggle')).focus();
	}
	function applyMulti(box, reset) {
		// Resets and history restores need not fire change events.
		var mode = box.querySelector('.ui_multi_modes select, .ui_multi_modes input[type="radio"]:checked');
		var body = box.querySelector('.ui_multi_body');
		var hide = JSON.parse(box.getAttribute('data-ui-multi-hide') || '[]');
		if (body) body.hidden = !!mode && hide.indexOf(mode.value) >= 0;
		var search = box.querySelector('[data-ui-multi-search]');
		var query = search ? search.value.trim().toLowerCase() : '';
		// Reopen restored searches.
		var filter = box.querySelector('.ui_multi_filter');
		if (filter) {
			if (query) filter.classList.add('ui_multi_filter_open');
			filter.classList.toggle('ui_multi_filter_active', query !== '');
			filter.querySelector('.ui_multi_filter_toggle').setAttribute('aria-expanded',
				String(filter.classList.contains('ui_multi_filter_open')));
		}
		var fold = box.querySelector('[data-ui-multi-action="children"]');
		var folded = !!(fold && fold.checked);
		var matched = 0;
		var chosen = [];
		var selectedCount = 0;
		box.querySelectorAll('.ui_multi_item').forEach(function (item) {
			var input = multiInput(item);
			if (input && input.checked) chosen.push(input.value);
			// Show child counts only while folded.
			var note = item.querySelector('.ui_multi_note');
			if (note) note.hidden = !folded;
			// The parent covers folded children.
			if (folded && item.getAttribute('data-ui-multi-level')) {
				item.hidden = true;
				return;
			}
			// Retain folded selections, but count only unfolded entries.
			if (input && input.checked) selectedCount++;
			var match = query === '' ||
				(item.getAttribute('data-ui-multi-text') || '').toLowerCase().indexOf(query) >= 0;
			if (match) matched++;
			item.hidden = !match;
		});
		var empty = box.querySelector('.ui_multi_empty');
		if (empty) empty.hidden = matched > 0;
		// Hide the count for empty selections or hidden lists.
		var count = box.querySelector('.ui_multi_count');
		if (count) {
			count.textContent = box.getAttribute('data-ui-multi-text-selected')
				.replace('$1', selectedCount);
			count.hidden = selectedCount === 0 || !!(body && body.hidden);
		}
		var name = box.getAttribute('data-ui-multi');
		box.querySelectorAll('input[type="hidden"]').forEach(function (hidden) {
			if (hidden.name !== name) return;
			var order = box.getAttribute('data-ui-multi-order');
			if (order !== null) {
				// Capture browser-decoded values once, surviving script reinjection.
				if (order === '') {
					order = JSON.stringify(hidden.value.split('\n'));
					box.setAttribute('data-ui-multi-order', order);
				}
				// Retain legacy selection order; newly added entries go first.
				var checked = new Set(chosen);
				var previous = (reset ? JSON.parse(order) : hidden.value.split('\n'))
					.filter(function (value) { return checked.has(value); });
				var retained = new Set(previous);
				var added = chosen.filter(function (value) { return !retained.has(value); });
				hidden.value = added.reverse().concat(previous).join('\n');
			} else {
				hidden.value = chosen.join('\n');
			}
		});
	}
	// Bulk actions affect only visible, enabled rows.
	function eachShownRow(box, fn) {
		box.querySelectorAll('.ui_multi_item').forEach(function (item) {
			var input = multiInput(item);
			if (input && !input.disabled && !item.hidden) fn(input);
		});
	}
	// Prevent text selection during Shift-click.
	on('mousedown', function (e) {
		var item = e.target.closest && e.target.closest('.ui_multi_item');
		if (e.shiftKey && e.button === 0 && item &&
		    item.closest('[data-ui-multi]') &&
		    !e.target.closest('input, a, button')) e.preventDefault();
	});
	on('input', function (e) {
		var search = e.target.closest && e.target.closest('[data-ui-multi-search]');
		var box = search && search.closest('[data-ui-multi]');
		if (box) applyMulti(box);
	});
	// Capture Enter/Escape before theme handlers can submit or leave the page.
	on('keydown', function (e) {
		var search = e.target.closest && e.target.closest('[data-ui-multi-search]');
		var box = search && search.closest('[data-ui-multi]');
		if (!box || e.isComposing) return;
		if (e.key === 'Escape' || e.key === 'Enter') {
			e.preventDefault();
			e.stopPropagation();
		}
		if (e.key === 'Escape') openMultiFilter(box, false);
	}, true);
	on('change', function (e) {
		var box = e.target.closest && e.target.closest('[data-ui-multi]');
		if (!box) return;
		var t = e.target;
		if (t.matches('.ui_multi_modes select, .ui_multi_modes input[type="radio"]')) {
			// Start a new range after a mode change.
			multiAnchors.delete(box);
		}
		applyMulti(box);
	});
	on('click', function (e) {
		var t = e.target.closest && e.target.closest(
			'[data-ui-multi-action], .ui_multi_item');
		var box = t && t.closest('[data-ui-multi]');
		if (!box) return;
		var action = t.getAttribute('data-ui-multi-action');
		if (action === 'filter' || action === 'filter-clear') {
			// Cross clears text or closes an empty filter; funnel toggles.
			e.preventDefault();
			if (t.disabled) return;
			var search = box.querySelector('[data-ui-multi-search]');
			var open = action === 'filter-clear' ? search.value !== '' :
				!t.closest('.ui_multi_filter').classList.contains('ui_multi_filter_open');
			if (action === 'filter-clear') search.value = '';
			openMultiFilter(box, open);
			return;
		}
		if (action === 'all' || action === 'invert') {
			// Apply the bulk action without following the link.
			e.preventDefault();
			eachShownRow(box, function (input) {
				input.checked = action === 'all' || !input.checked;
			});
			multiAnchors.delete(box);
		}
		else if (action) {
			// The switch is handled by change.
			return;
		}
		else {
			var input = multiInput(t);
			if (!input || input.disabled || t.hidden) return;
			// Only row backgrounds need toggling; checkboxes and labels do it natively.
			if (e.target !== input) {
				if (e.target.closest('input, label, a, button')) return;
				input.checked = !input.checked;
			}
			// Apply the clicked state across visible, enabled rows in either direction.
			if (e.shiftKey) {
				var shown = [];
				eachShownRow(box, function (row) { shown.push(row); });
				var start = shown.indexOf(multiAnchors.get(box));
				var end = shown.indexOf(input);
				if (start >= 0 && end >= 0) {
					var checked = input.checked;
					shown.slice(Math.min(start, end), Math.max(start, end) + 1)
						.forEach(function (row) { row.checked = checked; });
				}
			}
			multiAnchors.set(box, input);
		}
		applyMulti(box);
	});
	// Wait for native reset before syncing rows and submitted values.
	on('reset', function (e) {
		window.setTimeout(function () {
			if (e.defaultPrevented) return;
			document.querySelectorAll('[data-ui-multi]').forEach(function (box) {
				if (e.target.contains(box)) {
					multiAnchors.delete(box);
					applyMulti(box, true);
				}
			});
		}, 0);
	});
	// Sync new or restored widgets and discard old range anchors.
	function initMulti() {
		document.querySelectorAll('[data-ui-multi]').forEach(function (box) {
			multiAnchors.delete(box);
			applyMulti(box);
		});
	}
	// Back/forward cache restores do not reload scripts.
	on('pageshow', initMulti, false, window);
	if (document.readyState === 'loading') {
		on('DOMContentLoaded', initMulti);
	} else {
		initMulti();
	}

})();
