#!/usr/bin/perl
# edit_service.cgi
# Show a form for editing or creating a user-defined

require './itsecur-lib.pl';
&can_use_error("services");
&ReadParse();
if ($in{'new'}) {
	&header($text{'service_title1'}, "",
		undef, undef, undef, undef, &apply_button());
	}
else {
	&header($text{'service_title2'}, "",
		undef, undef, undef, undef, &apply_button());
	@services = &list_services();
	#$service = $services[$in{'idx'}];
		if (defined($in{'idx'})) {
		$service = $services[$in{'idx'}];
		}
	else {
		($service) = grep { $_->{'name'} eq $in{'name'} } @services;
		$in{'idx'} = $services->{'index'};
		}	
	}

print &ui_hr();

print &ui_form_start("save_service.cgi","post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'service_header'}, undef, 2);

# Show service name input
print &ui_table_row($text{'service_name'}, &ui_textbox("name", $service->{'name'}, 20) );

# Show protocols and ports
my $tx = "";
$tx .= &ui_columns_start([$text{'service_proto'}, $text{'service_port'}]);
for($i=0; $i<@{$service->{'protos'}}+6; $i++) {
    my @cols;
    push(@cols, &protocol_input("proto_$i", $service->{'protos'}->[$i]) );
    push(@cols, &ui_textbox("port_".$i, $service->{'ports'}->[$i], 20) );
    $tx .= &ui_columns_row(\@cols);
	}
$tx .= ui_columns_end();

print &ui_table_row($text{'service_ports'}, $tx);

# Show member services
print &ui_table_row($text{'service_members'},
        &service_input("others", join(",", @{$service->{'others'}}), 0, 1) );

print &ui_table_end();

if ($in{'new'}) {
    print &ui_submit($text{'create'});
	}
else {
    print &ui_submit($text{'save'});
    print &ui_submit($text{'delete'}, "delete");
	}

print &ui_form_end(undef,undef,1);
&can_edit_disable("services");

print &ui_hr();
&footer("list_services.cgi", $text{'services_return'});
