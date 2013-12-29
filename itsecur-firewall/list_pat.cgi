#!/usr/bin/perl
# list_pat.cgi
# Show table of incoming forwarded ports

require './itsecur-lib.pl';
&can_use_error("pat");
&header($text{'pat_title'}, "",
	undef, undef, undef, undef, &apply_button());

print &ui_hr();

my @forwards = &get_pat();
print &ui_form_start("save_pat.cgi","post");
print &ui_table_start($text{'pat_header'}, undef, 2);

my $tx = &ui_columns_start([$text{'pat_service'},
                                $text{'pat_host'},
                                $text{'pat_iface'}]);

my $j = 0;
foreach $f (@forwards, { }, { }, { }) {
	my @cols;
    push(@cols, &service_input("service_$j", $f->{'service'}, 1) );
    push(@cols, &ui_textbox("host_".$j, $f->{'host'}, 30) );
    push(@cols, &iface_input("iface_$j", $f->{'iface'}, 0, 1, 1) );
    $tx .= &ui_columns_row(\@cols);
	$j++;
	}
$tx .= &ui_columns_end();

print &ui_table_row($text{'pat_forward'}, $tx);

print &ui_table_end();
print "<p>";
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);
&can_edit_disable("pat");

print &ui_hr();
&footer("", $text{'index_return'});
