#!/usr/local/bin/perl
# A single page just for editing smtpd_client_restrictions

require './postfix-lib.pl';

$access{'client'} || &error($text{'client_ecannot'});
&ui_print_header(undef, $text{'client_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print &ui_form_start("save_client.cgi", "post");
print &ui_table_start($text{'client_title'}, undef, 2);

# Parse current settings
@opts = split(/[\s,]+/, &get_current_value('smtpd_client_restrictions'));
for(my $i=0; $i<@opts; $i++) {
	$opts{$opts[$i]} = $i;
	}

# Add binary restrictions to list
@grid = ( );
%done = ( );
foreach $r (&list_client_restrictions()) {
	push(@grid, &ui_checkbox("client", $r, $text{'sasl_'.$r},
				 defined($opts{$r})), undef);
	$done{$r} = 1;
	}

# Add restrictions with values
foreach $r (&list_multi_client_restrictions()) {
	push(@grid, &ui_checkbox("client", $r, $text{'sasl_'.$r},
				 defined($v)),
		    &ui_textbox("value_$r",
			        defined($v) ? $opts[$v+1] : undef, 40).
		    ($r eq "check_client_access" ?
			" ".&map_chooser_button("value_$r", $r) : ""));
	}

# XXX editing access maps?

# Show text field for the rest
@rest = grep { !$done{$o} } @opts;
if (@rest) {
	push(@grid, &ui_checkbox("other", 1, $text{'client_other'}, 1),
		    &ui_textbox("other_list", join(" ", @rest), 40));
	}

# Show field
print &ui_table_row($text{'client_restrict'},
	&ui_radio("client_def", @opts ? 0 : 1,
		  [ [ 1, $text{'client_restrict1'} ],
		    [ 0, $text{'client_restrict0'} ] ])."<br>\n".
	&ui_grid_table(\@grid, 2));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
