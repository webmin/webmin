#!/usr/local/bin/perl
# edit_white.cgi
# Display white and black lists of to and from addresses

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("white");
&ui_print_header($header_subtext, $text{'white_title'}, "");
$conf = &get_config();

print "$text{'white_desc'}<p>\n";
print &ui_form_start("save_white.cgi", "form-data");
print $form_hiddens;

# Start of tabs
$url = "edit_white.cgi?file=".&urlize($in{'file'}).
       "&title=".&urlize($in{'title'});
print &ui_tabs_start(
	[ map { [ $_, $text{'white_tab'.$_}, $url."&mode=$_" ] }
	      ( 'ham', 'spam', 'some', 'import' ) ],
	"mode", $in{'mode'} || "ham", 1);

# Start of ham addresses tab
print &ui_tabs_start_tab("mode", "ham");
print $text{'white_hamdesc'},"<p>\n";
print &ui_table_start(undef, undef, 2);

# Addresses to always whitelist
@from = &find("whitelist_from", $conf);
print &ui_table_row($text{'white_from'},
	&edit_textbox("whitelist_from",
		      [ map { @{$_->{'words'}} } @from ], 60, 10));

# Exceptions to whitelist
@un = &find("unwhitelist_from", $conf);
print &ui_table_row($text{'white_unfrom'},
	&edit_textbox("unwhitelist_from",
		      [ map { @{$_->{'words'}} } @un ], 60, 5));

if ($config{'show_global'}) {
	# Global white and blacklists
	$gconf = &get_config($config{'global_cf'}, 1);
	@gfrom = &find("whitelist_from", $gconf);
	print &ui_table_row($text{'white_gfrom'},
		&edit_textbox("gwhitelist_from",
			      [ map { @{$_->{'words'}} } @gfrom ], 40, 5, 1));

	@gun = &find("unwhitelist_from", $gconf);
	print &ui_table_row($text{'white_gunfrom'},
		&edit_textbox("gunwhitelist_from",
			      [ map { @{$_->{'words'}} } @gun ], 40, 5));
	}

# Whitelist by received header
@rcvd = &find("whitelist_from_rcvd", $conf);
print &ui_table_row($text{'white_rcvd2'},
	&edit_table("whitelist_from_rcvd",
		[ $text{'white_addr'}, $text{'white_rcvdhost'} ],
		[ map { $_->{'words'} } @rcvd ], [ 40, 30 ], undef, 3));

print &ui_table_end();
print &ui_tabs_end_tab("mode", "ham");

# Start of spam addresses tab
print &ui_tabs_start_tab("mode", "spam");
print $text{'white_spamdesc'},"<p>\n";
print &ui_table_start(undef, undef, 2);

# Blacklisted addresses
@from = &find("blacklist_from", $conf);
print &ui_table_row($text{'white_black'},
	&edit_textbox("blacklist_from",
		      [ map { @{$_->{'words'}} } @from ], 60, 10));

# Exceptions to blacklist
@un = &find("unblacklist_from", $conf);
print &ui_table_row($text{'white_unblack'},
	&edit_textbox("unblacklist_from",
		      [ map { @{$_->{'words'}} } @un ], 40, 5));

if ($config{'show_global'}) {
	# Global blacklist
	@gfrom = &find("blacklist_from", $gconf);
	print &ui_table_row($text{'white_gblack'},
		&edit_textbox("gblacklist_from",
			      [ map { @{$_->{'words'}} } @gfrom ], 40, 5, 1));

	@gun = &find("gunblacklist_from", $gconf);
	print &ui_table_row($text{'white_gunblack'},
		&edit_textbox("gunblacklist_from",
			      [ map { @{$_->{'words'}} } @gun ], 40, 5, 1));
	}

print &ui_table_end();
print &ui_tabs_end_tab("mode", "spam");

print &ui_tabs_start_tab("mode", "some");
print $text{'white_somedesc'},"<p>\n";
print &ui_table_start(undef, undef, 2);

# Addresses to allow some spam to
push(@to, map { [ $_, 0 ] } map { @{$_->{'words'}} }
	      &find("whitelist_to", $conf));
push(@to, map { [ $_, 1 ] } map { @{$_->{'words'}} }
	      &find("more_spam_to", $conf));
push(@to, map { [ $_, 2 ] } map { @{$_->{'words'}} }
	      &find("all_spam_to", $conf));
print &ui_table_row($text{'white_to'},
	&edit_table("whitelist_to",
		    [ $text{'white_addr2'}, $text{'white_level'} ],
		    \@to, [ 40, 0 ], \&whitelist_to_conv, 3));

print &ui_table_end();
print &ui_tabs_end_tab("mode", "some");

# Show whitelist import form
print &ui_tabs_start_tab("mode", "import");
print "$text{'white_importdesc'}<p>\n";
print &ui_table_start(undef, undef, 2);

# File to import, uploaded
print &ui_table_row($text{'white_import'}, &ui_upload("import"));

# Sort addresses?
print &ui_table_row($text{'white_sort'}, &ui_yesno_radio("sort", 0));

print &ui_table_end();
print &ui_tabs_end_tab("mode", "import");

print &ui_tabs_end(1);
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer($redirect_url, $text{'index_return'});

# whitelist_to_conv(col, name, size, value)
sub whitelist_to_conv
{
if ($_[0] == 0) {
	return &default_convfunc(@_);
	}
else {
	return &ui_select($_[1], $_[3],
		[ [ 0, $text{"white_level0"} ],
		  [ 1, $text{"white_level1"} ],
		  [ 2, $text{"white_level2"} ] ]);
	}
}

