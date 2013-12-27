#!/usr/bin/perl
# list_services.cgi
# Displays a list of standard and custom services

require './itsecur-lib.pl';
&can_use_error("services");
&header($text{'services_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

@services = &list_services();
$edit = &can_edit("services");

my $link = ( $edit ? &ui_link("edit_service.cgi?new=1",$text{'services_add'}) : "" );
 
print $link."<br>" if ( $link ne '' );

print &ui_columns_start([$text{'service_name'}, $text{'service_ports'}]);

if (!$services[0]->{'standard'}) {
    print &ui_columns_header([$text{'services_header1'}],["colspan=2"]);
	}
foreach $s (@services) {
	if ($s->{'standard'} && !$doneheader) {
        print &ui_columns_header([$text{'services_header2'}],["colspan=2"]);
		$doneheader++;
		}
    my @cols;
	if ($s->{'standard'}) {
        push(@cols, $s->{'name'} );
		}
	else {
        push(@cols, &ui_link("edit_service.cgi?idx=$s->{'index'}", $s->{'name'}) );
		}
    my $cl = "";
	for($i=0; $i<@{$s->{'protos'}}; $i++) {
        $cl .= &protocol_name($s->{'protos'}->[$i], $s->{'ports'}->[$i])."&nbsp;";
		}
	for($i=0; $i<@{$s->{'others'}}; $i++) {
		$cl .="<b>$s->{'others'}->[$i]</b>&nbsp;";
		}
    push(@cols, $cl);
    print &ui_columns_row(\@cols);
	}
print &ui_columns_end();

print $link."<p>" if ( $link ne '' );
print &ui_hr();


&footer("", $text{'index_return'});
