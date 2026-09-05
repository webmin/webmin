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

	// Ajax navigation can load the assets again in the same document.
	// Delegated handlers survive navigation and must only be installed once.
	if (window.webminUiWidgetsLoaded) return;
	window.webminUiWidgetsLoaded = true;

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
	document.addEventListener('click', function (e) {
		var confirmer = e.target.closest && e.target.closest('[data-ui-confirm]');
		if (confirmer &&
		    !window.confirm(confirmer.getAttribute('data-ui-confirm'))) {
			e.preventDefault();
			e.stopImmediatePropagation();
		}
	}, true);

	document.addEventListener('input', function (e) {
		var input = e.target.closest && e.target.closest('[data-ui-filter]');
		if (input) applyFilter(input);
	});
	// Choice lists : focusing an input of an option selects that option,
	// as the existing ui_opt_textbox does
	document.addEventListener('focusin', function (e) {
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
	document.addEventListener('change', function (e) {
		var select = e.target;
		if (select.matches && select.matches('select[data-ui-switch]')) {
			applySwitch(select);
		}
	});

	// Native reset restores select values after the reset event, without
	// firing change. Update the panels once those values have been restored.
	document.addEventListener('reset', function (e) {
		window.setTimeout(function () {
			if (e.defaultPrevented) return;
			document.querySelectorAll('select[data-ui-switch]').forEach(function (select) {
				if (select.form === e.target) applySwitch(select);
			});
		}, 0);
	});

})();
