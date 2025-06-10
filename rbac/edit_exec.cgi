#!/usr/local/bin/perl
# Show one RBAC execution profile

require './rbac-lib.pl';
$access{'execs'} || &error($text{'execs_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'exec_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'exec_title2'}, "");
	$execs = &list_exec_attrs();
	$exec = $execs->[$in{'idx'}];
	}

print &ui_form_start("save_exec.cgi", "post");
print &ui_hidden("idx", $in{'idx'}),"\n";
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_table_start($text{'exec_header'}, "width=100%", 2);

$profs = &list_prof_attrs();
print &ui_table_row($text{'exec_name'},
		    &ui_select("name", $exec->{'name'},
			[ map { [ $_->{'name'} ] } @$profs ], 0, 0,
			$in{'new'} ? 0 : 1));

print &ui_table_row($text{'exec_policy'},
		    &ui_radio("policy", $exec->{'policy'} || "suser",
			       [ [ "suser", $text{'execs_psuser'} ],
				 [ "solaris", $text{'execs_psolaris'} ] ]));

print &ui_table_row($text{'exec_id'},
		    &ui_opt_textbox("id", $exec->{'id'} eq "*" ? undef :
				$exec->{'id'}, 40, $text{'exec_all'}));

foreach $i ("uid", "gid", "euid", "egid") {
	print &ui_table_row($text{'exec_'.$i},
			    &ui_opt_textbox($i, $exec->{'attr'}->{$i}, 15,
				    $text{'exec_default'},
				    $i =~ /uid/ ? $text{'exec_asuser'}
						: $text{'exec_asgroup'}));
	}

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}

&ui_print_footer("list_execs.cgi", $text{'execs_return'});

