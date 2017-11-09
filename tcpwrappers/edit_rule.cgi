#!/usr/local/bin/perl
# Creating or editing rule

require './tcpwrappers-lib.pl';
&ReadParse();
$type = $in{'allow'} ? 'allow' : 'deny';

@xservices = &list_services();
unshift @xservices, "ALL" if (@xservices);

if ($in{'new'}) {
    &ui_print_header(undef, $text{'edit_title1'.$type}, "", "edit_rule");
} else {
    &ui_print_header(undef, $text{'edit_title2'.$type}, "", "edit_rule");

    # Get the rule
    @rules = &list_rules($config{'hosts_'.$type});
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
print &ui_table_start($text{'edit_header'}, "", 2);

# Services
if (@xservices && $config{'inetd_services'}) {
	# listed from (x)inetd
	print &ui_table_row($text{'edit_service'},
		&ui_select("service", \@services, \@xservices, 5, 1));
	print &ui_table_row($text{'edit_except'},
		&ui_select("service_except", \@eservices, \@xservices, 5, 1));
	}
else {
	print &ui_table_row($text{'edit_service'},
		&ui_textbox("service_custom", join(",",@services), 40));
	print &ui_table_row($text{'edit_except'},
		&ui_textbox("service_except_custom", join(",",@eservices), 40));
	}

print &ui_table_hr();

# Hosts
@wildcards = ("ALL","KNOWN","UNKNOWN","LOCAL","PARANOID");
$found = '';
foreach my $w (@wildcards) {
    $found = $w if ($w eq $hosts);
}
print &ui_table_row($text{'edit_hosts'},
	&ui_opt_textbox("host_text", ($found ? "" : $hosts), 41,
		&ui_select("host_select", $found, \@wildcards)), 3);
print &ui_table_row($text{'edit_hostsexcept'},
	&ui_textbox("host_except", $ehosts, 50), 3);

print &ui_table_hr();

# Shell commands
@directives = ('none', 'spawn', 'twist');
@cmds = split /:/, $rule->{'cmd'} if (!$in{'new'});
$label = $text{'edit_cmd'};
for ($i = 0; $i <= $#cmds; $i++) {
    $cmds[$i] =~ s/^\s*//;
    my $chosen = $cmds[$i] =~ /^(spawn|twist)/ ? $1 : 'none';
    $cmds[$i] =~ s/^\s*${chosen}\s*// if ($cmds[$i] =~ /^\s*(spawn)|(twist)/);
    print &ui_table_row($label, &ui_select("cmd_directive_$i", $chosen, \@directives).' '.&ui_textbox("cmd_$i", $cmds[$i], 50), 3);
    $label = "";
}

# Row for new command
print &ui_table_row($label, &ui_select("cmd_directive_$i", undef, \@directives).' '.&ui_textbox("cmd_$i", "", 50), 3);
print &ui_hidden("cmd_count", $i),"\n";

# Form footer
print &ui_table_end();
print &ui_form_end([
	$in{'new'} ? ( [ "create", $text{'create'} ] )
		   : ( [ "save", $text{'save'} ],
		       [ "delete", $text{'delete'} ] ) ]);

&ui_print_footer("index.cgi?type=$type", $text{'index_return'});
