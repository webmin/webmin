# mod_imap.pl
# Defines editors for imagemap directives

sub mod_imap_directives
{
$rv = [ [ 'ImapMenu', 0, 20, 'virtual directory htaccess' ],
        [ 'ImapDefault', 0, 20, 'virtual directory htaccess' ],
        [ 'ImapBase', 0, 20, 'virtual directory htaccess' ] ];
return &make_directives($rv, $_[0], "mod_imap");
}

sub mod_imap_handlers
{
return ("imap-file");
}

sub edit_ImapMenu
{
return (2, "$text{'mod_imap_action'}",
        &select_input($_[0]->{'value'}, "ImapMenu", "", "$text{'mod_imap_default'},",
         "$text{'mod_imap_godefurl'},none", "$text{'mod_imap_form'},formatted",
         "$text{'mod_imap_semiform'},semiformatted",
         "$text{'mod_imap_unform'},unformatted"));
}
sub save_ImapMenu
{
return &parse_select("ImapMenu", "");
}

sub edit_ImapDefault
{
local($rv, $v);
if ($_[0]->{'value'} =~ /^\S+:/) { $v = "url"; }
else { $v = $_[0]->{'value'}; }
$rv = &select_input($v, "ImapDefault", "", "$text{'mod_imap_default'},",
       "$text{'mod_imap_disperr'},error",  "$text{'mod_imap_donoth'},nocontent",
       "$text{'mod_imap_goimap'},map", "$text{'mod_imap_goref'},referer",
       "$text{'mod_imap_gourl'},url");
$rv .= sprintf "&nbsp;<input name=ImapDefault_url size=30 value=\"%s\">\n",
        $v eq "url" ? $_[0]->{'value'} : "";
return (2, "$text{'mod_imap_defact'}", $rv);
}
sub save_ImapDefault
{
if ($in{'ImapDefault'} eq "") { return ( [ ] ); }
elsif ($in{'ImapDefault'} ne "url") { return ( [ $in{'ImapDefault'} ] ); }
elsif ($in{'ImapDefault_url'} !~ /^\S+$/) {
	&error(&text('mod_imap_eurl', $in{'ImapDefault_url'}));
	}
else { return ( [ $in{'ImapDefault_url'} ] ); }
}

sub edit_ImapBase
{
local($rv, $v);
if ($_[0]->{'value'} =~ /^\S+:/) { $v = "url"; }
else { $v = $_[0]->{'value'}; }
$rv = &select_input($v, "ImapBase", "", "$text{'mod_imap_default2'},",
       "$text{'mod_imap_root'},root", "$text{'mod_imap_imapurl'},map",
       "$text{'mod_imap_refurl'},referer", "$text{'mod_imap_url'},url");
$rv .= sprintf "&nbsp;<input name=ImapBase_url size=30 value=\"%s\">\n",
        $v eq "url" ? $_[0]->{'value'} : "";
return (2, "$text{'mod_imap_defbase'}", $rv);
}
sub save_ImapBase
{
if ($in{'ImapBase'} eq "") { return ( [ ] ); }
elsif ($in{'ImapBase'} ne "url") { return ( [ $in{'ImapBase'} ] ); }
elsif ($in{'ImapBase_url'} !~ /^\S+$/) {
	&error(&text('mod_imap_eurl', $in{'ImapBase_url'}));
	}
else { return ( [ $in{'ImapBase_url'} ] ); }
}

1;

