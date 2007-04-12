#!/usr/local/bin/perl
# Show a form for editing or creating a log target

require './syslog-ng-lib.pl';
&ReadParse();

# Show title and get the log
$conf = &get_config();
@allsources = map { $_->{'value'} } &find("source", $conf);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'log_title1'}, "");
	$log = { 'type' => 1,
	         'members' => [ { 'type' => 0,
				  'name' => 'source',
			          'value' => $allsources[0]->{'value'},
			          'values' => $allsources[0]->{'values'},
				} ] };
	}
else {
	&ui_print_header(undef, $text{'log_title2'}, "");
	@logs = &find("log", $conf);
	($log) = grep { $_->{'index'} == $in{'idx'} } @logs;
	$log || &error($text{'log_egone'});
	}

# Form header
print &ui_form_start("save_log.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_table_start($text{'log_header'}, undef, 4);

# Show sources
@gotsources = map { $_->{'value'} } &find("source", $log->{'members'});
print &ui_table_row($text{'log_source'},
    &ui_select("source", \@gotsources,
	       [ map { [ $_ ] } @allsources ], 5, 1));

# Show flags
$fdir = &find("flags", $log->{'members'});
if ($fdir) {
	%flags = map { $_, 1 } @{$fdir->{'values'}};
	}
$flags = "";
foreach $f (@log_flags) {
	$flags .= &ui_checkbox($f, 1, $text{'log_'.$f}, $flags{$f})."<br>\n";
	}
print &ui_table_row($text{'log_flags'}, $flags);

# Show filters
@allfilters = map { [ $_->{'value'} ] } &find("filter", $conf);
@gotfilters = map { $_->{'value'} } &find("filter", $log->{'members'});
print &ui_table_row($text{'log_filter'},
    &ui_select("filter", \@gotfilters, \@allfilters, 10, 1));

# Show destinations
@alldestinations = map { [ $_->{'value'}, $_->{'value'}." (".&nice_destination_file($_).")" ] } &find("destination", $conf);
@gotdestinations = map { $_->{'value'} } &find("destination",$log->{'members'});
print &ui_table_row($text{'log_destination'},
    &ui_select("destination", \@gotdestinations, \@alldestinations, 10, 1));

# Form footer and buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_logs.cgi", $text{'logs_return'});

