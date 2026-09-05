# UI Demo

A read-only Webmin module that shows the widgets added at the end of
`ui-lib.pl` next to the existing tabs, forms, buttons and tables they are
meant to be combined with. It is a reference for writing new modules and
is not part of the Webmin distribution. Dropping this directory into the
Webmin root is enough to make it appear under the *Others* category.

## What it shows

Every tab of `index.cgi` is built by one function in `ui-demo-pages.pl` :

| Tab        | Function              | Shows                                                            |
|------------|-----------------------|------------------------------------------------------------------|
| Cards      | `demo_cards_tab`      | `ui_card` in its variations : buttons inside a card, header actions and footer, state accents with icon titles, a two-column `ui_dl`, a flush list filtered by a `ui_search` in the header, a standard table inside a card, a metric card with `ui_stat` and inline `ui_progress`, a card printed with `ui_card_start`/`ui_card_end`; `ui_stats`; `ui_grid` with the `template` option |
| Elements   | `demo_elements_tab`   | a `ui_dl` with help bubbles and HTML values, `ui_stats` with icons and links, `ui_feed` with an HTML event, `ui_empty_state`, then badges with their icon, dot and title options, chips, `ui_code`, `ui_note`, `ui_help`, `ui_tip`, every `ui_progress` variation and the ring gauges, and `ui_svg_icon` |
| Forms      | `demo_forms_tab`      | the usual `ui_table_start` / `ui_table_row` form with `ui_toggle`, `ui_search`, the date chooser and password fields; a second form of choosers : `file_chooser_button` for files and directories, `ui_user_textbox`, `ui_group_textbox`, `ui_users_textbox`, `ui_groups_textbox`, and an `hlink` help link |
| Choices    | `demo_choices_tab`    | three replacements for `ui_radio_table` and hand-made tables of radios with inputs : `ui_choice` (boxed, every option's inputs visible), `ui_select_switch` (a select showing only the chosen option's block) and `ui_radio_list` (compact radios); the backup destination selector twice and Virtualmin's new IP address selectors |
| Buttons    | `demo_buttons_tab`    | `ui_submit`, `ui_reset` and `ui_link_button` in one row, with a disabled and a confirmed one; a form ended by `ui_form_end`, one by `ui_form_grouped_buttons`, one by `ui_form_end_side_by_side` with a separate form at the right; a `ui_confirmation_form` page |
| Accordions | `demo_accordions_tab` | a settings form of `ui_table_start` followed by `ui_hidden_table_start` sections |
| Tables     | `demo_tables_tab`     | the empty state shown instead of a table with no rows, `ui_columns_table` with a `ui_details` disclosure in its first cell (classes `inline inlined`, as grub2's boot entries), and `ui_form_columns_table`, both with the sortable flag; the tab description itself hides more text behind a `ui_details` tick (class `inline`), as Virtualmin's SSL page does |
| Lists      | `demo_lists_tab`      | `ui_list` rows with badges, tags, meta and actions; a backup history with state icons, a filesystem list with inline progress bars, and a user list with a confirmed delete link |
| Icon links | `demo_iconlinks_tab`  | `icons_table` with SVG icons from `images/`, then a rule and the bottom-of-page `ui_buttons_row` block from `demo_page_actions` |
| Config editor | `demo_editor_tab`  | links to `edit_manual.cgi`, a manual config file editor page as in nftables : file selector form, then a large `ui_textarea` with Save, submitting to a `save_manual.cgi` that writes nothing |
| Alerts     | `demo_alerts_tab`     | every `ui_alert` type, one with a custom icon and title on one line, and an opened `ui_details` box with the `error` class under the error alert, as MariaDB shows its connection error |

The page itself is wrapped in `ui_page_start` / `ui_page_end`, which load
the stylesheet and script from `unauthenticated/css/ui-lib.css` and
`unauthenticated/js/ui-lib.js` once per page.

## Page chrome

Around the gallery, `index.cgi` and `demo_page_actions` show the parts
of a module page that are easy to get wrong :

| Piece | API | Seen in |
|-------|-----|---------|
| Subtitle under the page title | first argument of `ui_print_header`; several lines are separated by `<br>` | grub2 "GRUB version 2.12", Virtualmin Podman "In domain … / Image pool …" |
| Password shown as dots until hovered | `ui_text_mask(text, tag)` inside that tag, e.g. `ui_tag('tt', ui_text_mask($pass, 'tt'))` | Virtualmin Podman "Administrator credentials" |
| Help question mark at the right of the title | `help` argument of `ui_print_header`, naming a page in `help/` (here `help/intro.html`) | every module with help |
| Module config cog | `config` argument of `ui_print_header` set to 1, with a `config.info` listing the options and a `config` file of defaults; hidden for users whose ACL has `noconfig` | BIND, Apache, most modules |
| Search docs button | `help_search_link(term, sections...)` appended to `rightside`; returns nothing when the man module is not available. Explained in `index.cgi` but not used, since the demo has no system documentation | BIND DNS Server |
| Apply / restart button at the right of the title | `rightside` argument of `ui_print_header` with a `ui_link` to `apply.cgi`, `restart.cgi`, `generate.cgi`, `start.cgi` or `stop.cgi`; wrap the text in `<b>` while a change is pending and Authentic shows the button large with its text | grub2 "Regenerate GRUB menu" |
| Links at the left and right of a table | `otherlinks` argument of `ui_form_columns_table`, each `[ url, text, 'right' ]` | Users and Groups "Create a new user", "Run batch file" |
| Icon links to sub-pages | `icons_table` with SVG files from `images/`, on the Icon links tab | grub2 "Global Options", Webmin Configuration |
| Buttons with descriptions at the bottom of a page | `ui_buttons_start`, `ui_buttons_row`, `ui_buttons_end` after `ui_hr`, below the icon links; the after-submit and before-submit slots hold extra inputs | SSH Server, grub2, Virtualmin Podman index, Webmin Configuration "Start at boot time" |
| Return buttons under a page | pairs of URL and text given to `ui_print_footer`, most specific first; the theme draws them as footer buttons | every module page, e.g. `edit_manual.cgi` here with two of them |
| A button followed by a sentence of selects | `ui_buttons_row` with single-cell set, the fields in the after-submit slot, and a flex span opened in before-submit and closed after the fields | Virtualmin Podman "Add New … named … for …", WP Workbench "Create Scheduled Backup for … every …" |

## Rules the examples follow

- Reuse the existing API for tabs, forms, buttons and tables. The widget
  functions only add what was missing : cards, grids, stat tiles,
  description lists, badges, chips, list rows, feeds, empty states,
  progress bars, the toggle switch and the search box.
- Widget options are passed in a hash reference after any positional
  content arguments, and each widget returns a string. Text options are
  escaped by the library; `body`, `actions`, `footer` and `*_html` options
  are raw HTML built from other ui functions.
- Custom widget markup uses `ui_tag`; the examples also compose existing
  UI helpers and small HTML fragments.
- Interface labels come from `lang/en`; sample system data is embedded
  in the page builders.
- The page builders print nothing and do not need `init_config`, so they
  can be rendered outside Webmin for previews and tests.

## Theme caveats

Two more things on the Forms and Config editor tabs are Authentic features,
not core API :

- **Password meter and buttons.** Authentic adds the strength meter, the
  show/hide eye and the generate key next to password inputs on module
  pages it knows, or on any page where a password input carries a
  `data-password` attribute. Mark the repeat field `data-password-again`
  and it only gets the eye. Pass the attribute in the tags argument of
  `ui_password`.
- **Code editor.** Authentic replaces the text area of a manual config
  editor page with a code editor, and adds its own "Save and close" and
  file-manager buttons, only on pages it recognizes by name, such as
  `edit_manual.cgi`. That is why the demo's editor is a page of its own
  rather than a tab : the same form inside a tab of `index.cgi` stays a
  plain text area.

Authentic renders every `ui_link` as a small button, and inside widget
pages it draws `ui_link_button` the same way, so the two can be mixed in
card footers, header actions and list rows. Only in a `ui_cluster` row
that also holds submit buttons do a `ui_link_button` and a `ui_reset`
take the normal button size, as on the Buttons tab. A link inside text,
such as in a `ui_dl` value or a `ui_feed` event, must be built with
`ui_tag('a', text, { 'href' => url })` to stay a plain link, as the
Elements tab does. The stylesheet underlines such links inside widget
text, so they are not lost between chips and badges.

Authentic gives buttons their color and icon from the **lang key name**,
not from anything in the code : it looks the button label up in the lang
table, finds the key holding that exact text, and matches the key name
against patterns such as `start`, `restart`, `index_stop`, `index_reload`,
`index_boot`, `delete` and `status` (see `get_button_style` in the theme).
The Service card on the Cards tab shows four such buttons. Until that
behavior goes away :

- name button keys simply and stably : `index_start`, `index_stop`,
  `index_restart`, `index_reload`, `index_boot_off`; a key holding the
  word `delete`, as `index_b_delete` on the confirmation page, gets the
  red style and its icon;
- keep each button text unique in the lang file, or the lookup may land on
  another key with the same text and the button loses its style.

## Not to copy

`ui-demo-lib.pl` sets `$main::no_acl_check` before `init_config`, so the
module can be opened by any user even though it is not in anyone's module
ACL. That is only acceptable because this module reads nothing and changes
nothing. A real module must leave the ACL check in place and be installed
through the module installer, which adds it to the ACL.

The full option reference is the POD in the *Widgets* section at the
end of `ui-lib.pl`.
