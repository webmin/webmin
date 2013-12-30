#!/usr/bin/perl
# Show a form for setting up remote logging

require './itsecur-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&can_edit_error("remote");
&header($text{'remote_title'}, "",
	undef, undef, undef, undef, &apply_button());
print &ui_hr();

print &ui_form_start("save_remote.cgi", "post");
print &ui_table_start($text{'remote_header'}, undef, 2);


my @servers = &servers::list_servers();
my ($server) = grep { $_->{'host'} eq $config{'remote_log'} } @servers;

# Show target host
print &ui_table_row($text{'remote_host'},
                &ui_radio("host_def",($server ? 0 : 1),[
                    [1,$text{'no'}],
                    [0,$text{'remote_to'}."&nbsp;".
                        &ui_textbox("host",($server ? $server->{'host'} : ""),20)."&nbsp;".
                        $text{'remote_port'}."&nbsp;".
                        &ui_textbox("port",($server ? $server->{'port'} : 10000),10)
                    ]
                    ])
        ,undef, ["valign=middle","valign=middle"]);

# Show login and password
print &ui_table_row($text{'remote_user'},
            &ui_textbox("user",($server ? $server->{'user'} : ""),20), undef, ["valign=middle","valign=middle"] ); 
print &ui_table_row($text{'remote_pass'},
            &ui_password("pass",($server ? $server->{'pass'} : ""),20), undef, ["valign=middle","valign=middle"] ); 

print &ui_table_end();
print "<p>";
print &ui_submit($text{'save'});
print &ui_form_end(undef,undef,1);


print &ui_hr();
&footer("", $text{'index_return'});

