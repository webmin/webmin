#!/usr/bin/perl
# active.cgi
# Show active nftables tables for viewing and import

require './nftables-lib.pl';    ## no critic
use strict;
use warnings;
our (%text);
assert_acl('active');

ui_print_header(undef, $text{'active_title'}, "");

my ($tables, $err) = get_active_nftables_save();
if ($err) {
	print text('active_failed', $err);
	}
else {
	@$tables = grep { check_table_acl($_) } @$tables;
	if (!@$tables) {
		print "<b>$text{'active_none'}</b><p>\n";
		}
	else {
		my @saved_tables = get_nftables_save();
		print ui_columns_start(
			[ $text{'active_table'}, $text{'active_flags'},
			  $text{'active_chains'}, $text{'active_sets'},
			  $text{'active_rules'}, $text{'active_status'},
			  $text{'index_actions'} ], 100);
		foreach my $t (@$tables) {
			my $chains =
			    $t->{'chains'} &&
			    ref($t->{'chains'}) eq 'HASH'
			    	? scalar(keys %{$t->{'chains'}})
			    	: 0;
			my $sets =
			    $t->{'sets'} &&
			    ref($t->{'sets'}) eq 'HASH'
			    	? scalar(keys %{$t->{'sets'}})
			    	: 0;
			my $rules =
			    $t->{'rules'} &&
			    ref($t->{'rules'}) eq 'ARRAY'
			    	? scalar(@{$t->{'rules'}})
			    	: 0;
			my $flags = $t->{'flags'} || "-";
			my $status_key = active_table_status($t, \@saved_tables);
			my $status = $text{'active_'.$status_key};
			my $is_saved = table_is_webmin_managed($t, \@saved_tables);
			my $table_url =
			    "active_table.cgi?family=".
			    urlize($t->{'family'}).
			    "&name=".
			    urlize($t->{'name'});
			my @actions;
			push(
				@actions,
				ui_link(
					"import_table.cgi?family=".
					    urlize(
						$t->{'family'}
					    ).
					    "&name=".
					    urlize($t->{'name'}),
					$text{'active_import'}
				)
			) if (!$is_saved && check_acl('import'));
			push(
				@actions,
				ui_link(
					"clear_table.cgi?family=".
					    urlize(
						$t->{'family'}
					    ).
					    "&name=".
					    urlize($t->{'name'}),
					$text{'active_clear'}
				)
			    )
			    if (!table_is_externally_managed($t) && check_acl('clear'));
			my $actions = @actions ? join(" ", @actions) : "-";
			print ui_columns_row(
				[
					ui_link(
						$table_url,
						html_escape(nft_table_spec($t))
					),
					html_escape($flags),
					$chains, $sets, $rules, $status,
					$actions,
				]
			);
			}
		print ui_columns_end();

		my @clearable =
		    grep { !table_is_externally_managed($_) && check_acl('clear') }
		    @$tables;
		if (@clearable) {
			print ui_hr();
			print ui_buttons_start();
			print ui_buttons_row(
				"clear_tables.cgi",
				$text{'active_clear_all'},
				$text{'active_clear_alldesc'}
			);
			print ui_buttons_end();
			}
		}
	}

ui_print_footer("index.cgi", $text{'index_return'});
