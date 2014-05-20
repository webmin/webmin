#!/usr/local/bin/perl
# help.cgi
# Displays help HTML for some module, with substitutions

BEGIN { push(@INC, ".."); };
use WebminCore;

&init_config();
&error_setup($text{'help_err'});
$ENV{'PATH_INFO'} !~ /[\\\&\;\`\'\"\|\*\?\~\<\>\^\(\)\[\]\{\}\$\n\r]/ ||
	&error($text{'help_epath'});
$ENV{'PATH_INFO'} =~ /^\/(\S+)\/(\S+)$/ || &error($text{'help_epath'});
$module = $1; $file = $2;

# if it ends with .gif assume it is a direct URL
if ($file =~ /\.(gif|jpg|jpeg|png)$/i) {
	&redirect("$module/$file");
	exit;
}

# read the help file
$path = &help_file($module, $file);
@st = stat($path);
open(HELP, $path) || &helperror(&text('help_efile', $path));
read(HELP, $help, $st[7]);
close(HELP);

# find and replace the <header> section
if ($help =~ s/<header>([^<]+)<\/header>//i) {
	&popup_header($1);
	print &ui_subheading($1);
	}
else {
	&helperror($text{'help_eheader'});
	}

# replace any explicit use of <hr> with the ui-lib function
$uihr = &ui_hr();
$help =~ s/<hr>/$uihr/ig;

# find and replace the <footer> section
$help =~ s/<footer>/<p>/i;

# find and replace <include> directives
$help =~ s/<include\s+(\S+)>/inchelp($1)/ige;

# find and replace <if><else> directives
$help =~ s/<if\s+([^>]*)>([\000-\177]*?)<else>([\000-\177]*?)<\/if>/ifhelp($1, $2, $3)/ige;

# find and replace <if> directives
$help =~ s/<if\s+([^>]*)>([\000-\177]*?)<\/if>/ifhelp($1, $2)/ige;

# find and replace <exec> directives
$help =~ s/<exec\s+([^>]*)>/exechelp($1)/ige;

# output the HTML
print $help;
&popup_footer();

# inchelp(path)
sub inchelp
{
if ($_[0] =~ /^\/(\S+)\/(\S+)$/) {
	# including something from another module..
	}
else {
	# including from this module
	local $ipath = &help_file($module, $_[0]);
	@st = stat($ipath);
	open(INC, $ipath) ||
		return "<i>".&text('help_einclude', $_[0])."</i><br>\n";
	read(INC, $inc, $st[7]);
	close(INC);
	return $inc;
	}
}

# ifhelp(perl, text, [elsetext])
sub ifhelp
{
local $rv = eval $_[0];
if ($@) { return "<i>".&text('help_eif', $_[0], $@)."</i><br>\n"; }
elsif ($rv) { return $_[1]; }
else { return $_[2]; }
}

# exechelp(perl)
sub exechelp
{
local $rv = eval $_[0];
if ($@) { return "<i>".&text('help_eexec', $_[0], $@)."</i><br>\n"; }
else { return $rv; }
}

sub helperror
{
&header($text{'error'});
print "<center><h2>$text{'error'}</h2></center>\n";
print "<hr><p><b>",@_,"</b><p><hr>\n";
exit;
}

