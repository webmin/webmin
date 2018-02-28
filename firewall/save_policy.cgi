#!/usr/local/bin/perl
# save_policy.cgi
# Change the default policy for some chain

require './firewall-lib.pl';
&ReadParse();
if (&get_ipvx_version() == 6) {
	require './firewall6-lib.pl';
	}
else {
	require './firewall4-lib.pl';
	}
@tables = &get_iptables_save();
$table = $tables[$in{'table'}];
&can_edit_table($table->{'name'}) || &error($text{'etable'});
@d = split(/\0/, $in{'d'});

if ($in{'add'}) {
	# Redirect to the rule page for adding a rule
	&redirect("edit_rule.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}).
		  "&chain=".&urlize($in{'chain'})."&new=1");
	}
elsif ($in{'delete'} && $in{'confirm'}) {
	# Delete this entire chain and all rules in it
	&lock_file($ipvx_save);
	$access{'delchain'} || &error($text{'delete_ecannot'});
	$table->{'rules'} = [ grep { $_->{'chain'} ne $in{'chain'} }
				   @{$table->{'rules'}} ];
	delete($table->{'defaults'}->{$in{'chain'}});
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($ipvx_save);
	&webmin_log("delete", "chain", undef, { 'chain' => $in{'chain'},
						'table' => $table->{'name'} });
	&redirect("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}));
	}
elsif ($in{'clear'} && $in{'confirm'}) {
	# Delete all rules from this chain
	$access{'delchain'} || &error($text{'clear_ecannot'});
	&lock_file($ipvx_save);
	$table->{'rules'} = [ grep { $_->{'chain'} ne $in{'chain'} }
				   @{$table->{'rules'}} ];
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($ipvx_save);
	&webmin_log("clear", "chain", undef, { 'chain' => $in{'chain'},
					       'table' => $table->{'name'} });
	&redirect("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}));
	}
elsif ($in{'delete'} || $in{'clear'}) {
	# Ask for confirmation on deleting the chain
	$mode = $in{'delete'} ? "delete" : "clear";
	$access{'delchain'} || &error($text{$mode.'_ecannot'});
	&ui_print_header($text{"index_title_v${ipvx}"}, $text{$mode.'_title'}, "");

	@rules = grep { $_->{'chain'} eq $in{'chain'} } @{$table->{'rules'}};
	print &ui_form_start("save_policy.cgi");
        print &ui_hidden("version", ${ipvx_arg});
	print &ui_hidden("table", $in{'table'});
	print &ui_hidden("chain", $in{'chain'});
	print &ui_hidden($mode, 1);
	print "<center><b>",&text($mode.'_rusure', "<tt>$in{'chain'}</tt>",
				  scalar(@rules)),"</b><p>\n";
	print &ui_submit($text{'delete_ok'}, 'confirm');
	print "</center>\n";
	print &ui_form_end();

	&ui_print_footer("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}),
			 $text{'index_return'});
	}
elsif ($in{'rename'} && $in{'newname'}) {
	# Rename a chain
	&lock_file($ipvx_save);
	$access{'delchain'} || &error($text{'rename_ecannot'});
	$in{'newname'} =~ /^\S+$/ || &error($text{'new_ename'});

	# Change the chain on each rule
	foreach $r (@{$table->{'rules'}}) {
		if ($r->{'chain'} eq $in{'chain'}) {
			$r->{'chain'} = $in{'newname'};
			}
		}

	# Rename the default
	$table->{'defaults'}->{$in{'newname'}} =
		$table->{'defaults'}->{$in{'chain'}};
	delete($table->{'defaults'}->{$in{'chain'}});

	# Adjust any other rules
	if ($in{'adjust'}) {
		foreach $r (@{$table->{'rules'}}) {
			if ($r->{'j'} && $r->{'j'}->[1] eq $in{'chain'}) {
				$r->{'j'}->[1] = $in{'newname'};
				}
			}
		}

	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($ipvx_save);
	&webmin_log("rename", "chain", undef, { 'chain' => $in{'chain'},
						'table' => $table->{'name'} });
	&redirect("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}));
	}
elsif ($in{'rename'}) {
	# Show chain rename form
	&ui_print_header($text{"index_title_v${ipvx}"}, $text{'rename_title'}, "");

	print &ui_form_start("save_policy.cgi");
        print &ui_hidden("version", ${ipvx_arg});
	print &ui_hidden("table", $in{'table'});
	print &ui_hidden("chain", $in{'chain'});
	print &ui_hidden("rename", 1);
	print &ui_table_start($text{'rename_header'}, undef, 2);

	# Number of rules and old name
	@rules = grep { $_->{'chain'} eq $in{'chain'} } @{$table->{'rules'}};
	print &ui_table_row($text{'rename_chain'}, $in{'chain'});
	print &ui_table_row($text{'rename_count'},
		scalar(@rules) || $text{'rename_none'});

	# Destination chain
	print &ui_table_row($text{'rename_name'},
		&ui_textbox("newname", undef, 20));

	# Adjust other rules?
	print &ui_table_row(" ",
		&ui_checkbox("adjust", 1, $text{'rename_adjust'}, 1));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'rename_ok'} ] ]);

	&ui_print_footer("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}),
			 $text{'index_return'});
	}
