#!/usr/local/bin/perl
# Show the details of one file pool daemon

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
@pools = &find("Pool", $conf);

if ($in{'new'}) {
	&ui_print_header(undef, $text{'pool_title1'}, "");
	$mems = [ { 'name' => 'Pool Type',
		    'value' => 'Backup' },
		  { 'name' => 'Recycle',
		    'value' => 'yes' },
		  { 'name' => 'AutoPrune',
		    'value' => 'yes' },
		  { 'name' => 'Volume Retention',
		    'value' => '365 days' },
		];
	if (&get_bacula_version_cached() < 2) {
		push(@$mems,
		  { 'name' => 'Accept Any Volume',
		    'value' => 'yes' });
		}
	$pool = { 'members' => $mems };
	}
else {
	&ui_print_header(undef, $text{'pool_title2'}, "");
	$pool = &find_by("Name", $in{'name'}, \@pools);
	$pool || &error($text{'pool_egone'});
	$mems = $pool->{'members'};
	}

# Show details
print &ui_form_start("save_pool.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'pool_header'}, "width=100%", 4);

# Pool name
print &ui_table_row($text{'pool_name'},
	&ui_textbox("name", $name=&find_value("Name", $mems), 40), 3);

# Pool type
print &ui_table_row($text{'pool_type'},
	&ui_select("type", $type=&find_value("Pool Type", $mems),
	 	   [ map { [ $_, $_ =~ /^\*(.*)$/ ? $1 : $_ ] }
			 @pool_types ], 1, 0, 1));

# Maximum Volume Jobs
$max = &find_value("Maximum Volume Jobs", $mems);
print &ui_table_row($text{'pool_max'},
	    &ui_radio("maxmode", $max == 0 ? 0 : 1,
		      [ [ 0, $text{'pool_unlimited'} ],
			[ 1, &ui_textbox('max', $max == 0 ? "" : $max, 6) ] ]));

# Retention period
$reten = &find_value("Volume Retention", $mems);
print &ui_table_row($text{'pool_reten'},
		    &show_period_input("reten", $reten));

# Various yes/no options
print &ui_table_row($text{'pool_recycle'},
		    &bacula_yesno("recycle", "Recycle", $mems));
print &ui_table_row($text{'pool_auto'},
		    &bacula_yesno("auto", "AutoPrune", $mems));
if (&get_bacula_version_cached() < 2) {
	print &ui_table_row($text{'pool_any'},
			    &bacula_yesno("any", "Accept Any Volume", $mems));
	}
print &ui_table_row($text{'pool_autolabel'},
	&ui_textbox("autolabel", $name=&find_value("LabelFormat", $mems), 20), 3);
print &ui_table_row($text{'pool_maxvolsize'},
	&ui_textbox("maxvolsize", $name=&find_value("Maximum Volume Bytes", $mems), 10), 3);


# All done
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "status", $text{'pool_status'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_pools.cgi", $text{'pools_return'});

