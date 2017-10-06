#!/usr/local/bin/perl
# Show icons for sarg option categories

require './sarg-lib.pl';

if (!-r $config{'sarg_conf'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_econf',
			[ "<tt>$config{'sarg_conf'}</tt>", undef ]));
	}
if (!&has_command($config{'sarg'})) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&ui_config_link('index_ecmd',
		        [ "<tt>$config{'sarg'}</tt>", undef ]));
	}

# Get the version
$sarg_version = &get_sarg_version();
if (!$sarg_version) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(
		&text('index_eversion',
		      "<tt>$config{'sarg'}</tt>", "<pre>$out</pre>"));
	}

# Show icons for options
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 &help_search_link("sarg", "man", "doc", "google"),
		 undef, undef,
		 &text('index_version', $sarg_version));
@pages = ( "log", "report", "style", "sched" );
@links = map { "edit_${_}.cgi" } @pages;
@titles = map { $text{"${_}_title"} } @pages;
@icons = map { "images/${_}.gif" } @pages;
&icons_table(\@links, \@titles, \@icons);

# Show buttons for generating report now and for viewing
$conf = &get_config();
$odir = &find_value("output_dir", $conf);
$odir ||= &find_value("output_dir", $conf, 1);
$sfile = &find_value("access_log", $conf);
if ($sfile || $odir && -d $odir) {
	print &ui_hr();
	}
if ($sfile) {
	print &ui_buttons_start();
	print &ui_buttons_row("generate.cgi", $text{'index_generate'},
			      &text('index_generatedesc', "<tt>$odir</tt>").
			      "<br><b>$text{'index_clear'}</b> ".
			      &gen_clear_input().
			      "<br><b>$text{'index_range'}</b> ".
			      &gen_range_input());
	print "<tr> <td><p></td> </tr>\n";
	print &ui_buttons_end();
	}
if ($odir && -d $odir) {
	print &ui_buttons_start();
	print &ui_buttons_row(-r "$odir/index.html" ? "view.cgi/index.html"
						    : "view.cgi/",
			      $text{'index_view'},
			      &text('index_viewdesc', "<tt>$odir</tt>"));
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});
