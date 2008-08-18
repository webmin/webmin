#!/usr/local/bin/perl
# list_ipnodes.cgi
# List ipnodes from /etc/ipnodes

require './net-lib.pl';
$access{'ipnodes'} || &error($text{'ipnodes_ecannot'});
&ui_print_header(undef, $text{'ipnodes_title'}, "");

# Build table contents
@table = ( );
foreach $h (&list_ipnodes()) {
	push(@table, [ $access{'ipnodes'} == 2 ?
			( { 'type' => 'checkbox', 'name' => 'd',
			    'value' => $h->{'index'} },
			  "<a href=\"edit_ipnode.cgi?idx=$h->{'index'}\">".
			  &html_escape($h->{'address'})."</a>" ) :
			( &html_escape($h->{'address'}) ),
		       join(" , ", map { &html_escape($_) }
				       @{$h->{'ipnodes'}}),
		     ]);
	}

# Show the table
print &ui_form_columns_table(
	$access{'ipnodes'} == 2 ?
		( "delete_ipnodes.cgi",
		  [ [ undef, $text{'ipnodes_delete'} ] ], 1  ) :
		( undef, undef, 0 ),
	$access{'ipnodes'} == 2 ?
		[ [ "edit_ipnode.cgi?new=1", $text{'ipnodes_add'} ] ] : [ ],
	undef,
	[ $access{'ipnodes'} == 2 ? ( "" ) : ( ),
	  $text{'ipnodes_ip'}, $text{'ipnodes_ipnode'} ],
	undef,
	\@table,
	undef, 1, undef, $text{'ipnodes_none'});

&ui_print_footer("", $text{'index_return'});

