#!/usr/local/bin/perl
# Show a table of all MIME types, with links to edit

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
my $conf = &get_config();
my $http = &find("http", $conf);
my $types = &find("types", $http);
$access{'global'} || &error($text{'index_eglobal'});

&ui_print_header(undef, $text{'mime_title'}, "");

# Show search form
print &ui_form_start("edit_mime.cgi");
print "$text{'mime_search'}&nbsp;&nbsp; ",
      &ui_textbox("search", $in{'search'}, 20)," ",
      &ui_submit($text{'mime_ok'});
print &ui_form_end();

# Find types
my @types = $types ? @{$types->{'members'}} : ();
if ($in{'search'}) {
	@types = grep { $_->{'name'} =~ /\Q$in{'search'}\E/i ||
			&indexoflc($in{'search'}, @{$_->{'words'}}) >= 0 }
		      @types;
	}

my @links;
push(@links, "<a href='edit_mime.cgi?new=1&search=".&urlize($in{'search'}).
	     "#new'>".$text{'mime_add'}."</a>") if (!$in{'new'});
if (@types) {
	# Show in table
	unshift(@links, &select_all_link("d", 1),
			&select_invert_link("d", 1));
	print &ui_form_start("save_mime.cgi", "post");
	print &ui_hidden("new", $in{'new'});
	print &ui_hidden("type", $in{'type'});
	print &ui_hidden("search", $in{'search'});
	print &ui_links_row(\@links);
	print &ui_columns_start([ "", $text{'mime_type'}, $text{'mime_exts'} ],
				100, 0, [ "width=5" ]);
	foreach my $t (@types) {
		if ($in{'type'} && $in{'type'} eq $t->{'name'}) {
			# Editing this type
			print "<a name=edit>";
			print &ui_checked_columns_row(
			  [ &ui_textbox("name", $t->{'name'}, 30),
			    &ui_textbox("words",
					join(" ", @{$t->{'words'}}), 50) ],
			  undef, "d", $t->{'name'}, 0, 1);
			}
		else {
			# Just show, with link to edit
			print &ui_checked_columns_row(
			  [ "<a href='edit_mime.cgi?type=".
			    &urlize($t->{'name'})."&search=".
			    &urlize($in{'search'})."#edit'>".
			    &html_escape($t->{'name'})."</a>",
			   &html_escape(join(" ", @{$t->{'words'}})) ],
			  undef, "d", $t->{'name'});
			}
		}
	if ($in{'new'}) {
		print &ui_checked_columns_row(
		  [ &ui_textbox("name", undef, 30),
		    &ui_textbox("words", undef, 50) ],
		  undef, "d", "xxx", 0, 1);
		}
	print &ui_columns_end();
	print "<a name=new>\n";
	print &ui_links_row(\@links);
	print &ui_form_end([ $in{'type'} ? ( [ undef, $text{'save'} ] ) :
			     $in{'new'} ? ( [ undef, $text{'create'} ] ) : ( ),
			     [ 'delete', $text{'mime_delete'} ] ]);
	}
else {
	# None matching search
	print "<b>",($in{'search'} ? $text{'mime_nomatch'}
				   : $text{'mime_none'}),"</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
