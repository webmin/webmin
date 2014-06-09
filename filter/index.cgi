#!/usr/local/bin/perl
# Show a table of simple actions

require './filter-lib.pl';
&foreign_require("mailbox", "mailbox-lib.pl");
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1);

if (&get_product_name() eq 'webmin') {
	&ui_print_endpage($text{'index_nowebmin'});
	}

# Warn if procmail is not installed
if ($config{'warn_procmail'} && !&has_command("procmail")) {
	print "$text{'index_warn'}<p>\n";
	}

# Check for an override alias
$alias = &get_override_alias();
if ($alias) {
	# Got one .. but does it deliver locally
	$noat = $remote_user;
	$noat =~ s/\@/-/g;
	@values = @{$alias->{'values'}};
	($tome) = grep { $_ eq "\\$remote_user" ||
			 $_ eq "\\$noat" } @values;
	if ($tome) {
		@values = grep { $_ ne $tome } @values;
		$msg = 'index_aliasme';
		}
	else {
		$msg = 'index_alias';
		}
	print "<b>$text{$msg}</b><br>\n";
	print "<ul>\n";
	foreach $dest (&describe_alias_dest(\@values)) {
		print "<li>$dest\n";
		}
	print "</ul>\n";
	}

# Check if /etc/procmailrc forces local delivery
if (&no_user_procmailrc()) {
	print "<b>",$text{'index_force'},"</b><p>\n";
	}

@filters = &list_filters();
@links = ( );
if (@filters) {
	push(@links, &select_all_link("d"), &select_invert_link("d"));
	}
push(@links, &ui_link("edit.cgi?new=1",$text{'index_add'}));
($auto) = grep { $_->{'actionreply'} } @filters;
if (&can_simple_autoreply() && !$auto) {
	push(@links, &ui_link("edit_auto.cgi",$text{'index_addauto'}));
	}
($fwd) = grep { $_->{'actiontype'} eq '!' } @filters;
if (&can_simple_forward() && !$fwd) {
	push(@links, &ui_link("edit_forward.cgi",$text{'index_addfwd'}));
	}

@folders = &mailbox::list_folders();
if (@filters || &get_global_spamassassin()) {
	# Show table of filters
	print &ui_form_start("delete.cgi", "post");
	@tds = ( "width=5", "width=50%", "width=50%", "width=32" );
	print &ui_links_row(\@links);
	print &ui_columns_start([ "",
				  $text{'index_condition'},
				  $text{'index_action'},
				  @filters > 1 ? ( $text{'index_move'} ) : ( ),
				], 100, 0, \@tds);

	# Add a magic non-editable row(s) for global spamassassin run
	if (&get_global_spamassassin()) {
		print &ui_columns_row(
			[ "", $text{'index_calways'}, $text{'index_aspam'},
			  @filters > 1 ? ( "" ) : ( ) ],
			\@tds);
		# Delete level
		$spamlevel = &get_global_spam_delete();
		if ($spamlevel) {
			print &ui_columns_row(
				[ "", &text('index_clevel', $spamlevel),
				      $text{'index_athrow'},
				  @filters > 1 ? ( "" ) : ( ) ],
				\@tds);
			}
		# Delivery path
		$spamfile = &get_global_spam_path();
		if ($spamfile) {
			$folder = &file_to_folder($spamfile, \@folders, 0, 1);
			$id = &mailbox::folder_name($folder);
			if ($folder->{'fake'}) {
				$sflink = "<u>$folder->{'name'}</u>";
				}
			else {
				$sflink =
				    "<a href='../mailbox/index.cgi?id=$id'>".
				    "$folder->{'name'}</a>";
				}
			print &ui_columns_row(
				[ "", $text{'index_cspam'},
				      &text('index_afolder', $sflink),
				  @filters > 1 ? ( "" ) : ( ) ],
				\@tds);
			}
		}

	# Show editable rows
	foreach $f (@filters) {
		# Work out nice condition and action descriptions
		local $cond;
		($cond, $lastalways) = &describe_condition($f);
		$cond = &ui_link("edit.cgi?idx=$f->{'index'}",$cond);
		local $action = &describe_action($f, \@folders);

		# Create mover links
		local $mover;
		if ($f eq $filters[0]) {
			$mover .= "<img src=images/gap.gif alt=' '>";
			}
		else {
			$mover .= "<a href='up.cgi?idx=$f->{'index'}'>".
			      "<img src=images/up.gif border=0 alt='Up'></a>";
			}
		if ($f eq $filters[$#filters]) {
			$mover .= "<img src=images/gap.gif alt=' '>";
			}
		else {
			$mover .= "<a href='down.cgi?idx=$f->{'index'}'>".
			    "<img src=images/down.gif border=0 alt='Down'></a>";
			}

		# Show the row
		print &ui_checked_columns_row(
			[ $cond,
			  $action,
			  @filters > 1 ? ( $mover ) : ( ) ],
			\@tds, "d", $f->{'index'}
			);

		}

	# Add a magic non-editable row for default delivery
	if (!$lastalways) {
		print &ui_columns_row(
			[ "", $text{'index_calways'}, $text{'index_adefault'},
			  @filters > 1 ? ( "" ) : ( ) ],
			\@tds);
		}

	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	# Tell the user there are none
	@pmrc = &procmail::get_procmailrc();
	if (@pmrc) {
		print "<b>$text{'index_none2'}</b><p>\n";
		}
	else {
		print "<b>$text{'index_none'}</b><p>\n";
		}
	print &ui_links_row(\@links);
	}

&ui_print_footer("/", $text{'index'});

