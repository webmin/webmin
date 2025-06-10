#!/usr/local/bin/perl
# Display a list of other webmin servers

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './servers-lib.pl';
our (%text, %config, %access, %in);
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
&ReadParse();

# Get servers and apply search
my @servers = &list_servers_sorted(1);
if ($in{'search'}) {
	@servers = grep { $_->{'host'} =~ /\Q$in{'search'}\E/i ||
			  $_->{'desc'} =~ /\Q$in{'search'}\E/i } @servers;
	}

# Show search form
my $form = 0;
if (@servers > $config{'max_servers'} || $in{'search'}) {
	print &ui_form_start("index.cgi");
	print "<b>$text{'index_search'}</b> ",
	      &ui_textbox("search", $in{'search'}, 40)," ",
	      &ui_submit($text{'index_ok'}),"<p>\n";
	print &ui_form_end();
	$form++;
	}

# Work out links
my @linksrow;
if ($access{'edit'}) {
	if (@servers) {
		print &ui_form_start("delete_servs.cgi");
		push(@linksrow, &select_all_link("d", $form),
				&select_invert_link("d", $form));
		}
	if ($access{'add'}) {
		push(@linksrow, &ui_link("edit_serv.cgi?new=1", $text{'index_add'}) );
		}
	}

if (@servers && $config{'display_mode'}) {
	# Show table of servers
	print &ui_links_row(\@linksrow);
	print &ui_columns_start([
		$access{'edit'} ? ( "" ) : ( ),
		$text{'index_host'},
		$text{'index_desc'},
		$text{'index_group'},
		$text{'index_os'} ], 100);
	foreach my $s (@servers) {
		my @cols;
		my $table = "";
		if (!$access{'links'} || !$s->{'port'}) {
			$table .= "<span>\n";
			$table .= &html_escape($s->{'realhost'} ||$s->{'host'});
			$table .= ":$s->{'port'}" if ($s->{'port'});
			$table .= "</span>\n";
			}
		else {
			my $link = "";
			if ($s->{'user'} || $s->{'autouser'}) {
				$link = "link.cgi/".$s->{'id'}."/";
				}
			else {
				$link = &make_url($s);
				}
		    	$table .= "<span>\n";
			$table .= &ui_link($link,
				&html_escape($s->{'realhost'} || $s->{'host'} ).
				":".$s->{'port'}, undef, "target=_top");
			$table .= "</span>\n";
			}
		$table .= "<span style=\"float: right;\">";
		if ($s->{'autouser'} && &logged_in($s)) {
			$table .= &ui_link("logout.cgi?id=".$s->{'id'},
					   "(".$text{'index_logout'}.")");
			}
		if ($access{'edit'}) {
			$table .= &ui_link("edit_serv.cgi?id=".$s->{'id'},
					   "(".$text{'index_edit'}.")");
			}
		$table .= "</span>\n";
		push(@cols, $table);
		push(@cols, &html_escape($s->{'desc'}));
		push(@cols, &html_escape($s->{'group'}) || $text{'index_none'});
		my ($type) = grep { $_->[0] eq $s->{'type'} }
				  &get_server_types();
		push(@cols, $type->[1]);
		if ($access{'edit'}) {
			print &ui_checked_columns_row(\@cols, undef,
						      "d", $s->{'id'});
			}
		else {
			print &ui_columns_row(\@cols);
			}
		}
	print &ui_columns_end();
	}
elsif (@servers) {
	# Show server icons
	print &ui_links_row(\@linksrow);
	my (@afters, @befores);
	if ($access{'edit'}) {
		my $sep = length($text{'index_edit'}) > 10 ? "<br>" : " ";
		my $logout = sub {
			my ($l) = @_;
			my $logout_link = "";
			if (&logged_in($l)) {
			 	$logout_link =
			 		&ui_link("logout.cgi?id=$l->{'id'}", "(".$text{'index_logout'}.") ");
			 	}
			 return $logout_link;
		};
		@afters = map { $sep.&$logout($_).&ui_link("edit_serv.cgi?id=".$_->{'id'}, "(".$text{'index_edit'}.")" ) } @servers;
		@befores = map { &ui_checkbox("d", $_->{'id'}) } @servers;
		}
	my @titles = map { &make_iconname($_) } @servers;
	my @icons = map { -r "images/$_->{'type'}.svg" ? 
	                    "images/$_->{'type'}.svg" :
	                    "images/$_->{'type'}.gif" } @servers;
	my @links = map { !$access{'links'} ? undef :
		       $_->{'user'} || $_->{'autouser'} ?
			"link.cgi/$_->{'id'}/" : &make_url($_) } @servers;
	&icons_table(\@links, \@titles, \@icons, undef, "target=_top",
		     undef, undef, \@befores, \@afters);
	}
elsif ($in{'search'}) {
	# No servers match
	print "<b>$text{'index_nosearch'}</b> <p>\n";
	}
else {
	# No servers exist
	print "<b>$text{'index_noservers'}</b> <p>\n";
	}
if ($access{'edit'}) {
	print &ui_links_row(\@linksrow);
	if (@servers) {
		print &ui_form_end([ [ "delete", $text{'index_delete'} ] ]);
		}
	}

my $myip = &get_my_address();
my $myscan = &address_to_broadcast($myip, 1) if ($myip);
if ($access{'find'} || $access{'auto'}) {
	print &ui_hr();
	print &ui_buttons_start();
	if ($access{'find'}) {
		# Buttons to scan and broadcast for servers
		my %miniserv;
		&get_miniserv_config(\%miniserv);
		my $port = $config{'listen'} || $miniserv{'listen'} || 10000;
		print &ui_buttons_row("find.cgi", $text{'index_broad'},
						  $text{'index_findmsg'});
		my $t = &ui_buttons_row("find.cgi", $text{'index_scan'},
		      &text('index_scanmsg', "&nbsp;".
		              &ui_textbox("scan", $myscan, 15)."&nbsp;").
		      "<br><table>\n".
		      "<tr><td valign=middle>$text{'index_defuser'}&nbsp;</td>\n".
		      "<td valign=middle>".&ui_textbox("defuser", undef, 20)."</td> </tr>".
		      "<tr> <td>$text{'index_defpass'}&nbsp;</td>\n".
		      "<td valign=middle>".&ui_password("defpass", undef, 20)."</td> </tr>".
		      "<tr> <td>$text{'index_defport'}&nbsp;</td>\n".
		      "<td valign=middle>".&ui_textbox("port", $port, 20)."</td> </tr>".
		      "</table>\n"
		      );
		$t =~ s/valign=top class=ui_buttons_value/valign=middle class=ui_buttons_value/g;
		print $t;
		}
	if ($access{'auto'}) {
		# Button for auto-discovery form
		print &ui_buttons_row("edit_auto.cgi", $text{'index_auto'},
						  $text{'index_automsg'});
		}
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index'});

sub make_url
{
return sprintf "http%s://%s:%d/",
	$_[0]->{'ssl'} ? 's' : '', $_[0]->{'host'}, $_[0]->{'port'};
}

sub make_iconname
{
my $rv;
if ($_[0]->{'desc'} && !$config{'show_ip'}) {
	$rv = $_[0]->{'desc'};
	}
elsif ($_[0]->{'realhost'}) {
	$rv = "$_[0]->{'realhost'}:$_[0]->{'port'}";
	}
else {
	$rv = "$_[0]->{'host'}:$_[0]->{'port'}";
	}
return &html_escape($rv);
}

