# mod_cgi.pl
# Defines editors CGI logging directives

sub mod_cgi_directives
{
local($rv);
$rv = [ [ 'ScriptLog', 0, 11, 'global', 1.2 ],
        [ 'ScriptLogLength', 0, 11, 'global', 1.2 ],
        [ 'ScriptLogBuffer', 0, 11, 'global', 1.2 ] ];
return &make_directives($rv, $_[0], "mod_cgi");
}

sub mod_cgi_handlers
{
return ("cgi-script");
}

sub edit_ScriptLog
{
return (1, "$text{'mod_cgi_logname'}",
        &opt_input($_[0]->{'value'}, "ScriptLog", "$text{'mod_cgi_none'}", 20).
        &file_chooser_button("ScriptLog", 0));
}
sub save_ScriptLog
{
$in{'ScriptLog_def'} || &allowed_auth_file($in{'ScriptLog'}) ||
	&error($text{'mod_cgi_eunder'});
return &parse_opt("ScriptLog", '^\S+$', "$text{'mod_cgi_elogname'}");
}

sub edit_ScriptLogLength
{
return (1, "$text{'mod_cgi_logsize'}",
        &opt_input($_[0]->{'value'}, "ScriptLogLength", "$text{'mod_cgi_default'}", 8)
		.$text{'bytes'});
}
sub save_ScriptLogLength
{
return &parse_opt("ScriptLogLength", '^\d+$', "$text{'mod_cgi_elogsize'}");
}

sub edit_ScriptLogBuffer
{
return (1, "$text{'mod_cgi_post'}",
        &opt_input($_[0]->{'value'}, "ScriptLogBuffer", "$text{'mod_cgi_default'}", 6)
		.$text{'bytes'});
}
sub save_ScriptLogBuffer
{
return &parse_opt("ScriptLogBuffer", '^\d+$', "$text{'mod_cgi_epost'}");
}

1;

