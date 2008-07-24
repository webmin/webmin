#!/usr/local/bin/perl
# Creating or editing rule

require './tcpwrappers-lib.pl';
&ReadParse();

@xservices = &list_services();
unshift @xservices, "ALL" if (@xservices);

if ($in{'new'}) {
    &ui_print_header(undef, $text{'edit_title1'}, "", "edit_rule");
} else {
    &ui_print_header(undef, $text{'edit_title2'}, "", "edit_rule");
    @rules = &list_rules($in{'allow'} ? $config{'hosts_allow'} : $config{'hosts_deny'});
    ($rule) = grep { $_->{'id'} == $in{'id'} } @rules;
    $rule || &error($text{'edit_eid'});

    # parse services (daemons)
    if ($rule->{'service'} =~ /^(.+) EXCEPT (.*)$/) {
	@services = split /,\s?|\s+/, $1;
	@eservices = split /,\s?|\s+/, $2;
    } else {
	@services = split /,\s?|\s+/, $rule->{'service'};
    } 

    if (@xservices) {
	# try to find all services (daemons) in xinetd/inetd
		foreach my $rule_service (@services, @eservices) {
		    $found = 0;
	    	foreach my $xinet_service (@xservices) { $found = 1 if ($rule_service eq $xinet_service); }
		    unless ($found) {
		    	# not found -> let user to edit custom service
		    	@xservices = ();
		    }
		}
    }
    # parse hosts
    if ($rule->{'host'} =~ /^(.+) EXCEPT (.*)$/) {
	$hosts = $1;
	$ehosts = $2
    } else {
	$hosts = $rule->{'host'};
    } 
}

# Form header
print &ui_form_start("save_rule.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("id", $in{'id'}),"\n";
print &ui_hidden($in{'allow'} ? 'allow' : 'deny', 1),"\n";
#print &ui_table_start($text{'edit_header'}, "width=100%", 5);
print &ui_table_start($text{'edit_header'}, "", 5);


# Services
if (@xservices) {
    # listed from (x)inetd
    print &ui_table_row("<b>$text{'edit_service'}</b> ", &ui_select("service", \@services, \@xservices, 10, 1));
    print &ui_table_row("EXCEPT", &ui_select("service_except", \@eservices, \@xservices, 10, 1));
} else {
    print &ui_table_row("<b>$text{'edit_service'}</b> ", &ui_textbox("service_custom", join(",",@services), 23));
    print &ui_table_row("EXCEPT", &ui_textbox("service_except_custom", join(",",@eservices), 23));    
}
print &ui_table_hr();

# Hosts
@wildcards = ("ALL","KNOWN","UNKNOWN","LOCAL","PARANOID");
$found = '';
foreach my $w (@wildcards) {
    $found = $w if ($w eq $hosts);
}
print &ui_table_row("<b>$text{'edit_hosts'}</b> ", &ui_opt_textbox("host_text", ($found ? "" : $hosts), 41, &ui_select("host_select", $found, \@wildcards)), 3);
print &ui_table_row("", "<b>EXCEPT</b> ".&ui_textbox("host_except", $ehosts, 50), 3);
print &ui_table_hr();

# Shell commands
@directives = ('none', 'spawn', 'twist');
@cmds = split /:/, $rule->{'cmd'} if (!$in{'new'});
print &ui_table_row($text{'edit_cmd'}, "", 3);
for ($i = 0; $i <= $#cmds; $i++) {
    $cmds[$i] =~ s/^\s*//;
    my $choosed = $cmds[$i] =~ /^(spawn|twist)/ ? $1 : 'none';
    $cmds[$i] =~ s/^\s*${choosed}\s*// if ($cmds[$i] =~ /^\s*(spawn)|(twist)/); 
    print &ui_table_row("", &ui_select("cmd_directive_$i", $choosed, \@directives).' '.&ui_textbox("cmd_$i", $cmds[$i], 50), 3);
}
# Row for new command
print &ui_table_row("", &ui_select("cmd_directive_$i", undef, \@directives).' '.&ui_textbox("cmd_$i", "", 50), 3);
print &ui_hidden("cmd_count", $i),"\n";


# Form footer
print &ui_table_end();
print &ui_form_end([
	$in{'new'} ? ( [ "create", $text{'create'} ] )
		   : ( [ "save", $text{'save'} ],
		       [ "delete", $text{'delete'} ] ) ]);

&ui_print_footer("", $text{'index_return'});
