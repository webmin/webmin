#!/usr/local/bin/perl
# view.cgi
# Show details of the action, including changed files

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './webminlog-lib.pl';
our (%text, %in);
&ReadParse();

# find the log record to view
my $act = &get_action($in{'id'});
&can_user($act->{'user'}) || &error($text{'view_ecannot'});
&can_mod($act->{'module'}) || &error($text{'view_ecannot'});

# display info about the action
&ui_print_header($in{'search_sub_title'} || undef, $text{'view_title'}, "", undef, undef, $in{'no_return'});

my @files = &list_files($act);
print &ui_form_start("rollback.cgi");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("search", $in{'search'});

print &ui_hidden_table_start(&text('view_header', $act->{'id'}),
		      	     "width=100%", 4, "main", 1);

# This "" is needed to make the label show properly!
print &ui_table_row($text{'view_action'}."",
		    &filter_javascript(&get_action_description($act, 1)), 3);

my %minfo = $act->{'module'} eq 'global' ?
		( 'desc' => $text{'search_global'} ) :
		&get_module_info($act->{'module'});
print &ui_table_row($text{'view_module'},
		    $minfo{'desc'});

if ($act->{'module'} ne 'global') {
	print &ui_table_row($text{'view_script'},
			    $act->{'script'} =~ /\// ?
				"<tt>$act->{'script'}</tt>" :
				"<tt>$act->{'module'}/$act->{'script'}</tt>");
	}
else {
	print &ui_table_row($text{'view_script'}, "<tt>$act->{'script'}</tt>");
	}

print &ui_table_row($text{'view_user'},
		    &html_escape($act->{'user'}));

print &ui_table_row($text{'view_ip'},
		    &html_escape($act->{'ip'}));

if ($act->{'sid'} ne '-') {
	print &ui_table_row($text{'view_sid'},
		&ui_link("search.cgi?sid=$act->{'sid'}&uall=1&mall=1&tall=1&fall=1&return=".
        &urlize($in{'return'})."&returndesc=".
        &urlize($in{'returndesc'}), $act->{'sid'}) );
	}

print &ui_table_row($text{'view_time'}, &make_date($act->{'time'}).
	" (".&make_date_relative($act->{'time'}).")");

if ($act->{'webmin'}) {
	print &ui_table_row($text{'view_host'},
			    $act->{'webmin'});
	}
print &ui_hidden_table_end("main");

# Annotations for this log entry
my $text = &get_annotation($act);
print &ui_hidden_table_start($text{'view_anno'}, "width=100%", 1, "anno",
			     $text ? 1 : 0);
print &ui_table_row(undef,
	&ui_textarea("anno", $text, 10, 80, "auto", 0,
		     "style='width:100%'")."<br>".
	&ui_submit($text{'save'}, "annosave"));
print &ui_hidden_table_end("anno");

# Page output, if any
my $output = &get_action_output($act);
if ($output && &foreign_check("mailboxes")) {
	&foreign_require("mailboxes");
	$output = &mailboxes::filter_javascript($output);
	$output = &mailboxes::safe_urls($output);
	$output = &mailboxes::disable_html_images($output, 1);
	print &ui_hidden_table_start($text{'view_output'}, "width=100%", 1,
				     "output", 0);
	print &ui_table_row(undef, $output, 2);
	print &ui_hidden_table_end("output");
	}

# Raw log data, hidden by default
print &ui_hidden_table_start($text{'view_raw'}, "width=100%", 1, "raw", 0);
my @tds = ( "width=20% ");
my $rtable = &ui_columns_start(
	[ $text{'view_rawname'}, $text{'view_rawvalue'} ], 100, 0, \@tds);
foreach my $k (keys %$act) {
	next if ($k eq 'param');
	$rtable .= &ui_columns_row([
		"<b>".&html_escape($k)."</b>",
		&html_escape($act->{$k}) ], \@tds);
	}
foreach my $k (keys %{$act->{'param'}}) {
	$rtable .= &ui_columns_row([
		&html_escape($k),
		&html_escape(join("\n", split(/\0/, $act->{'param'}->{$k}))) ],
		\@tds);
	}
$rtable .= &ui_columns_end();
print &ui_table_row(undef, $rtable, 2);
print &ui_hidden_table_end("raw");

# display modified and commands run files
my $rbcount = 0;
my $i = 0;
my $fhtml = "";
my $anydiffs = 0;
foreach my $d (&list_diffs($act)) {
	my $t = $text{"view_type_".$d->{'type'}};
	my $rb;
	if ($d->{'type'} eq 'create' || $d->{'type'} eq 'modify' ||
	    $d->{'type'} eq 'delete') {
		($rb) = grep { $_->{'file'} eq $d->{'object'} } @files;
		}
	my $cbox = @files ?
		&ui_checkbox("r", $d->{'object'}, "", $rb, undef, !$rb) : "";
	$rbcount++ if ($rb);
	my $open = !$in{'file'} || $d->{'object'} eq $in{'file'};
	if ($t =~ /\$2/ || !$d->{'diff'}) {
		# Diff is just a single line message
		$fhtml .= &ui_hidden_table_start($cbox.
		      $text{"view_type_".$d->{'type'}."desc"},
		      "width=100%", 2, "diff$i", 1);
		$fhtml .= &ui_table_row(undef,
			&ui_tag('pre',
				&text("view_type_".$d->{'type'},
				      "<tt>$d->{'object'}</tt>",
				      "<tt>".&html_escape($d->{'diff'})."</tt>")
			, {'data-text' => 1}), 2);
		}
	else {
		# Show multi-line diff
		$fhtml .= &ui_hidden_table_start(
			$cbox.&text("view_type_".$d->{'type'},
			            "<tt>$d->{'object'}</tt>"),
			"width=100%", 2, "diff$i", $open);
		$fhtml .= &ui_table_row(undef,
			"<pre>".&html_escape($d->{'diff'})."</pre>", 2);
		if ($d->{'input'}) {
			# And input too
			$fhtml .= &ui_table_row(undef,
				"<b>".&text('view_input')."</b><br>".
				"<pre>".&html_escape($d->{'input'})."</pre>",2);
			}
		}
	$fhtml .= &ui_hidden_table_end("diff$i");
	$i++;
	$anydiffs++;
	}
if ($rbcount) {
	$fhtml .= &ui_links_row([ &select_all_link("r"),
			          &select_invert_link("r") ]);
	}
print &ui_hidden_table_start($text{'view_files'}, "width=100%", 1, "files", 1);
$fhtml .= "<b>$text{'view_nofiles'}</b><p>\n" if (!$anydiffs);
print &ui_table_row(undef, $fhtml, 2);
print &ui_hidden_table_end("raw");

# Show rollback button
if (@files && $rbcount) {
	print &ui_form_end([ [ "rollback", $text{'view_rollback2'} ] ]);
	}
else {
	print &ui_form_end();
	}
my @return_index = $in{'no_return'} ? ( ) : ("", $text{'index_return'});
&ui_print_footer("search.cgi?search=".&urlize($in{'search'}), $text{'search_return'},
                 @return_index);


