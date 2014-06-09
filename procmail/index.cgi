#!/usr/local/bin/perl
# index.cgi
# Display the current list of procmail recipes

require './procmail-lib.pl';
if ($minfo{'usermin'}) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	}
else {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	}

# Make sure procmail is installed
if (!$module_info{'usermin'} && !&has_command($config{'procmail'})) {
	print &text('index_ecmd', "<tt>$config{'procmail'}</tt>",
				  "../config.cgi?$module_name"),"<p>\n";

	&foreign_require("software", "software-lib.pl");
	$lnk = &software::missing_install_link(
			"procmail", $text{'index_procmail'},
			"../$module_name/", $text{'index_title'});
	print $lnk,"<p>\n" if ($lnk);

	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

# Tell user when procmail will be used
if ($module_info{'usermin'}) {
	print &text('index_desc', "<tt>$procmailrc</tt>"),"<p>\n";
	}
else {
	($ms, $mserr) = &check_mailserver_config();
	if ($mserr) {
		print "<b>",&text('index_mserr', $mserr),"</b><p>\n";
		}
	elsif (!$ms) {
		print &text('index_desc_other', "<tt>$procmailrc</tt>"),"<p>\n";
		}
	}

# Build links for adding things
@links = ( &ui_link("edit_recipe.cgi?new=1",$text{'index_add'}),
	   &ui_link("edit_recipe.cgi?new=1&block=1",$text{'index_badd'}),
	   &ui_link("edit_env.cgi?new=1",$text{'index_eadd'}) );
push(@links, &ui_link("edit_inc.cgi?new=1",$text{'index_iadd'}))
	if (!$includes);

@conf = &get_procmailrc();
if (@conf) {
	@tds = ( "width=5" );
	print &ui_form_start("delete_recipes.cgi", "post");
	unshift(@links, &select_all_link("d"),
			&select_invert_link("d") );
	print &ui_links_row(\@links);
	print &ui_columns_start([
		"",
		$text{'index_action'},
		$text{'index_conds'},
		$text{'index_move'},
		$text{'index_ba'} ], 100, 0, \@tds);
	foreach $c (@conf) {
		local @cols;
		local @tds = ( "width=5" );
		if ($c->{'name'}) {
			# Environment variable assignment
			local $v = length($c->{'value'}) > 80 ?
					substr($c->{'value'}, 0, 80)." ..." :
					$c->{'value'};
			push(@cols, "<a href='edit_env.cgi?idx=$c->{'index'}'>".
			      &text('index_env',
			    	"<tt>".&html_escape($c->{'name'})."</tt>",
				"<tt>".&html_escape($v)."</tt>")."</a>");
			push(@tds, "width=100% colspan=2");
			}
		elsif ($c->{'include'}) {
			# Included file
			push(@cols, "<a href='edit_inc.cgi?idx=$c->{'index'}'>".
				&text('index_include', 
				"<tt>".&html_escape($c->{'include'})."</tt>").
				"</a>");
			push(@tds, "width=100% colspan=2");
			}
		else {
			# Procmail recipe
			local ($t, $a) = &parse_action($c);
			push(@cols,
			    "<a href='edit_recipe.cgi?idx=$c->{'index'}'>".
			    &text('index_act'.$t,
				    "<tt>".&html_escape($a)."</tt>")."</a>");
			push(@tds, "valign=top width=50%");

			local @c = @{$c->{'conds'}};
			if (!@c) {
				push(@cols, $text{'index_noconds'});
				}
			else {
				local $c;
				foreach $n (@c) {
					local $he ="<tt>".&html_escape($n->[1]).
						   "</tt>";
					if ($n->[0] eq '') {
						$c .= &text('index_re', $he);
						}
					elsif ($n->[0] eq '!') {
						$c .= &text('index_nre', $he);
						}
					elsif ($n->[0] eq '$') {
						$c .= &text('index_shell', $he);
						}
					elsif ($n->[0] eq '?') {
						$c .= &text('index_exit', $he);
						}
					elsif ($n->[0] eq '<') {
						$c .= &text('index_lt',$n->[1]);
						}
					elsif ($n->[0] eq '>') {
						$c .= &text('index_gt',$n->[1]);
						}
					$c .= "<br>\n";
					}
				push(@cols, $c);
				}
			push(@tds, "width=50%");
			}

		# Move up/down links
		local $mover;
		if ($c eq $conf[@conf-1] ||
		    $c->{'file'} ne $conf[$c->{'index'}+1]->{'file'}) {
			$mover .= "<img src=images/gap.gif>";
			}
		else {
			$mover .= "<a href='down.cgi?idx=$c->{'index'}'>".
			      "<img src=images/down.gif border=0></a>";
			}
		if ($c eq $conf[0] ||
		    $c->{'file'} ne $conf[$c->{'index'}-1]->{'file'}) {
			$mover .= "<img src=images/gap.gif>";
			}
		else {
			$mover .= "<a href='up.cgi?idx=$c->{'index'}'>".
			      "<img src=images/up.gif border=0></a>";
			}
		push(@cols, $mover);
		push(@tds, "width=32");

		# Add before/after links
		push(@cols, &ui_link("edit_recipe.cgi?new=1&after=$c->{'index'}","<img src=images/after.gif border=0>"));
		print &ui_checked_columns_row(\@cols, \@tds, "d",$c->{'index'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

# Manual edit button
print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("manual_form.cgi",
		      $text{'index_man'}, $text{'index_mandesc'});
print &ui_buttons_end();

print &ui_link("manual_form.cgi","$text{'index_manual'}")."\n";
print "<p>\n";

&ui_print_footer("/", $text{'index'});

