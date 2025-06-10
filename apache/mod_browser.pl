# mod_browser.pl
# Defines editors for directives to set environment variables

sub mod_browser_directives
{
local($rv);
$rv = [ [ 'BrowserMatch BrowserMatchNoCase', 1, 11, 'global' ] ];
return &make_directives($rv, $_[0], "mod_browser");
}

require 'browsermatch.pl';

1;

