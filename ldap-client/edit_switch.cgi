#!/usr/local/bin/perl
# Show a form for editing an LDAP switch

if (-r 'ldap-client-lib.pl') {
	require './ldap-client-lib.pl';
	}
else {
	require './nis-lib.pl';
	}
require './switch-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'eswitch_title'}, "");

# Get the current service
$conf = &get_nsswitch_config();
($switch) = grep { $_->{'name'} eq $in{'name'} } @$conf;
$switch || &error($text{'eswitch_egone'});

print &ui_form_start("save_switch.cgi", "post");
print &ui_hidden("name", $in{'name'}),"\n";
print &ui_table_start($text{'eswitch_header'}, undef, 2);

# Show service name
$desc = $text{'desc_'.$switch->{'name'}};
print &ui_table_row($text{'eswitch_name'},
		    $desc ? "$desc ($switch->{'name'})" : $switch->{'name'});

# Show sources in order, with fallback modes for each
$i = 0;
($allsrcs, $allowed) = &list_switch_sources();
foreach $s (@{$switch->{'srcs'}}, { }) {
	@cansrcs = grep { !$allowed->{$_} ||
			  &indexof($switch->{'name'}, @{$allowed->{$_}}) >= 0 }
			@$allsrcs;
	$stable = &ui_select("src_$i", $s->{'src'},
		[ [ "", "&lt;$text{'eswitch_none'}&gt;" ],
		  map { [ $_, $text{'order_'.$_} || $_ ] } @cansrcs ],
		1, 0, 1)."<br>\n";
	$stable .= "<table>\n";
	foreach $st (&list_switch_statuses()) {
		$stable .= "<tr> <td>".$text{'eswitch_'.$st}."</td>\n";
		@acts = &list_switch_actions($st);
		$stable .= "<td>".&ui_select(
			"status_".$st."_".$i, $s->{$st},
			[ [ "", "&lt;$text{'default'}&gt;" ],
			  map { [ $_, $text{'eswitch_'.$_} ] } @acts ]).
			   "</td> </tr>\n";		 
		}
	$stable .= "</table>\n";
	print &ui_table_row($text{'eswitch_'.$i} ||
			    &text('eswitch_nth', $i+1), $stable);
	$i++;
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_switches.cgi", $text{'switch_return'});

