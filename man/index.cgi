#!/usr/local/bin/perl
# index.cgi
# Display the manual pages search form

require './man-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", $module_info{'usermin'} ? 0 : 1, 1);

# build list of available search options
@search = ( "man", "help" );
foreach $d (split(/\s+/, $config{'doc_dir'})) {
	if (-d $d) {
		push(@search, "doc");
		last;
		}
	}
foreach $h (split(/\s+/, $config{'howto_dir'})) {
	if (-d $h) {
		push(@search, "howto");
		last;
		}
	}
if (-d $config{'kde_dir'}) {
	push(@search, "kde");
	}
if (-d $config{'kernel_dir'}) {
	push(@search, "kernel");
	}
if ($perl_doc) {
	push(@search, "perl");
	}
if (-d $config{'custom_dir'}) {
        push(@search, "custom");
        }
push(@search, "google");

# display the search form
print &ui_form_start("search.cgi");
print &ui_table_start($text{'index_header'}, undef, 2);

# Search box and boolean mode
print &ui_table_row($text{'index_for'},
	&ui_textbox("for", undef, 50)."<br>".
	&ui_radio("and", 1, [ [ 1, $text{'index_and'} ],
			      [ 0, $text{'index_or'} ] ]));

# Exact match
print &ui_table_row($text{'index_type'},
	&ui_radio("exact", 1, [ [ 1, $text{'index_name'} ],
			 	[ 0, $text{'index_data'} ] ]));

# Sections to search
$sects = "";
foreach $s (@search) {
	$txt = $text{"index_${s}"};
	$txt = $config{'custom_desc'}
		if ($s eq "custom" && $config{'custom_desc'});
	$sects .= &ui_checkbox("section", $s, $txt, $s eq 'man')."<br>\n";
	}
print &ui_table_row($text{'index_where'}, $sects);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'index_search'} ] ]);

# Form to control search from other modules
if (!$module_info{'usermin'} && $access{'allow'}) {
	@check = $config{'check'} ? split(/\s+/, $config{'check'}) : @search;
	print &ui_hr();
	print &ui_form_start("save_check.cgi");
	print &ui_hidden("count", scalar(@search));
	print "<b>$text{'index_others'}</b><br>\n";
	@grid = ( );
	foreach $s (@search) {
		push(@grid, &ui_checkbox("check", $s, $text{"index_other_${s}"},
				         &indexof($s, @check) >= 0));
		}
	print &ui_grid_table(\@grid, 3);
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}

&ui_print_footer("/", $text{'index'});

