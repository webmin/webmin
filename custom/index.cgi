#!/usr/local/bin/perl
# index.cgi
# Display commands available for execution

require './custom-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

@cust = grep { &can_run_command($_) } &list_commands();
@cust = sort { local $o = $b->{'order'} <=> $a->{'order'};
	       $o ? $o : $a->{'id'} <=> $b->{'id'} } @cust;

# Build links
@links = ( );
if ($access{'edit'}) {
	push(@links,"<a href='edit_cmd.cgi?new=1'>$text{'index_create'}</a>");
	push(@links,"<a href='edit_file.cgi?new=1'>$text{'index_ecreate'}</a>");
	push(@links,"<a href='edit_sql.cgi?new=1'>$text{'index_screate'}</a>");
	}

if (!@cust) {
	print "<b>$text{'index_none'}</b> <p>\n";
	}
elsif ($config{'display_mode'} == 0) {
	# Show command buttons
	print &ui_links_row(\@links);
	print "<table width=100%><tr><td valign=top>\n";
	$form = 0;
	for($i=0; $i<@cust; $i++) {
		$c = $cust[$i];
		@a = @{$c->{'args'}};
		if ($c->{'edit'}) {
			print "<form action=view.cgi>\n";
			}
		elsif ($c->{'sql'}) {
			print "<form action=sql.cgi>\n";
			}
		else {
			local ($up) = grep { $_->{'type'} == 10 } @a;
			if ($up) {
				print "<form action=run.cgi method=post enctype=multipart/form-data>\n";
				}
			elsif (@a) {
				print "<form action=run.cgi method=post>\n";
				}
			else {
				print "<form action=run.cgi method=get>\n";
				}
			}
		print "<input type=hidden name=idx value='$c->{'index'}'>\n";
		print "<table border cellpadding=3><tr $cb><td>\n";
		print "<input type=submit value='",&html_escape($c->{'desc'}),
		      "'><br>\n";
		print &filter_javascript($c->{'html'}),"\n";
		print "<table>\n";
		foreach $a (@a) {
			print "<tr> <td><b>",&html_escape($a->{'desc'}),
			      "</b></td> <td>\n";
			$n = $a->{'name'};
			if ($a->{'type'} == 0) {
				print "<input name=$n size=30>\n";
				}
			elsif ($a->{'type'} == 1 || $a->{'type'} == 2) {
				print "<input name=$n size=8> ",
					&user_chooser_button($n, 0, $form);
				}
			elsif ($a->{'type'} == 3 || $a->{'type'} == 4) {
				print "<input name=$n size=8> ",
					&group_chooser_button($n, 0, $form);
				}
			elsif ($a->{'type'} == 5 || $a->{'type'} == 6) {
				print "<input name=$n size=30 ",
				      "value='$a->{'opts'}'> ",
					&file_chooser_button(
						$n, $a->{'type'}-5, $form);
				}
			elsif ($a->{'type'} == 7) {
				print "<input type=radio name=$n value=1> $text{'yes'}\n";
				print "<input type=radio name=$n value=0 checked> $text{'no'}\n";
				}
			elsif ($a->{'type'} == 8) {
				print "<input name=$n type=password size=30>\n";
				}
			elsif ($a->{'type'} == 9) {
				print "<select name=$n>\n";
				foreach $l (&read_opts_file($a->{'opts'})) {
					print "<option value='$l->[0]'>",
					      "$l->[1]\n";
					}
				print "</select>\n";
				}
			elsif ($a->{'type'} == 10) {
				print "<input name=$n type=file size=20>\n";
				}
			elsif ($a->{'type'} == 11) {
				print "<textarea name=$n rows=4 cols=30>".
				      "</textarea>\n";
				}
			print "</td> </tr>\n";
			}
		if ($access{'edit'}) {
			if ($c->{'edit'}) {
				print "<tr> <td colspan=2 align=right nowrap>",
				      "<a href='edit_file.cgi?idx=$c->{'index'}'>",
				      "$text{'index_fedit'}</a></td> </tr>\n";
				}
			elsif ($c->{'sql'}) {
				print "<tr> <td colspan=2 align=right nowrap>",
				      "<a href='edit_sql.cgi?idx=$c->{'index'}'>",
				      "$text{'index_sedit'}</a></td> </tr>\n";
				}
			else {
				print "<tr> <td colspan=2 align=right nowrap>",
				      "<a href='edit_cmd.cgi?idx=$c->{'index'}'>",
				      "$text{'index_edit'}</a></td> </tr>\n";
				}
			}
		print "</table></td></tr></table></form>\n";
		$form++;
		if ($i == int((@cust-1)/2) && $config{'columns'} == 2) {
			print "</td><td valign=top>\n";
			}
		}
	print "</td></tr></table>\n";
	}
else {
	# Just show table of commands
	print &ui_links_row(\@links);
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_cmd'}</b></td>\n";
	if ($access{'edit'}) {
		print "<td colspan=2><b>$text{'index_desc'}</b></td> </tr>\n";
		}
	else {
		print "<td><b>$text{'index_desc'}</b></td> </tr>\n";
		}
	foreach $c (@cust) {
		if ($c->{'edit'} && !@{$c->{'args'}}) {
			# Open file editor directly, as file is known
			print "<tr $cb> <td><a href='view.cgi?idx=$c->{'index'}'>",
			      &html_escape($c->{'desc'}),"</a>\n";
			}
		elsif ($c->{'sql'}) {
			# Link to SQL query form
			print "<tr $cb> <td><a href='sqlform.cgi?idx=$c->{'index'}'>",
			      &html_escape($c->{'desc'}),"</a>\n";
			}
		else {
			# Link to parameters form
			print "<tr $cb> <td><a href='form.cgi?idx=$c->{'index'}'>",
			      &html_escape($c->{'desc'}),"</a></td>\n";
			}
		print "</td> <td>$c->{'html'}<br></td>\n";
		if ($access{'edit'}) {
			local $e = $c->{'edit'} ? "edit_file.cgi" :
				   $c->{'sql'} ? "edit_sql.cgi" :
						 "edit_cmd.cgi";
			print "<td align=right><a href='$e?idx=$c->{'index'}'>",
			      "$text{'index_ed'}</a></td>\n";
			}
		print "</tr>\n";
		}
	print "</table>\n";
	}
print &ui_links_row(\@links);

&ui_print_footer("/", $text{'index'});

