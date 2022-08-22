#!/usr/local/bin/perl
# help.cgi
# Displays help HTML for some module, with substitutions

BEGIN { push(@INC, "."); };
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
$gzpath = $path.".gz";
if (-r $gzpath) {
	$help = &backquote_command(
		"gunzip -c ".quotemeta($gzpath)." 2>/dev/null");
	$? || !$help && &helperror(&text('help_efile2', &html_escape($gzpath)));
	}
else {
	$help = &read_file_contents($path);
	$help || &helperror(&text('help_efile', &html_escape($path)));
	}

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

# output the HTML
print $help;
&popup_footer();

# inchelp(path)
sub inchelp
{
my ($path) = @_;
my $ipath = &help_file($module, $path);
my $gzpath = $ipath.".gz";
if (-r $gzpath) {
	my $inc = &backquote_command(
		"gunzip -c ".quotemeta($gzpath)." 2>/dev/null");
	$? || !$inc ||
		return "<i>".&text('help_einclude2', $gzpath)."</i><br>\n";
	return $inc;
	}
else {
	my $inc = &read_file_contents($ipath);
	$inc || return "<i>".&text('help_einclude', $path)."</i><br>\n";
	return $inc;
	}
}

# ifhelp(perl, text, [elsetext])
sub ifhelp
{
my ($perl, $txt, $elsetxt) = @_;
my $rv = eval $perl;
if ($@) { return "<i>".&text('help_eif', $perl, $@)."</i><br>\n"; }
elsif ($rv) { return $txt; }
else { return $elsetxt; }
}

sub helperror
{
&header($text{'error'});
print "<center><h2>$text{'error'}</h2></center>\n";
print "<hr><p><b>",@_,"</b><p><hr>\n";
exit;
}