elsif ($in{'delsel'}) {
	# Just delete selected rules
	%idxs = map { $_, 1 } @d;
	&lock_file($ipvx_save);
	$table->{'rules'} = [ grep { $_->{'chain'} ne $in{'chain'} ||
				     !$idxs{$_->{'index'}} }
				   @{$table->{'rules'}} ];
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($ipvx_save);
	&webmin_log("delsel", "chain", undef, { 'chain' => $in{'chain'},
					        'table' => $table->{'name'},
						'count' => scalar(@d)});
	&redirect("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}));
	}
elsif ($in{'movesel'} && $in{'dest'}) {
	# Move selected rules to new chain
	%idxs = map { $_, 1 } @d;
        &lock_file($ipvx_save);

	# Change the chain on each rule
	foreach $r (@{$table->{'rules'}}) {
		if ($r->{'chain'} eq $in{'chain'} && $idxs{$r->{'index'}}) {
			$r->{'chain'} = $in{'dest'};
			}
		}

	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($ipvx_save);
	&webmin_log("movesel", "chain", undef, { 'chain' => $in{'chain'},
					         'table' => $table->{'name'},
						 'count' => scalar(@d)});
	&redirect("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}));
	}
elsif ($in{'movesel'}) {
	# Show rule move form
	&ui_print_header($text{"index_title_v${ipvx}"}, $text{'move_title'}, "");

	print &ui_form_start("save_policy.cgi");
        print &ui_hidden("version", ${ipvx_arg});
	print &ui_hidden("table", $in{'table'});
	print &ui_hidden("chain", $in{'chain'});
	print &ui_hidden("movesel", 1);
	foreach $d (@d) {
		print &ui_hidden("d", $d);
		}
	print &ui_table_start($text{'move_header'}, undef, 2);

	# Number of rules and source
	print &ui_table_row($text{'move_count'}, scalar(@d));
	print &ui_table_row($text{'move_chain'}, $in{'chain'});

	# Destination chain
	print &ui_table_row($text{'move_dest'},
		&ui_select("dest", $in{'chain'},
		   [ grep { $_ ne $in{'chain'} }
			  sort by_string_for_iptables
			       (keys %{$table->{'defaults'}}) ]));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'move_ok'} ] ]);

	&ui_print_footer("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}),
			 $text{'index_return'});
	}
else {
	# Change the default for this chain
	$access{'policy'} || &error($text{'policy_ecannot'});
	&lock_file($ipvx_save);
	$table->{'defaults'}->{$in{'chain'}} = $in{'policy'};
	&run_before_command();
	&save_table($table);
	&run_after_command();
	&copy_to_cluster();
	&unlock_file($ipvx_save);
	&webmin_log("modify", "chain", undef, { 'chain' => $in{'chain'},
					        'table' => $table->{'name'} });
	&redirect("index.cgi?version=${ipvx_arg}&table=".&urlize($in{'table'}));
	}

