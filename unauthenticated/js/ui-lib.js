/*
 * ui-lib.js
 * Behavior for the widgets added to ui-lib.pl.
 *
 * Everything is wired through delegated event listeners keyed off
 * data-ui-* attributes, so no inline handlers are generated and pages
 * remain compatible with a strict Content-Security-Policy. Tabs, sorting
 * and select-all links keep using the scripts the existing ui-lib
 * functions and themes already provide.
 *
 * Besides the filters, confirmations, choice lists and selection lists,
 * this script drives the drop-down menus of ui_dropdown (one open at a
 * time, closed by a click elsewhere or Escape, arrow keys between the
 * entries, flipped to stay in the window) and the dialogs of ui_dialog
 * (opened by data-ui-dialog controls, filled from data-ui-dialog-values,
 * closed by data-ui-dialog-close controls or a click on the backdrop).
 * window.webminUiWidgets.openDialog(id, values) and closeDialog(id) do
 * the same from module scripts, and webminUiWidgets.confirm(message,
 * options) asks a question in the confirmation dialog that
 * data-ui-confirm controls use, resolving with the answer.
 */
(function () {
	'use strict';

	// Replace old listeners when Ajax navigation reloads this script.
	if (window.webminUiWidgets) window.webminUiWidgets.remove();
	var listeners = [];
	var dropdownObserver;
	function on(type, fn, capture, target) {
		target = target || document;
		target.addEventListener(type, fn, capture);
		listeners.push([ type, fn, capture, target ]);
	}
	window.webminUiWidgets = {
		remove: function () {
			if (dropdownObserver) dropdownObserver.disconnect();
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
	// The click is caught before a theme or inline handler performs the
	// action, the question is asked in a dialog, and the click is replayed
	// once confirmed. data-ui-confirm-title, data-ui-confirm-ok and
	// data-ui-confirm-state refine the dialog; a danger action button asks
	// in the danger state by default.
	var replaying = null;
	on('click', function (e) {
		// Disabled action links must not run handlers or open confirmations.
		var disabled = e.target.closest && e.target.closest('.ui_action[aria-disabled="true"]');
		if (disabled) {
			e.preventDefault();
			e.stopImmediatePropagation();
			return;
		}
		var confirmer = e.target.closest && e.target.closest('[data-ui-confirm]');
		if (!confirmer || confirmer === replaying) return;
		e.preventDefault();
		e.stopImmediatePropagation();
		openDropdowns().forEach(function (menu) { closeDropdown(menu); });
		var state = confirmer.getAttribute('data-ui-confirm-state') ||
			(confirmer.classList.contains('ui_action_danger') ? 'danger' : 'warning');
		uiConfirm(confirmer.getAttribute('data-ui-confirm'), {
			title: confirmer.getAttribute('data-ui-confirm-title'),
			ok: confirmer.getAttribute('data-ui-confirm-ok'),
			state: state
		}).then(function (yes) {
			if (!yes) return;
			replaying = confirmer;
			try { confirmer.click(); } finally { replaying = null; }
		});
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
		var shownGroups = new Set();
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
			if (match) {
				matched++;
				shownGroups.add(item.getAttribute('data-ui-multi-group'));
			}
			item.hidden = !match;
		});
		// Hide headings whose entries are all filtered or folded.
		box.querySelectorAll('[data-ui-multi-heading]').forEach(function (heading) {
			heading.hidden = !shownGroups.has(heading.getAttribute('data-ui-multi-heading'));
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

	// ---- Drop-down menus ----
	// The details element opens and closes natively; this adds the
	// behavior a menu needs on top of that.
	function openDropdowns() {
		return document.querySelectorAll('details.ui_dropdown[open]');
	}
	function dropdownItems(menu) {
		return Array.prototype.slice.call(menu.querySelectorAll(
			'.ui_dropdown_item:not(:disabled):not([aria-disabled="true"])'));
	}
	function closeDropdown(menu, refocus) {
		menu.removeAttribute('open');
		menu.classList.remove('ui_dropdown_flip');
		var summary = menu.querySelector(':scope > summary');
		if (refocus && summary) summary.focus();
	}
	// positionDropdown(menu) keeps one menu open and flips it to fit the window.
	function positionDropdown(menu) {
		if (!menu.matches || !menu.matches('details.ui_dropdown')) return;
		if (!menu.open) {
			menu.classList.remove('ui_dropdown_flip');
			return;
		}
		openDropdowns().forEach(function (other) {
			if (other !== menu) closeDropdown(other);
		});
		var panel = menu.querySelector('.ui_dropdown_menu');
		if (!panel) return;
		menu.classList.remove('ui_dropdown_flip');
		var rect = panel.getBoundingClientRect();
		var width = document.documentElement.clientWidth;
		var end = menu.classList.contains('ui_dropdown_end');
		if ((!end && rect.right > width - 8) || (end && rect.left < 8)) {
			menu.classList.add('ui_dropdown_flip');
		}
	}
	// Attribute observers run before painting; native toggle events may arrive
	// after the panel has already appeared on the wrong side.
	dropdownObserver = new MutationObserver(function (records) {
		var menus = new Set();
		records.forEach(function (record) {
			if (record.target.matches('details.ui_dropdown')) menus.add(record.target);
		});
		menus.forEach(function (menu) {
			if (menu.isConnected) positionDropdown(menu);
		});
	});
	dropdownObserver.observe(document, {
		attributes: true, attributeFilter: ['open'], subtree: true
	});
	// Also place menus that were already open when this script loaded, or
	// were inserted as open markup. Toggle does not bubble.
	openDropdowns().forEach(positionDropdown);
	on('toggle', function (e) { positionDropdown(e.target); }, true);
	// A click outside an open menu closes it; a chosen entry closes its
	// menu once its own action has run
	on('click', function (e) {
		var inside = e.target.closest && e.target.closest('details.ui_dropdown[open]');
		openDropdowns().forEach(function (menu) {
			if (menu !== inside) closeDropdown(menu);
		});
		var item = e.target.closest && e.target.closest('.ui_dropdown_item');
		if (item && inside && !e.defaultPrevented) {
			window.setTimeout(function () { closeDropdown(inside); }, 0);
		}
	});
	// Keep the focus, and so the menu, while clicking on its padding,
	// headings and separators
	on('mousedown', function (e) {
		var panel = e.target.closest && e.target.closest('.ui_dropdown_menu');
		if (panel && !e.target.closest('input, select, textarea, a, button, [tabindex]')) {
			e.preventDefault();
		}
	});
	on('keydown', function (e) {
		var menu = e.target.closest && e.target.closest('details.ui_dropdown');
		if (!menu || e.isComposing) return;
		var items = dropdownItems(menu);
		var current = items.indexOf(document.activeElement);
		if (e.key === 'Escape') {
			if (!menu.open) return;
			e.preventDefault();
			e.stopPropagation();
			closeDropdown(menu, true);
		}
		else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
			e.preventDefault();
			if (!menu.open) {
				menu.setAttribute('open', '');
				// Place the panel before focusing an item can scroll it into view.
				positionDropdown(menu);
			}
			if (!items.length) return;
			var next;
			if (e.key === 'ArrowDown') {
				next = current < 0 ? 0 : (current + 1) % items.length;
			} else {
				next = current < 0 ? items.length - 1 :
					(current - 1 + items.length) % items.length;
			}
			items[next].focus();
		}
		else if ((e.key === 'Home' || e.key === 'End') && menu.open && items.length) {
			e.preventDefault();
			items[e.key === 'Home' ? 0 : items.length - 1].focus();
		}
	});
	// Tabbing out of an open menu closes it
	on('focusout', function (e) {
		var menu = e.target.closest && e.target.closest('details.ui_dropdown[open]');
		if (menu && (!e.relatedTarget || !menu.contains(e.relatedTarget))) {
			closeDropdown(menu);
		}
	});

	// ---- Dialogs ----
	function findDialog(ref) {
		if (!ref) return null;
		return typeof ref === 'string' ? document.getElementById(ref) : ref;
	}
	// Fill the dialog's fields from a name to value map
	function fillDialog(dialog, values) {
		if (!values || typeof values !== 'object') return;
		Object.keys(values).forEach(function (name) {
			var value = values[name];
			var selector = '[name="' + name.replace(/["\\]/g, '\\$&') + '"]';
			dialog.querySelectorAll(selector).forEach(function (field) {
				if (field.type === 'checkbox' || field.type === 'radio') {
					field.checked = Array.isArray(value) ?
						value.indexOf(field.value) >= 0 :
						value === true || String(field.value) === String(value);
				}
				else if (field.tagName === 'SELECT' && field.multiple && Array.isArray(value)) {
					Array.prototype.forEach.call(field.options, function (option) {
						option.selected = value.indexOf(option.value) >= 0;
					});
				}
				else if (field.type !== 'file') {
					field.value = value === null || value === undefined ? '' : value;
				}
			});
		});
	}
	// Open a dialog modally, after filling it and letting module scripts
	// prepare or veto it through the ui-dialog-open event
	function openDialog(ref, values, opener) {
		var dialog = findDialog(ref);
		if (!dialog) return null;
		fillDialog(dialog, values);
		var go = dialog.dispatchEvent(new CustomEvent('ui-dialog-open', {
			bubbles: true, cancelable: true,
			detail: { opener: opener || null, values: values || null }
		}));
		if (!go) return null;
		if (!dialog.open) {
			if (typeof dialog.showModal === 'function') dialog.showModal();
			else dialog.setAttribute('open', '');
		}
		var focus = dialog.querySelector('[autofocus]') || dialog.querySelector(
			'input:not([type="hidden"]):not([disabled]), select:not([disabled]), ' +
			'textarea:not([disabled]), button:not([disabled]):not(.ui_dialog_x)');
		if (focus) focus.focus();
		return dialog;
	}
	function closeDialog(ref) {
		var dialog = findDialog(ref);
		if (dialog && dialog.open) dialog.close();
	}

	// ---- Confirmations ----
	// One dialog, built on first use and reused, asks the questions of
	// data-ui-confirm controls and of webminUiWidgets.confirm(). Its texts
	// come from the data attributes ui_page_assets puts on this script
	// tag, with English fallbacks for pages that load the script by hand.
	var confirmTexts = (function () {
		var me = document.currentScript || document.querySelector('script[data-ui-lib]');
		var d = me ? me.dataset : {};
		return { title: d.uiTextConfirm || 'Please confirm', ok: d.uiTextOk || 'OK',
			 cancel: d.uiTextCancel || 'Cancel', close: d.uiTextClose || 'Close' };
	})();
	// The state icons of ui_svg_icon, drawn the same way
	var confirmIcons = {
		warning: 'M8 2.6l6.4 10.4H1.6L8 2.6z|M8 6.8v2.7|M8 11.3h.01',
		danger: 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M6 6l4 4|M10 6l-4 4',
		info: 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M8 7.4v3.4|M8 5.1h.01',
		success: 'M8 14.25A6.25 6.25 0 1 0 8 1.75a6.25 6.25 0 0 0 0 12.5z|M5.4 8.3l1.8 1.9 3.4-4',
		x: 'M4.5 4.5l7 7|M11.5 4.5l-7 7'
	};
	function confirmIcon(name, size) {
		var ns = 'http://www.w3.org/2000/svg';
		var svg = document.createElementNS(ns, 'svg');
		svg.setAttribute('class', 'ui_svg_icon ui_svg_icon_' + name);
		svg.setAttribute('width', size);
		svg.setAttribute('height', size);
		svg.setAttribute('viewBox', '0 0 16 16');
		svg.setAttribute('fill', 'none');
		svg.setAttribute('stroke', 'currentColor');
		svg.setAttribute('stroke-width', '1.5');
		svg.setAttribute('stroke-linecap', 'round');
		svg.setAttribute('stroke-linejoin', 'round');
		svg.setAttribute('aria-hidden', 'true');
		confirmIcons[name].split('|').forEach(function (d) {
			var path = document.createElementNS(ns, 'path');
			path.setAttribute('d', d);
			svg.appendChild(path);
		});
		return svg;
	}
	function actionButton(className, attrs) {
		var button = document.createElement('button');
		button.type = 'button';
		button.className = className;
		Object.keys(attrs).forEach(function (name) { button.setAttribute(name, attrs[name]); });
		var content = document.createElement('span');
		content.className = 'ui_action_content';
		content.appendChild(document.createElement('span'));
		button.appendChild(content);
		return button;
	}
	// A page may supply its own dialog with the id ui_confirm, holding a
	// data-ui-confirm-text element and a data-ui-confirm-ok button
	function confirmDialog() {
		var dialog = document.getElementById('ui_confirm');
		if (dialog) return dialog;
		dialog = document.createElement('dialog');
		dialog.id = 'ui_confirm';
		dialog.className = 'ui_dialog ui_dialog_small';
		dialog.setAttribute('aria-labelledby', 'ui_confirm_title');
		var head = document.createElement('header');
		head.className = 'ui_dialog_head';
		var titles = document.createElement('div');
		titles.className = 'ui_dialog_titles';
		var title = document.createElement('h2');
		title.className = 'ui_dialog_title';
		title.id = 'ui_confirm_title';
		titles.appendChild(title);
		head.appendChild(titles);
		var x = document.createElement('button');
		x.type = 'button';
		x.className = 'ui_dialog_x';
		x.setAttribute('data-ui-dialog-close', '1');
		x.setAttribute('aria-label', confirmTexts.close);
		x.title = confirmTexts.close;
		x.appendChild(confirmIcon('x', 16));
		head.appendChild(x);
		dialog.appendChild(head);
		var body = document.createElement('div');
		body.className = 'ui_dialog_body';
		var text = document.createElement('p');
		text.className = 'ui_dialog_text';
		text.setAttribute('data-ui-confirm-text', '1');
		body.appendChild(text);
		dialog.appendChild(body);
		var foot = document.createElement('footer');
		foot.className = 'ui_dialog_foot';
		foot.appendChild(actionButton('ui_action ui_action_warning ui_action_normal ui_action_square',
			{ 'data-ui-confirm-ok': '1' }));
		var cancel = actionButton('ui_action ui_action_neutral ui_action_normal ui_action_square',
			{ 'data-ui-dialog-close': '1', 'autofocus': '' });
		cancel.querySelector('.ui_action_content > span').textContent = confirmTexts.cancel;
		foot.appendChild(cancel);
		dialog.appendChild(foot);
		document.body.appendChild(dialog);
		return dialog;
	}
	// Ask a question and resolve with true on OK, false otherwise. The
	// options are title, ok (the label of the confirming button) and state.
	// Without dialog support the browser's own prompt is used.
	function uiConfirm(message, opts) {
		opts = opts || {};
		return new Promise(function (resolve) {
			if (typeof HTMLDialogElement === 'undefined') {
				resolve(window.confirm(message));
				return;
			}
			var state = /^(?:warning|danger|info|success|neutral)$/.test(opts.state || '') ?
				opts.state : 'warning';
			var dialog = confirmDialog();
			dialog.classList.remove('ui_dialog_warning', 'ui_dialog_danger',
				'ui_dialog_info', 'ui_dialog_success', 'ui_dialog_neutral');
			dialog.classList.add('ui_dialog_' + state);
			var title = dialog.querySelector('.ui_dialog_title');
			if (title) {
				title.textContent = '';
				if (confirmIcons[state]) title.appendChild(confirmIcon(state, 18));
				var span = document.createElement('span');
				span.textContent = opts.title || confirmTexts.title;
				title.appendChild(span);
			}
			var text = dialog.querySelector('[data-ui-confirm-text]');
			if (text) text.textContent = message;
			var ok = dialog.querySelector('[data-ui-confirm-ok]');
			if (ok) {
				ok.className = 'ui_action ui_action_' + state + ' ui_action_normal ui_action_square';
				var label = ok.querySelector('.ui_action_content > span');
				if (label) label.textContent = opts.ok || confirmTexts.ok;
			}
			var done = false;
			function finish(result) {
				if (done) return;
				done = true;
				dialog.removeEventListener('close', onClose);
				if (ok) ok.removeEventListener('click', onOk);
				resolve(result);
			}
			function onOk() {
				finish(true);
				dialog.close();
			}
			function onClose() { finish(false); }
			if (ok) ok.addEventListener('click', onOk);
			dialog.addEventListener('close', onClose);
			if (!openDialog(dialog)) finish(false);
		});
	}
	window.webminUiWidgets.openDialog = openDialog;
	window.webminUiWidgets.closeDialog = closeDialog;
	window.webminUiWidgets.confirm = uiConfirm;
	on('click', function (e) {
		if (!e.target.closest) return;
		var closer = e.target.closest('[data-ui-dialog-close]');
		if (closer) {
			var owner = closer.closest('dialog');
			if (owner) {
				e.preventDefault();
				owner.close();
			}
			return;
		}
		var opener = e.target.closest('[data-ui-dialog]');
		if (opener) {
			// A link opener must not navigate
			if (opener.matches('a')) e.preventDefault();
			if (opener.matches(':disabled, [aria-disabled="true"]')) return;
			var values = null;
			try {
				values = JSON.parse(opener.getAttribute('data-ui-dialog-values') || 'null');
			} catch (err) {
				values = null;
			}
			openDialog(opener.getAttribute('data-ui-dialog'), values, opener);
			return;
		}
		// A click on the backdrop, which lands on the dialog element itself
		// outside its box, closes the dialog
		var dialog = e.target;
		if (dialog.matches && dialog.matches('dialog.ui_dialog[open]')) {
			var rect = dialog.getBoundingClientRect();
			if (e.clientX < rect.left || e.clientX > rect.right ||
			    e.clientY < rect.top || e.clientY > rect.bottom) {
				dialog.close();
			}
		}
	});

})();
