#!/usr/local/bin/perl
# Show allowed and denied lists

require './tcpwrappers-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);

# Start of tabs
@types = ('allow', 'deny');
print &ui_tabs_start(
	[ map { [ $_, $text{'index_'.$_.'title'},
		  "index.cgi?type=$_" ] } @types ],
	"type",
	$in{'type'} || "allow",
	1);

# Tables of rules
$formno = 0;
foreach my $type ('allow', 'deny') {
	print &ui_tabs_start_tab("type", $type);
	my $file = $type eq 'allow' ? $config{'hosts_allow'}
				    : $config{'hosts_deny'};
	@rules = &list_rules($file);

	# Build grid of rules
	@table = ( );
	foreach my $r (@rules) {
		push(@table, [
			{ 'type' => 'checkbox', 'name' => 'd',
			  'value' => $r->{'id'} },
			&ui_link("edit_rule.cgi?$type=1&id=$r->{'id'}","$r->{'service'}"),
			$r->{'host'},
			$r->{'cmd'} ? join("<br>", split /:/, $r->{'cmd'})
				    : $text{'index_none'},
			]);
		}

	# Show them
	print &ui_form_columns_table(
		"delete_rules.cgi",
	       [ [ "delete", $text{'index_delete'} ] ],
	       1,
	       [ [ "edit_rule.cgi?$type=1&new=1", $text{'index_add'} ] ],
	       [ [ $type, 1 ] ],
	       [ "", $text{'index_service'},
		 $text{'index_hosts'}, $text{'index_cmd'}, ],
	       100,
	       \@table,
	       undef,
	       0,
	       undef,
	       &text('index_norule', $file),
	       $formno++,
	       );			
	print &ui_tabs_end_tab("type", $type);
	}

print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index_return'});
